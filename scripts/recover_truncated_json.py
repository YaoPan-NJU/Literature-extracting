#!/usr/bin/env python3
"""Re-extract full v2 schema JSON from raw outputs that were truncated.
Handles LLM output issues like unescaped quotes in string values."""
import json
import os
import sys
import re
import argparse
from pathlib import Path

def fix_unescaped_quotes_in_strings(text):
    """Fix unescaped double quotes inside JSON string values.

    Strategy: walk through the text character by character, tracking
    whether we're inside a JSON string. When we encounter a quote that
    would break the JSON, escape it.
    """
    result = []
    in_string = False
    i = 0

    while i < len(text):
        c = text[i]

        if not in_string:
            result.append(c)
            if c == '"':
                in_string = True
            i += 1
            continue

        # We're inside a string
        if c == '\\':
            # Escape sequence - copy both chars
            result.append(c)
            if i + 1 < len(text):
                result.append(text[i + 1])
                i += 2
            else:
                i += 1
            continue

        if c == '"':
            # Is this the end of the string, or an unescaped quote inside?
            # Look ahead: after a closing quote, we expect , : ] } or whitespace
            rest = text[i+1:].lstrip()
            if rest and rest[0] in ',:]} \n\r\t':
                # This is a proper closing quote
                result.append(c)
                in_string = False
            elif rest and rest[0] == '"':
                # Possible: end quote followed by next key/value start
                # Check if this looks like "key": pattern
                result.append(c)
                in_string = False
            else:
                # Unescaped quote inside string - escape it
                result.append('\\"')
        elif c == '\n':
            # Newlines inside JSON strings should be escaped
            result.append('\\n')
        elif c == '\r':
            result.append('\\r')
        elif c == '\t':
            result.append('\\t')
        else:
            result.append(c)

        i += 1

    return ''.join(result)

def find_outermost_json(text):
    """Find the outermost JSON object by tracking brace depth."""
    start = text.find('{')
    if start == -1:
        return None

    depth = 0
    in_string = False
    escape = False

    for i in range(start, len(text)):
        c = text[i]

        if escape:
            escape = False
            continue

        if c == '\\' and in_string:
            escape = True
            continue

        if c == '"' and not escape:
            in_string = not in_string
            continue

        if in_string:
            continue

        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return text[start:i+1]

    return None

def try_parse(text):
    """Try to parse JSON with progressive fixes."""
    # Remove markdown code blocks
    text = re.sub(r'```json\s*', '', text)
    text = re.sub(r'```\s*', '', text)
    text = text.strip()

    # Attempt 1: parse as-is
    try:
        return json.loads(text[text.find('{'):])
    except json.JSONDecodeError:
        pass

    # Attempt 2: fix unescaped quotes
    fixed = fix_unescaped_quotes_in_strings(text)
    try:
        return json.loads(fixed[fixed.find('{'):])
    except json.JSONDecodeError:
        pass

    # Attempt 3: find outermost braces after fixing
    outer = find_outermost_json(fixed)
    if outer:
        try:
            return json.loads(outer)
        except json.JSONDecodeError:
            pass

    # Attempt 4: try fixing trailing commas
    if outer:
        outer2 = re.sub(r',\s*([}\]])', r'\1', outer)
        try:
            return json.loads(outer2)
        except json.JSONDecodeError:
            pass

    return None

def process_file(raw_path, json_path):
    """Re-extract JSON from a raw file."""
    with open(raw_path, 'r', encoding='utf-8') as f:
        text = f.read()

    obj = try_parse(text)

    if obj is None:
        return False, "Could not parse any valid v2 JSON"

    # Check if it's the full schema
    if 'schema_version' not in obj and 'knowledge_items' not in obj:
        return False, f"Parsed JSON has keys: {list(obj.keys())[:5]}"

    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(obj, f, ensure_ascii=False, indent=2)
        f.write('\n')

    ki_count = len(obj.get('knowledge_items', []))
    return True, f"Recovered: {ki_count} knowledge_items"

def main():
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description="Recover malformed JSON files from raw OpenClaw outputs.")
    parser.add_argument(
        "--json-dir",
        default=str(repo / "outputs" / "en_literature_multi" / "json"),
        help="Directory containing JSON files to inspect.",
    )
    parser.add_argument(
        "--raw-dir",
        default=str(repo / "outputs" / "en_literature_multi" / "raw"),
        help="Directory containing matching .raw.txt files.",
    )
    args = parser.parse_args()

    json_dir = args.json_dir
    raw_dir = args.raw_dir

    if not os.path.isdir(json_dir) or not os.path.isdir(raw_dir):
        print("ERROR: Output directories not found")
        sys.exit(1)

    recovered = 0
    failed = 0

    for f in sorted(os.listdir(json_dir)):
        if not f.endswith('.json'):
            continue

        json_path = os.path.join(json_dir, f)

        # Check if already OK
        with open(json_path, 'r') as fh:
            obj = json.load(fh)
        if 'schema_version' in obj and 'knowledge_items' in obj:
            continue

        # Find corresponding raw file
        raw_path = os.path.join(raw_dir, f.replace('.json', '.raw.txt'))
        if not os.path.exists(raw_path):
            print(f"SKIP {f}: raw file not found")
            continue

        print(f"Recovering: {f[:60]}...")
        ok, msg = process_file(raw_path, json_path)

        if ok:
            recovered += 1
            print(f"  ✓ {msg}")
        else:
            failed += 1
            print(f"  ✗ {msg}")

    print(f"\nDone: {recovered} recovered, {failed} still failed")

if __name__ == '__main__':
    main()
