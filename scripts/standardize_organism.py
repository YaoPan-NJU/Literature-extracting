#!/usr/bin/env python3
"""
标准化 biomimetic_organism 命名。

问题分析：
- 总唯一值: 101
- "lotus leaf" 和 "lotus" 是两个值
- 有些写多个生物（如 "mussel;bacteria;plants"）

标准化规则：
1. 统一小写
2. 统一命名（如 "lotus" → "lotus leaf"）
3. 拆分多个生物为单独条目
4. 移除噪声（如 "schwertmannite(施氏矿物，天然铁硫酸盐次生矿物)"）
"""

import json
import os
import sys
import glob

# 标准命名映射表
ORGANISM_MAPPING = {
    # 荷叶
    'lotus': 'lotus leaf',
    'lotus leaf': 'lotus leaf',
    'lotus leaves': 'lotus leaf',
    'nelumbo nucifera': 'lotus leaf',

    # 贻贝
    'mussel': 'mussel',
    'mussels': 'mussel',
    'mytilus edulis': 'mussel',
    'mussel foot': 'mussel',
    'mussel foot protein': 'mussel',
    'mussel-inspired': 'mussel',

    # 硅藻
    'diatom': 'diatom',
    'diatoms': 'diatom',
    'diatom frustule': 'diatom',
    'diatomite': 'diatom',

    # 蜘蛛丝
    'spider silk': 'spider silk',
    'spider': 'spider silk',

    # 鲨鱼皮
    'shark skin': 'shark skin',
    'shark': 'shark skin',
    'sharklet': 'shark skin',

    # 猪笼草
    'nepenthes': 'pitcher plant',
    'nepenthes alata': 'pitcher plant',
    'pitcher plant': 'pitcher plant',
    'pitcher-plant': 'pitcher plant',
    'slippery surface': 'pitcher plant',

    # 玫瑰花瓣
    'rose petal': 'rose petal',
    'rose': 'rose petal',

    # 水稻叶
    'rice leaf': 'rice leaf',
    'rice': 'rice leaf',

    # 水通道蛋白
    'aquaporin': 'aquaporin',
    'aquaporins': 'aquaporin',

    # 牡蛎
    'oyster': 'oyster shell',
    'oyster shell': 'oyster shell',
    'oyster-shell': 'oyster shell',

    # 鱼鳞
    'fish scale': 'fish scale',
    'fish scales': 'fish scale',

    # 壁虎
    'gecko': 'gecko',
    'gecko feet': 'gecko',
    'gecko-inspired': 'gecko',

    # 水黾
    'water strider': 'water strider',
    'water-strider': 'water strider',

    # 仙人掌
    'cactus': 'cactus spine',
    'cactus spine': 'cactus spine',

    # 红树林
    'mangrove': 'mangrove root',
    'mangrove root': 'mangrove root',

    # 壳聚糖
    'chitosan': 'chitosan',

    # 海藻酸钠
    'alginate': 'alginate',
    'sodium alginate': 'alginate',

    # 纤维素
    'cellulose': 'cellulose',
    'nanocellulose': 'cellulose',
    'cellulose nanocrystal': 'cellulose',

    # 蚕丝
    'silk fibroin': 'silk fibroin',
    'silk': 'silk fibroin',
    'silkworm silk': 'silk fibroin',

    # 菌丝体
    'mycelium': 'mycelium',
    'fungal biomass': 'mycelium',
    'fungus': 'mycelium',

    # 细菌
    'sulfate-reducing bacteria': 'sulfate-reducing bacteria',
    'srb': 'sulfate-reducing bacteria',
    'iron-oxidizing bacteria': 'iron-oxidizing bacteria',
    'magnetic bacteria': 'magnetic bacteria',
    'magnetotactic bacteria': 'magnetic bacteria',

    # 小球藻
    'chlorella': 'chlorella',
    'microalgae': 'chlorella',
    'algae': 'chlorella',

    # 珊瑚
    'coral': 'coral skeleton',
    'coral skeleton': 'coral skeleton',

    # 木材
    'wood': 'wood xylem',
    'wood xylem': 'wood xylem',

    # 骨骼
    'bone': 'bone structure',
    'bone structure': 'bone structure',
    'hydroxyapatite': 'hydroxyapatite',

    # MOF
    'mof': 'metal-organic framework',
    'metal-organic framework': 'metal-organic framework',
    'metal organic framework': 'metal-organic framework',

    # 淀粉
    'starch': 'starch',

    # 单宁
    'tannin': 'plant tannin',
    'plant tannin': 'plant tannin',

    # 龙虾
    'lobster': 'lobster exoskeleton',
    'lobster exoskeleton': 'lobster exoskeleton',

    # 扇贝
    'scallop': 'scallop shell',
    'scallop shell': 'scallop shell',

    # 施氏矿物
    'schwertmannite': 'schwertmannite',
    'ferrihydrite': 'ferrihydrite',

    # 其他
    'superhydrophobic surface': 'superhydrophobic surface',
    'bioinspired': None,  # 太泛，不映射
    'biomimetic': None,  # 太泛，不映射
    'nature-inspired': None,
    'biologically inspired': None,
}

