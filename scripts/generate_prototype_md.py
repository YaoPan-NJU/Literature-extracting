#!/usr/bin/env python3
"""
将聚合结果渲染为 prototype.md 格式。

输入：outputs/prototypes/<id>/aggregated_data.json
逻辑：按 templates/prototype-template.md 格式渲染为 Markdown
输出：prototypes/<id>/prototype.md
"""

import json
import os
import sys
from pathlib import Path


def generate_prototype_md(aggregated_data: dict, template_path: str) -> str:
    """
    将聚合结果渲染为 prototype.md 格式。

    返回: Markdown 内容
    """
    prototype_id = aggregated_data.get('prototype_id', 'unknown')
    knowledge_items = aggregated_data.get('knowledge_items', [])
    biomimetic_narrative = aggregated_data.get('biomimetic_narrative', {})
    biomimetic_metadata = aggregated_data.get('biomimetic_metadata', {})
    performance_data = aggregated_data.get('performance_data', [])
    mechanisms = aggregated_data.get('mechanisms', [])
    engineering_constraints = aggregated_data.get('engineering_constraints', [])

    # 生成 Markdown
    md_lines = []

    # 标题
    md_lines.append(f'# {prototype_id}')
    md_lines.append('')

    # 元数据
    md_lines.append('## 元数据')
    md_lines.append('')
    md_lines.append(f'- **原型 ID**: {prototype_id}')
    md_lines.append(f'- **知识条目数**: {len(knowledge_items)}')
    md_lines.append(f'- **性能数据数**: {len(performance_data)}')
    md_lines.append(f'- **机制描述数**: {len(mechanisms)}')
    md_lines.append(f'- **工程约束数**: {len(engineering_constraints)}')
    md_lines.append('')

    # 仿生元数据
    if biomimetic_metadata:
        md_lines.append('## 仿生元数据')
        md_lines.append('')
        for key, value in biomimetic_metadata.items():
            if value:
                md_lines.append(f'- **{key}**: {value}')
        md_lines.append('')

    # 仿生叙事
    if biomimetic_narrative:
        md_lines.append('## 仿生叙事')
        md_lines.append('')
        for key, value in biomimetic_narrative.items():
            if value:
                md_lines.append(f'### {key}')
                md_lines.append('')
                md_lines.append(str(value))
                md_lines.append('')

    # 性能数据
    if performance_data:
        md_lines.append('## 性能数据')
        md_lines.append('')
        md_lines.append('| 参数 | 值 | 单位 | 污染物 | 材料 | 来源 |')
        md_lines.append('|------|-----|------|--------|------|------|')

        for item in performance_data[:20]:  # 只显示前 20 条
            parameter = item.get('parameter', '')
            value = item.get('value', '')
            unit = item.get('unit', '')
            context = item.get('context', {})
            pollutant = context.get('pollutant', '')
            material = context.get('material', '')
            source = item.get('source', '')
            ref_doi = item.get('ref_doi', '')
            patent_number = item.get('patent_number', '')
            standard_number = item.get('standard_number', '')

            # 构建来源标识
            source_id = ref_doi or patent_number or standard_number or ''
            if source_id:
                source_str = f'{source}: {source_id}'
            else:
                source_str = source

            md_lines.append(f'| {parameter} | {value} | {unit} | {pollutant} | {material} | {source_str} |')

        md_lines.append('')

    # 机制描述
    if mechanisms:
        md_lines.append('## 吸附机制')
        md_lines.append('')
        for item in mechanisms[:10]:  # 只显示前 10 条
            parameter = item.get('parameter', '')
            value = item.get('value', '')
            context = item.get('context', {})
            source = item.get('source', '')
            ref_doi = item.get('ref_doi', '')

            md_lines.append(f'- **{parameter}**: {value}')
            if context:
                md_lines.append(f'  - 条件: {context}')
            if ref_doi:
                md_lines.append(f'  - 来源: {source}: {ref_doi}')

        md_lines.append('')

    # 工程约束
    if engineering_constraints:
        md_lines.append('## 工程约束')
        md_lines.append('')
        for item in engineering_constraints[:10]:  # 只显示前 10 条
            parameter = item.get('parameter', '')
            value = item.get('value', '')
            unit = item.get('unit', '')
            context = item.get('context', {})
            source = item.get('source', '')
            ref_doi = item.get('ref_doi', '')

            md_lines.append(f'- **{parameter}**: {value} {unit}')
            if context:
                md_lines.append(f'  - 条件: {context}')
            if ref_doi:
                md_lines.append(f'  - 来源: {source}: {ref_doi}')

        md_lines.append('')

    # 来源汇总
    md_lines.append('## 来源汇总')
    md_lines.append('')
    sources = set()
    for item in knowledge_items:
        source = item.get('source', '')
        ref_doi = item.get('ref_doi', '')
        patent_number = item.get('patent_number', '')
        standard_number = item.get('standard_number', '')

        if ref_doi:
            sources.add(f'{source}: {ref_doi}')
        elif patent_number:
            sources.add(f'{source}: {patent_number}')
        elif standard_number:
            sources.add(f'{source}: {standard_number}')
        elif source:
            sources.add(source)

    for source in sorted(sources):
        md_lines.append(f'- {source}')

    md_lines.append('')

    return '\n'.join(md_lines)


def main():
    import argparse
    parser = argparse.ArgumentParser(description='将聚合结果渲染为 prototype.md')
    parser.add_argument('--aggregated-dir', default=None, help='聚合数据目录')
    parser.add_argument('--output-dir', default=None, help='输出目录')
    parser.add_argument('--template', default=None, help='模板文件路径')
    args = parser.parse_args()

    # 默认路径
    repo_dir = Path(__file__).resolve().parents[1]
    aggregated_dir = args.aggregated_dir or str(repo_dir / 'outputs' / 'prototypes')
    output_dir = args.output_dir or str(repo_dir.parent / 'prototypes')
    template_path = args.template or str(repo_dir.parent / 'templates' / 'prototype-template.md')

    if not os.path.exists(aggregated_dir):
        print(f"ERROR: 聚合数据目录不存在: {aggregated_dir}")
        sys.exit(1)

    # 查找所有聚合数据文件
    aggregated_files = []
    for root, dirs, files in os.walk(aggregated_dir):
        for file in files:
            if file == 'aggregated_data.json':
                aggregated_files.append(os.path.join(root, file))

    print(f"找到 {len(aggregated_files)} 个聚合数据文件")

    # 生成 prototype.md
    for aggregated_file in aggregated_files:
        try:
            with open(aggregated_file, 'r', encoding='utf-8') as f:
                aggregated_data = json.load(f)

            prototype_id = aggregated_data.get('prototype_id', 'unknown')
            print(f"\n处理原型: {prototype_id}")

            # 生成 Markdown
            md_content = generate_prototype_md(aggregated_data, template_path)

            # 保存文件
            prototype_dir = os.path.join(output_dir, prototype_id)
            os.makedirs(prototype_dir, exist_ok=True)

            output_path = os.path.join(prototype_dir, 'prototype.md')
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(md_content)

            print(f"  保存到: {output_path}")
            print(f"  行数: {len(md_content.splitlines())}")

        except Exception as e:
            print(f"处理 {aggregated_file} 时出错: {e}", file=sys.stderr)

    print(f"\n完成! 共生成 {len(aggregated_files)} 个 prototype.md")


if __name__ == '__main__':
    main()
