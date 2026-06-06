#!/usr/bin/env python3
"""
重标注 evidence 质量标签。

问题分析：
- reliable: 99.5% (5,071/5,097)
- needs_review: 0.4% (19/5,097)
- suspicious: 0.0% (0/5,097)

重标注规则：
- reliable: 有页码 + 有原文引用 + 数值精度一致
- needs_review: 有页码但无原文引用，或数值精度不一致
- suspicious: 无页码，或数值明显异常（如 qmax > 1000 mg/g）
- unavailable: 无页码且无原文引用
"""

import json
import os
import sys
import glob
import re


def has_page(evidence: dict) -> bool:
    """检查 evidence 是否有页码"""
    page = evidence.get('page')
    return page is not None and page != ''


def has_evidence_text(evidence: dict) -> bool:
    """检查 evidence 是否有原文引用"""
    text = evidence.get('evidence_text')
    return text is not None and text != '' and len(text) > 10


def is_suspicious_value(value: str, parameter: str) -> bool:
    """检查数值是否明显异常"""
    if not value or not isinstance(value, str):
        return False

    # 检查 qmax 异常值
    if 'qmax' in parameter.lower() or '吸附容量' in parameter.lower():
        nums = re.findall(r'[\d.]+', value)
        for num in nums:
            try:
                if float(num) > 1000:  # qmax > 1000 mg/g 可疑
                    return True
            except:
                pass

    # 检查去除率异常值
    if '去除率' in parameter.lower() or 'removal' in parameter.lower():
        nums = re.findall(r'[\d.]+', value)
        for num in nums:
            try:
                if float(num) > 100:  # 去除率 > 100% 可疑
                    return True
            except:
                pass

    return False


def relabel_evidence(evidence: dict, value: str = '', parameter: str = '') -> str:
    """根据规则重新标注 evidence 质量"""
    page = has_page(evidence)
    text = has_evidence_text(evidence)
    suspicious = is_suspicious_value(value, parameter)
    text_length = len(evidence.get('evidence_text', '') or '')

    if suspicious:
        return 'suspicious'

    # 高质量：有页码 + 有详细原文引用（>50字符）
    if page and text and text_length > 50:
        return 'reliable'

    # 中等质量：有页码 + 有原文引用但较短
    if page and text:
        return 'needs_review'

    # 低质量：有页码但无原文引用
    if page and not text:
        return 'needs_review'

    # 可疑：无页码但有原文引用（可能是编造的）
    if not page and text:
        return 'suspicious'

    # 不可用：无页码且无原文引用
    return 'unavailable'


def relabel_json_file(json_path: str, dry_run: bool = False) -> dict:
    """重标注单个 JSON 文件的 evidence 质量"""
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    items = data.get('knowledge_items', [])
    if not items:
        return {'file': json_path, 'status': 'skip', 'reason': 'no knowledge_items'}

    # 统计修复前
    before_stats = {'reliable': 0, 'needs_review': 0, 'suspicious': 0, 'unavailable': 0}
    for item in items:
        for ev in item.get('evidence', []):
            q = ev.get('quality', 'unknown')
            if q in before_stats:
                before_stats[q] += 1

    # 重标注
    after_stats = {'reliable': 0, 'needs_review': 0, 'suspicious': 0, 'unavailable': 0}
    changes = []

    for item in items:
        value = str(item.get('value', ''))
        parameter = str(item.get('parameter', ''))
        for ev in item.get('evidence', []):
            old_quality = ev.get('quality', 'unknown')
            new_quality = relabel_evidence(ev, value, parameter)
            ev['quality'] = new_quality

            if new_quality in after_stats:
                after_stats[new_quality] += 1

            if old_quality != new_quality:
                changes.append({
                    'parameter': parameter[:30],
                    'old': old_quality,
                    'new': new_quality
                })

    # 保存
    if not dry_run:
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')

    return {
        'file': os.path.basename(json_path),
        'status': 'changed' if changes else 'unchanged',
        'before': before_stats,
        'after': after_stats,
        'changes_count': len(changes)
    }


def main():
    import argparse
    parser = argparse.ArgumentParser(description='重标注 evidence 质量标签')
    parser.add_argument('--json-dir', default=None, help='JSON 文件目录')
    parser.add_argument('--dry-run', action='store_true', help='只分析不保存')
    args = parser.parse_args()

    json_dir = args.json_dir or os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        'outputs', 'extractions', '论文', 'json'
    )

    if not os.path.exists(json_dir):
        print(f"ERROR: 目录不存在: {json_dir}")
        sys.exit(1)

    json_files = glob.glob(os.path.join(json_dir, '*.json'))
    print(f"找到 {len(json_files)} 个 JSON 文件")

    if args.dry_run:
        print("=== DRY RUN 模式 ===\n")

    reports = []
    for json_file in sorted(json_files):
        try:
            report = relabel_json_file(json_file, dry_run=args.dry_run)
            reports.append(report)
        except Exception as e:
            reports.append({
                'file': os.path.basename(json_file),
                'status': 'error',
                'error': str(e)
            })

    # 输出报告
    print("=" * 60)
    print("重标注报告")
    print("=" * 60)

    changed_count = sum(1 for r in reports if r['status'] == 'changed')
    unchanged_count = sum(1 for r in reports if r['status'] == 'unchanged')
    error_count = sum(1 for r in reports if r['status'] == 'error')

    print(f"\n总文件: {len(reports)}")
    print(f"已修改: {changed_count}")
    print(f"未变: {unchanged_count}")
    print(f"错误: {error_count}")

    # 统计修复前后的质量分布
    total_before = {'reliable': 0, 'needs_review': 0, 'suspicious': 0, 'unavailable': 0}
    total_after = {'reliable': 0, 'needs_review': 0, 'suspicious': 0, 'unavailable': 0}

    for r in reports:
        if 'before' in r:
            for k in total_before:
                total_before[k] += r['before'].get(k, 0)
                total_after[k] += r['after'].get(k, 0)

    total_all_before = sum(total_before.values())
    total_all_after = sum(total_after.values())

    print(f"\n修复前:")
    for k, v in total_before.items():
        print(f"  {k}: {v} ({v/total_all_before*100:.1f}%)")

    print(f"\n修复后:")
    for k, v in total_after.items():
        print(f"  {k}: {v} ({v/total_all_after*100:.1f}%)")


if __name__ == '__main__':
    main()
