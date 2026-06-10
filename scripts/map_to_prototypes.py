#!/usr/bin/env python3
"""
将 LitExtract JSON 文件映射到仿生设计库的原型 ID。

输入：outputs/extractions/ 下的所有 JSON
逻辑：读取每个 JSON 的 routing.prototype_targets，按 prototype_id 分组
输出：outputs/prototype_mapping.json（每个原型 → 对应的 JSON 文件列表）
"""

import json
import os
import sys
import glob
from pathlib import Path
from collections import defaultdict

# ID 别名归一化：LLM 路由可能产生的非标准 ID → feature-mapping 规范 ID
ID_ALIASES = {
    'mof-adsorbent': 'metal-organic-framework',
    'alginate-adsorbent': 'alginate',
    'starch-adsorbent': 'starch-granule',
    'chlorella': 'chlorella-cell-wall',
    'wood-structure': 'wood-xylem',
    'superhydrophobic-surface': 'superhydrophobic-artificial',
    'diatom': 'diatom-frustule',
    'diatom-inspired-porous': 'diatom-frustule',
}


def normalize_id(raw_id: str) -> str:
    """将别名 ID 归一化为规范 ID。"""
    return ID_ALIASES.get(raw_id, raw_id)


def map_to_prototypes(json_dir: str) -> dict:
    """
    将 JSON 文件映射到原型 ID。

    返回: {prototype_id: [json_file_path, ...]}
    """
    prototype_mapping = defaultdict(list)

    # 关键词到原型的映射
    keyword_to_prototype = {
        'sulfate-reducing': 'sulfate-reducing-bacteria',
        'sulfate reducing': 'sulfate-reducing-bacteria',
        'SRB': 'sulfate-reducing-bacteria',
        'iron-oxidizing': 'iron-oxidizing-bacteria',
        'iron oxidizing': 'iron-oxidizing-bacteria',
        'magnetic bacteria': 'magnetic-bacteria',
        'magnetotactic': 'magnetic-bacteria',
        'chitosan': 'chitosan',
        '壳聚糖': 'chitosan',
        'lotus': 'lotus-leaf',
        '荷叶': 'lotus-leaf',
        'mussel': 'mussel-foot-adhesion',
        '贻贝': 'mussel-foot-adhesion',
        'diatom': 'diatom-frustule',
        '硅藻': 'diatom-frustule',
        'MOF': 'metal-organic-framework',
        'metal-organic framework': 'metal-organic-framework',
        '金属有机框架': 'metal-organic-framework',
        'alginate': 'alginate',
        '海藻酸': 'alginate',
        'cellulose': 'cellulose-nanocrystal',
        '纤维素': 'cellulose-nanocrystal',
        'starch': 'starch-granule',
        '淀粉': 'starch-granule',
        'spider silk': 'spider-silk',
        '蜘蛛丝': 'spider-silk',
        'shark skin': 'shark-skin',
        '鲨鱼皮': 'shark-skin',
        'coral': 'coral-skeleton',
        '珊瑚': 'coral-skeleton',
        'oyster': 'oyster-shell',
        '牡蛎': 'oyster-shell',
        'wood': 'wood-xylem',
        '木材': 'wood-xylem',
        'bone': 'bone-structure',
        '骨': 'bone-structure',
        'mycelium': 'mycelium',
        '菌丝': 'mycelium',
        'silk fibroin': 'silk-fibroin',
        '丝素蛋白': 'silk-fibroin',
        'PDA': 'polydopamine-coating',
        'polydopamine': 'polydopamine-coating',
        '聚多巴胺': 'polydopamine-coating',
        'aquaporin': 'cell-membrane-ion-channel',
        '水通道蛋白': 'cell-membrane-ion-channel',
        'fish scale': 'fish-scale-hydroxyapatite',
        '鱼鳞': 'fish-scale-hydroxyapatite',
        'gecko': 'gecko-adhesion',
        '壁虎': 'gecko-adhesion',
        'mangrove': 'mangrove-root',
        '红树林': 'mangrove-root',
        'lobster': 'lobster-exoskeleton',
        '龙虾': 'lobster-exoskeleton',
        'scallop': 'scallop-shell',
        '扇贝': 'scallop-shell',
        'cactus': 'cactus-spine',
        '仙人掌': 'cactus-spine',
        'namib beetle': 'namib-beetle',
        '纳米布甲虫': 'namib-beetle',
        'water strider': 'water-strider-leg',
        '水黾': 'water-strider-leg',
        'pitcher plant': 'pitcher-plant-slippery-surface',
        '猪笼草': 'pitcher-plant-slippery-surface',
        'tannin': 'plant-tannin',
        '单宁': 'plant-tannin',
    }

    # 查找所有 JSON 文件（排除 backup 目录）
    json_files = [
        f for f in glob.glob(os.path.join(json_dir, '**/*.json'), recursive=True)
        if 'backup' not in f.lower() and 'json_backup' not in f
    ]

    for json_file in json_files:
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)

            # 获取 prototype_targets
            routing = data.get('routing', {})
            prototype_targets = routing.get('prototype_targets', [])

            if not prototype_targets:
                # 尝试从 biomimetic_organism 推导
                biomimetic_organism = routing.get('biomimetic_organism')
                if biomimetic_organism:
                    # 简单映射
                    organism_to_prototype = {
                        'mussel': 'mussel-foot-adhesion',
                        'lotus': 'lotus-leaf',
                        'lotus leaf': 'lotus-leaf',
                        'diatom': 'diatom-frustule',
                        'chitosan': 'chitosan',
                        'chlorella': 'chlorella-cell-wall',
                        'alginate': 'alginate',
                        'spider': 'spider-silk',
                        'spider silk': 'spider-silk',
                        'shark': 'shark-skin',
                        'shark skin': 'shark-skin',
                        'coral': 'coral-skeleton',
                        'coral skeleton': 'coral-skeleton',
                        'oyster': 'oyster-shell',
                        'oyster shell': 'oyster-shell',
                        'wood': 'wood-xylem',
                        'bone': 'bone-structure',
                        'mycelium': 'mycelium',
                        'silk': 'silk-fibroin',
                        'silk fibroin': 'silk-fibroin',
                        'cellulose': 'cellulose-nanocrystal',
                        'starch': 'starch-granule',
                        'MOF': 'metal-organic-framework',
                        'metal-organic framework': 'metal-organic-framework',
                        'PDA': 'polydopamine-coating',
                        'polydopamine': 'polydopamine-coating',
                        'aquaporin': 'cell-membrane-ion-channel',
                        'fish scale': 'fish-scale-hydroxyapatite',
                        'gecko': 'gecko-adhesion',
                        'mangrove': 'mangrove-root',
                        'lobster': 'lobster-exoskeleton',
                        'scallop': 'scallop-shell',
                        'cactus': 'cactus-spine',
                        'namib beetle': 'namib-beetle',
                        'water strider': 'water-strider-leg',
                        'pitcher plant': 'pitcher-plant-slippery-surface',
                        'tannin': 'plant-tannin',
                        'plant tannin': 'plant-tannin',
                        'magnetic bacteria': 'magnetic-bacteria',
                        'iron oxidizing bacteria': 'iron-oxidizing-bacteria',
                        'sulfate reducing bacteria': 'sulfate-reducing-bacteria',
                    }

                    for organism in biomimetic_organism.split(','):
                        organism = organism.strip()
                        if organism in organism_to_prototype:
                            prototype_id = organism_to_prototype[organism]
                            prototype_targets.append({
                                'prototype_id': prototype_id,
                                'confidence': 0.8,
                                'match_reason': f'从 biomimetic_organism 推导: {organism}'
                            })

            # 如果没有 prototype_targets，尝试从标题和内容推导
            if not prototype_targets:
                # 获取标题和摘要
                title = data.get('bibliographic_metadata', {}).get('title', '')
                abstract = data.get('bibliographic_metadata', {}).get('abstract', '')
                content = title + ' ' + abstract

                # 检查关键词
                for keyword, prototype_id in keyword_to_prototype.items():
                    if keyword.lower() in content.lower():
                        prototype_targets.append({
                            'prototype_id': prototype_id,
                            'confidence': 0.7,
                            'match_reason': f'从标题/摘要推导: {keyword}'
                        })

            # 添加到映射（归一化 ID + 去重）
            seen_prototypes = set()
            for target in prototype_targets:
                prototype_id = normalize_id(target.get('prototype_id', ''))
                if prototype_id and prototype_id not in seen_prototypes:
                    seen_prototypes.add(prototype_id)
                    prototype_mapping[prototype_id].append({
                        'json_file': json_file,
                        'confidence': target.get('confidence', 0.5),
                        'match_reason': target.get('match_reason', '')
                    })

        except Exception as e:
            print(f"处理 {json_file} 时出错: {e}", file=sys.stderr)

    return dict(prototype_mapping)


