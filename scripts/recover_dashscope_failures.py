#!/usr/bin/env python3
"""Recover failed dashscope extractions by reconstructing JSON from raw outputs."""
import json, re, sys, os
from pathlib import Path

RUN_DIR = Path("/tmp/openclaw/litextract_runs/20260502111946-33077")
OUT_DIR = Path("/Users/panyao/Qoder/JJJ_Literature/outputs/extractions")

def fix_quotes(t):
    out, in_s, i = [], False, 0
    while i < len(t):
        c = t[i]
        if not in_s:
            out.append(c)
            if c == '"': in_s = True
            i += 1; continue
        if c == '\\' and i+1 < len(t):
            out.append(c); out.append(t[i+1]); i += 2; continue
        if c == '"':
            rest = t[i+1:].lstrip()
            if rest and rest[0] in ',:]} \n\r\t':
                out.append(c); in_s = False
            else:
                out.append('\\"')
            i += 1; continue
        if c == '\n': out.append('\\n'); i += 1; continue
        out.append(c); i += 1
    return ''.join(out)

def try_parse(t):
    for txt in [t, fix_quotes(t)]:
        s = txt.find('{')
        if s < 0: continue
        try: return json.loads(txt[s:])
        except json.JSONDecodeError: pass
        depth = 0
        for j in range(s, len(txt)):
            if txt[j] == '{': depth += 1
            elif txt[j] == '}':
                depth -= 1
                if depth == 0:
                    try: return json.loads(txt[s:j+1])
                    except json.JSONDecodeError: break
    return None

def reconstruct_from_parts(t):
    s = t.find('{')
    if s < 0: return None
    c = t[s:]
    sm = re.search(r'"schema_version"\s*:\s*"([^"]*)"', c)
    pm = re.search(r'"paper_id"\s*:\s*"([^"]*)"', c)
    if not sm or not pm: return None
    def extract_obj(key):
        pos = c.find(f'"{key}"')
        if pos < 0: return None
        ob = c.find('{', pos)
        if ob < 0: return None
        d = 0
        for j in range(ob, len(c)):
            if c[j] == '{': d += 1
            elif c[j] == '}':
                d -= 1
                if d == 0:
                    try: return json.loads(c[ob:j+1])
                    except: return None
        return None
    def extract_arr(key):
        pos = c.find(f'"{key}"')
        if pos < 0: return []
        lb = c.find('[', pos)
        if lb < 0: return []
        items = []
        for m in re.finditer(r'\{', c[lb:]):
            d = 0
            s2 = lb + m.start()
            for j in range(s2, len(c)):
                if c[j] == '{': d += 1
                elif c[j] == '}':
                    d -= 1
                    if d == 0:
                        try: items.append(json.loads(c[s2:j+1]))
                        except: pass
                        break
        return items
    result = {
        "schema_version": sm.group(1),
        "paper_id": pm.group(1),
        "bibliographic_metadata": extract_obj("bibliographic_metadata") or {},
        "routing": extract_obj("routing") or {},
        "decision_summary": extract_obj("decision_summary") or {},
        "knowledge_items": extract_arr("knowledge_items"),
        "vector_index_records": extract_arr("vector_index_records"),
        "quality_control": extract_obj("quality_control") or {},
        "processing_notes": [],
    }
    if not result["knowledge_items"]: return None
    return result

def categorize_pdf(pdf_name):
    for cat in ["英文文献", "中文文献", "专利"]:
        if (OUT_DIR / cat / "json").is_dir():
            return cat
    return "英文文献"

def main():
    failures_tsv = RUN_DIR / "manifests" / "failures.tsv"
    if not failures_tsv.is_file():
        print("No failures file found")
        return

    recovered = 0
    still_failed = 0

    with open(failures_tsv) as f:
        for line in f:
            if line.startswith("timestamp"):
                continue
            parts = line.strip().split("\t")
            if len(parts) < 8:
                continue
            pdf_path, record_id, model = parts[1], parts[2], parts[3]
            if "no_valid_json" not in parts[6]:
                continue

            raw_path = RUN_DIR / "raw" / f"{record_id}.raw.txt"
            if not raw_path.is_file():
                continue

            text = open(raw_path, "r", encoding="utf-8").read()
            text = re.sub(r"```json\s*", "", text)
            text = re.sub(r"```\s*", "", text)
            text = text.strip()

            obj = try_parse(text)
            if obj is None:
                obj = reconstruct_from_parts(text)

            if obj and ("schema_version" in obj or "knowledge_items" in obj):
                pdf_name = os.path.basename(pdf_path)
                stem = os.path.splitext(pdf_name)[0]
                cat = categorize_pdf(pdf_name)
                dest = OUT_DIR / cat / "json" / f"{stem}.json"
                dest.parent.mkdir(parents=True, exist_ok=True)
                with open(dest, "w", encoding="utf-8") as f:
                    json.dump(obj, f, ensure_ascii=False, indent=2)
                    f.write("\n")
                ki = len(obj.get("knowledge_items", []))
                vr = len(obj.get("vector_index_records", []))
                print(f"  ✓ {pdf_name[:60]}  ({ki} ki, {vr} vr)")
                recovered += 1
            else:
                print(f"  ✗ {os.path.basename(pdf_path)[:60]}")
                still_failed += 1

    print(f"\nRecovered: {recovered}, Still failed: {still_failed}")

if __name__ == "__main__":
    main()
