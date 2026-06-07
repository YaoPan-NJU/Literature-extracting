#!/usr/bin/env python3
"""
将同一原型下的所有 knowledge_items 聚合，生成结构化数据。

输入：outputs/prototype_mapping.json + 各 JSON 文件
逻辑：将同一原型下的所有 knowledge_items 聚合
输出：outputs/prototypes/<id>/aggregated_data.json
"""

import json
import os
import sys
import glob
from pathlib import Path
from collections import defaultdict


def aggregate_prototype_data(prototype_id: str, json_files: list) -> dict:
    """
    聚合同一原型下的所有 knowledge_items。

    返回: 聚合后的数据
    """
    all_knowledge_items = []
    all_biomimetic_narrative = {}
    all_biomimetic_metadata = {}
    all_performance_data = []
    all_mechanisms = []
    all_engineering_constraints = []

    for file_info in json_files:
        json_file = file_info.get('json_file')
        if not json_file or not os.path.exists(json_file):
            continue

        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)

            # 收集 knowledge_items
            knowledge_items = data.get('knowledge_items', [])
            for item in knowledge_items:
                item['_source_file'] = json_file
                all_knowledge_items.append(item)

            # 收集 biomimetic_narrative
            biomimetic_narrative = data.get('biomimetic_narrative', {})
            if biomimetic_narrative:
                all_biomimetic_narrative.update(biomimetic_narrative)

            # 收集 biomimetic_metadata
            biomimetic_metadata = data.get('biomimetic_metadata', {})
            if biomimetic_metadata:
                all_biomimetic_metadata.update(biomimetic_metadata)

            # 提取 performance_data
            for item in knowledge_items:
                parameter = item.get('parameter', '')
                if any(keyword in parameter.lower() for keyword in ['qmax', 'removal', 'adsorption capacity', '去除率', '吸附容量']):
                    all_performance_data.append({
                        'parameter': parameter,
                        'value': item.get('value'),
                        'unit': item.get('unit'),
                        'context': item.get('context', {}),
                        'source': item.get('source', 'literature'),
                        'ref_doi': item.get('ref_doi'),
                        'patent_number': item.get('patent_number'),
                        'standard_number': item.get('standard_number'),
                        'source_file': item.get('source_file')
                    })

            # 提取 mechanisms
            for item in knowledge_items:
                parameter = item.get('parameter', '')
                if any(keyword in parameter.lower() for keyword in ['mechanism', 'adsorption mechanism', '吸附机制', '机理']):
                    all_mechanisms.append({
                        'parameter': parameter,
                        'value': item.get('value'),
                        'context': item.get('context', {}),
                        'source': item.get('source', 'literature'),
                        'ref_doi': item.get('ref_doi')
                    })

            # 提取 engineering_constraints
            for item in knowledge_items:
                parameter = item.get('parameter', '')
                if any(keyword in parameter.lower() for keyword in ['ph', 'temperature', '再生', '循环', '稳定性', 'regeneration', 'stability']):
                    all_engineering_constraints.append({
                        'parameter': parameter,
                        'value': item.get('value'),
                        'unit': item.get('unit'),
                        'context': item.get('context', {}),
                        'source': item.get('source', 'literature'),
                        'ref_doi': item.get('ref_doi')
                    })

        except Exception as e:
            print(f"处理 {json_file} 时出错: {e}", file=sys.stderr)

    # 聚合结果
    aggregated_data = {
        'prototype_id': prototype_id,
        'total_knowledge_items': len(all_knowledge_items),
        'total_source_files': len(json_files),
        'knowledge_items': all_knowledge_items,
        'biomimetic_narrative': all_biomimetic_narrative,
        'biomimetic_metadata': all_biomimetic_metadata,
        'performance_data': all_performance_data,
        'mechanisms': all_mechanisms,
        'engineering_constraints': all_engineering_constraints
    }

    return aggregated_data


def main():
    import argparse
    parser = argparse.ArgumentParser(description='聚合同一原型下的所有 knowledge_items')
    parser.add_argument('--mapping', default=None, help='原型映射文件路径')
    parser.add_argument('--output-dir', default=None, help='输出目录')
    args = parser.parse_args()

    # 默认路径
    repo_dir = Path(__file__).resolve().parents[1]
    mapping_path = args.mapping or str(repo_dir / 'outputs' / 'prototype_mapping.json')
    output_dir = args.output_dir or str(repo_dir / 'outputs' / 'prototypes')

    if not os.path.exists(mapping_path):
        print(f"ERROR: 映射文件不存在: {mapping_path}")
        sys.exit(1)

    # 读取映射
    with open(mapping_path, 'r', encoding='utf-8') as f:
        prototype_mapping = json.load(f)

    print(f"加载映射: {len(prototype_mapping)} 个原型")

    # 创建输出目录
    os.makedirs(output_dir, exist_ok=True)

    # 聚合每个原型
    for prototype_id, json_files in prototype_mapping.items():
        print(f"\n处理原型: {prototype_id} ({len(json_files)} 个文件)")

        # 聚合数据
        aggregated_data = aggregate_prototype_data(prototype_id, json_files)

        # 保存结果
        prototype_dir = os.path.join(output_dir, prototype_id)
        os.makedirs(prototype_dir, exist_ok=True)

        output_path = os.path.join(prototype_dir, 'aggregated_data.json')
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(aggregated_data, f, ensure_ascii=False, indent=2)

        print(f"  保存到: {output_path}")
        print(f"  knowledge_items: {aggregated_data['total_knowledge_items']}")
        print(f"  performance_data: {len(aggregated_data['performance_data'])}")
        print(f"  mechanisms: {len(aggregated_data['mechanisms'])}")

    print(f"\n完成! 共处理 {len(prototype_mapping)} 个原型")


if __name__ == '__main__':
    main()
