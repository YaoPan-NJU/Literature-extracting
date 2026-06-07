#!/usr/bin/env python3
"""
修复 knowledge_items 中的 context/evidence 泄漏问题。

问题分析：
- 泄漏的 context 对象: 如 {"material": "...", "isotherm_model": "..."}
- 泄漏的 evidence 对象: 如 {"page": 1, "locator": "...", "evidence_text": "..."}
- 真正空的 items: 所有字段都是 None

修复策略：
1. 识别泄漏的 context/evidence 对象
2. 尝试将泄漏对象与有效 items 关联（通过位置或 record_id）
3. 无法关联的标记为 orphaned 并移除
"""

import json
import os
import sys
import glob
from pathlib import Path


def is_valid_item(item: dict) -> bool:
    """检查是否是有效的 knowledge_item"""
    return bool(item.get('parameter') or item.get('value'))


def is_leaked_context(item: dict) -> bool:
    """检查是否是泄漏的 context 对象"""
    context_keys = {'material', 'isotherm_model', 'pollutant', 'mechanism',
                    'initial_concentration', 'ph', 'temperature', 'kinetics_model'}
    return any(k in item for k in context_keys) and not is_valid_item(item)


def is_leaked_evidence(item: dict) -> bool:
    """检查是否是泄漏的 evidence 对象"""
    evidence_keys = {'page', 'locator', 'evidence_text', 'quality'}
    return any(k in item for k in evidence_keys) and not is_valid_item(item)


def is_empty_item(item: dict) -> bool:
    """检查是否是真正空的 item"""
    return not any(v is not None for v in item.values())


def try_merge_leaked_items(items: list) -> tuple:
    """
    尝试将泄漏的 context/evidence 对象合并到有效 items 中。

    返回: (fixed_items, orphaned_count)
    """
    valid_items = []
    leaked_contexts = []
    leaked_evidences = []
    empty_items = []

    # 分类
    for item in items:
        if is_valid_item(item):
            valid_items.append(item)
        elif is_leaked_context(item):
            leaked_contexts.append(item)
        elif is_leaked_evidence(item):
            leaked_evidences.append(item)
        elif is_empty_item(item):
            empty_items.append(item)
        else:
            # 无法分类，当作泄漏的 context
            leaked_contexts.append(item)

    # 尝试合并
    orphaned_count = 0

    # 策略1: 按位置关联（泄漏对象通常紧跟在有效对象后面）
    for i, valid_item in enumerate(valid_items):
        # 检查是否有泄漏的 context 需要合并
        if i < len(leaked_contexts):
            ctx = leaked_contexts[i]
            if 'context' not in valid_item or not valid_item['context']:
                valid_item['context'] = ctx
            else:
                # 合并 context
                for k, v in ctx.items():
                    if k not in valid_item['context']:
                        valid_item['context'][k] = v

        # 检查是否有泄漏的 evidence 需要合并
        if i < len(leaked_evidences):
            ev = leaked_evidences[i]
            if 'evidence' not in valid_item or not valid_item['evidence']:
                valid_item['evidence'] = [ev]
            else:
                # 检查是否重复
                if ev not in valid_item['evidence']:
                    valid_item['evidence'].append(ev)

    # 计算无法关联的泄漏对象
    orphaned_count = max(0, len(leaked_contexts) - len(valid_items)) + \
                     max(0, len(leaked_evidences) - len(valid_items)) + \
                     len(empty_items)

    return valid_items, orphaned_count


def fix_routing_nested_data(data: dict) -> bool:
    """
    修复 routing 对象内部嵌套完整知识数据的问题。

    问题：routing 对象内部错误地嵌套了 decision_summary、knowledge_items、
    vector_index_records、quality_control 四个顶层字段。

    修复：删除 routing 内部的这些字段（保留顶层版本）。
    """
    routing = data.get('routing', {})
    if not routing:
        return False

    # 检查 routing 内部是否包含顶层字段
    nested_keys = {'decision_summary', 'knowledge_items', 'vector_index_records', 'quality_control'}
    found_keys = nested_keys.intersection(routing.keys())

    if not found_keys:
        return False

    # 删除 routing 内部的嵌套字段
    for key in found_keys:
        del routing[key]

    return True