def main():
    import argparse
    parser = argparse.ArgumentParser(description='将 JSON 文件映射到原型 ID')
    parser.add_argument('--json-dir', default=None, help='JSON 文件目录')
    parser.add_argument('--output', default=None, help='输出文件路径')
    args = parser.parse_args()

    # 默认路径
    repo_dir = Path(__file__).resolve().parents[1]
    json_dir = args.json_dir or str(repo_dir / 'outputs' / 'extractions')
    output_path = args.output or str(repo_dir / 'outputs' / 'prototype_mapping.json')

    if not os.path.exists(json_dir):
        print(f"ERROR: 目录不存在: {json_dir}")
        sys.exit(1)

    print(f"扫描目录: {json_dir}")
    prototype_mapping = map_to_prototypes(json_dir)

    # 统计
    total_prototypes = len(prototype_mapping)
    total_files = sum(len(files) for files in prototype_mapping.values())

    print(f"\n映射结果:")
    print(f"  原型数: {total_prototypes}")
    print(f"  文件数: {total_files}")

    # 显示前 10 个原型
    print(f"\n前 10 个原型:")
    for i, (prototype_id, files) in enumerate(sorted(prototype_mapping.items())[:10]):
        print(f"  {prototype_id}: {len(files)} 个文件")

    # 保存结果
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(prototype_mapping, f, ensure_ascii=False, indent=2)

    print(f"\n结果已保存到: {output_path}")


if __name__ == '__main__':
    main()