# 标准原型 ID 映射
ORGANISM_TO_PROTOTYPE = {
    'lotus leaf': 'lotus-leaf',
    'mussel': 'mussel-foot-adhesion',
    'diatom': 'diatom-frustule',
    'spider silk': 'spider-silk',
    'shark skin': 'shark-skin',
    'pitcher plant': 'pitcher-plant-slippery-surface',
    'rose petal': None,  # 无对应原型
    'rice leaf': None,
    'aquaporin': 'cell-membrane-ion-channel',
    'oyster shell': 'oyster-shell',
    'fish scale': 'fish-scale-hydroxyapatite',
    'gecko': None,
    'water strider': 'water-strider-leg',
    'cactus spine': 'cactus-spine',
    'mangrove root': 'mangrove-root',
    'chitosan': 'chitosan',
    'alginate': 'alginate',
    'cellulose': 'cellulose-nanocrystal',
    'silk fibroin': 'silk-fibroin',
    'mycelium': 'mycelium',
    'sulfate-reducing bacteria': 'sulfate-reducing-bacteria',
    'iron-oxidizing bacteria': 'iron-oxidizing-bacteria',
    'magnetic bacteria': 'magnetic-bacteria',
    'chlorella': 'chlorella-cell-wall',
    'coral skeleton': 'coral-skeleton',
    'wood xylem': 'wood-xylem',
    'bone structure': 'bone-structure',
    'hydroxyapatite': 'hydroxyapatite-adsorbent',
    'metal-organic framework': 'metal-organic-framework',
    'starch': 'starch-granule',
    'plant tannin': 'plant-tannin',
    'lobster exoskeleton': 'lobster-exoskeleton',
    'scallop shell': 'scallop-shell',
    'schwertmannite': None,
    'ferrihydrite': None,
    'superhydrophobic surface': 'superhydrophobic-artificial',
}


def standardize_organism(raw_organism: str) -> list:
    """
    标准化生物名称。

    返回: 标准化后的生物名称列表
    """
    if not raw_organism:
        return []

    # 分割多个生物
    separators = [';', ',', '/', '、', '；']
    organisms = [raw_organism]
    for sep in separators:
        new_organisms = []
        for org in organisms:
            new_organisms.extend(org.split(sep))
        organisms = new_organisms

    # 标准化每个生物
    standardized = []
    for org in organisms:
        org = org.strip().lower()
        if not org:
            continue

        # 查找映射
        mapped = ORGANISM_MAPPING.get(org)
        if mapped is None:
            continue  # 跳过无法映射的
        if mapped:
            standardized.append(mapped)
        else:
            # 尝试模糊匹配
            for key, value in ORGANISM_MAPPING.items():
                if key in org or org in key:
                    if value:
                        standardized.append(value)
                        break

    # 去重
    return list(set(standardized))


def get_prototype_targets(organisms: list) -> list:
    """
    从标准化后的生物名称获取原型 ID。

    返回: prototype_targets 列表
    """
    targets = []
    for org in organisms:
        prototype_id = ORGANISM_TO_PROTOTYPE.get(org)
        if prototype_id:
            targets.append({
                'prototype_id': prototype_id,
                'confidence': 0.9,
                'match_reason': f'从 biomimetic_organism "{org}" 映射'
            })
    return targets


def standardize_json_file(json_path: str, dry_run: bool = False) -> dict:
    """标准化单个 JSON 文件的 biomimetic_organism"""
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    routing = data.get('routing', {})
    raw_organism = routing.get('biomimetic_organism', '')

    if not raw_organism:
        return {'file': os.path.basename(json_path), 'status': 'skip', 'reason': 'no organism'}

    # 标准化
    standardized = standardize_organism(raw_organism)

    if not standardized:
        return {'file': os.path.basename(json_path), 'status': 'skip', 'reason': 'no mapping'}

    # 更新 routing
    routing['biomimetic_organism'] = ', '.join(standardized)

    # 添加 prototype_targets（如果不存在）
    if 'prototype_targets' not in routing:
        routing['prototype_targets'] = get_prototype_targets(standardized)

    # 保存
    if not dry_run:
        data['routing'] = routing
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')

    return {
        'file': os.path.basename(json_path),
        'status': 'standardized',
        'before': raw_organism,
        'after': ', '.join(standardized),
        'prototype_targets': len(routing.get('prototype_targets', []))
    }


def main():
    import argparse
    parser = argparse.ArgumentParser(description='标准化 biomimetic_organism 命名')
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
            report = standardize_json_file(json_file, dry_run=args.dry_run)
            reports.append(report)
        except Exception as e:
            reports.append({
                'file': os.path.basename(json_file),
                'status': 'error',
                'error': str(e)
            })

    # 输出报告
    print("=" * 60)
    print("标准化报告")
    print("=" * 60)

    standardized_count = sum(1 for r in reports if r['status'] == 'standardized')
    skipped_count = sum(1 for r in reports if r['status'] == 'skip')
    error_count = sum(1 for r in reports if r['status'] == 'error')

    print(f"\n总文件: {len(reports)}")
    print(f"已标准化: {standardized_count}")
    print(f"跳过: {skipped_count}")
    print(f"错误: {error_count}")

    # 统计标准化后的唯一值
    all_organisms = set()
    total_prototype_targets = 0
    for r in reports:
        if r['status'] == 'standardized':
            for org in r['after'].split(', '):
                all_organisms.add(org)
            total_prototype_targets += r.get('prototype_targets', 0)

    print(f"\n标准化后:")
    print(f"  唯一生物: {len(all_organisms)}")
    print(f"  总 prototype_targets: {total_prototype_targets}")

    # 显示标准化样例
    print(f"\n标准化样例 (前10):")
    for r in [r for r in reports if r['status'] == 'standardized'][:10]:
        print(f"  {r['file'][:40]}: {r['before']} → {r['after']}")


if __name__ == '__main__':
    main()