def fix_json_file(json_path: str, dry_run: bool = False) -> dict:
    """
    修复单个 JSON 文件。

    返回: 修复报告
    """
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 修复 routing 嵌套问题
    routing_fixed = fix_routing_nested_data(data)

    items = data.get('knowledge_items', [])
    if not items and not routing_fixed:
        return {'file': json_path, 'status': 'skip', 'reason': 'no knowledge_items'}

    # 统计修复前
    before_total = len(items)
    before_valid = sum(1 for item in items if is_valid_item(item))
    before_leaked_ctx = sum(1 for item in items if is_leaked_context(item))
    before_leaked_ev = sum(1 for item in items if is_leaked_evidence(item))
    before_empty = sum(1 for item in items if is_empty_item(item))

    # 修复
    fixed_items, orphaned_count = try_merge_leaked_items(items)

    # 统计修复后
    after_total = len(fixed_items)
    after_valid = sum(1 for item in fixed_items if is_valid_item(item))

    # 更新 record_id
    for i, item in enumerate(fixed_items):
        item['record_id'] = f'ki_{i+1:03d}'

    # 保存
    if not dry_run:
        data['knowledge_items'] = fixed_items
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')

    return {
        'file': os.path.basename(json_path),
        'status': 'fixed' if (before_total != after_total or routing_fixed) else 'unchanged',
        'routing_fixed': routing_fixed,
        'before': {
            'total': before_total,
            'valid': before_valid,
            'leaked_context': before_leaked_ctx,
            'leaked_evidence': before_leaked_ev,
            'empty': before_empty
        },
        'after': {
            'total': after_total,
            'valid': after_valid
        },
        'orphaned': orphaned_count
    }


def main():
    import argparse
    parser = argparse.ArgumentParser(description='修复 knowledge_items 结构泄漏')
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
            report = fix_json_file(json_file, dry_run=args.dry_run)
            reports.append(report)
        except Exception as e:
            reports.append({
                'file': os.path.basename(json_file),
                'status': 'error',
                'error': str(e)
            })

    # 输出报告
    print("=" * 60)
    print("修复报告")
    print("=" * 60)

    fixed_count = sum(1 for r in reports if r['status'] == 'fixed')
    unchanged_count = sum(1 for r in reports if r['status'] == 'unchanged')
    error_count = sum(1 for r in reports if r['status'] == 'error')

    print(f"\n总文件: {len(reports)}")
    print(f"已修复: {fixed_count}")
    print(f"未变: {unchanged_count}")
    print(f"错误: {error_count}")

    # 统计修复前后的 items 数量
    total_before = sum(r['before']['total'] for r in reports if 'before' in r)
    total_after = sum(r['after']['total'] for r in reports if 'after' in r)
    total_valid_before = sum(r['before']['valid'] for r in reports if 'before' in r)
    total_valid_after = sum(r['after']['valid'] for r in reports if 'after' in r)

    print(f"\n修复前:")
    print(f"  总 items: {total_before}")
    print(f"  有效 items: {total_valid_before} ({total_valid_before/total_before*100:.1f}%)")

    print(f"\n修复后:")
    print(f"  总 items: {total_after}")
    print(f"  有效 items: {total_valid_after} ({total_valid_after/total_after*100:.1f}%)")

    # 显示变化最大的文件
    print(f"\n变化最大的文件 (前5):")
    sorted_reports = sorted(
        [r for r in reports if 'before' in r],
        key=lambda r: r['before']['total'] - r['after']['total'],
        reverse=True
    )
    for r in sorted_reports[:5]:
        diff = r['before']['total'] - r['after']['total']
        print(f"  {r['file']}: {r['before']['total']} → {r['after']['total']} (-{diff})")


if __name__ == '__main__':
    main()
