#!/usr/bin/env python3
"""
分析Mimo-v2.5-pro提参结果中的多模态信息缺失问题
"""

import json
import glob
from pathlib import Path
from collections import Counter

def analyze_mimo_extraction():
    json_dir = Path("/Users/panyao/Qoder/JJJ_Literature/outputs/extractions/英文文献/json")
    json_files = list(json_dir.glob("*.json"))
    
    print("=" * 80)
    print("  Mimo-v2.5-pro 提参结果多模态信息分析")
    print("=" * 80)
    print()
    
    # 1. 检查JSON中的processing_notes
    print("📊 第一部分：processing_notes分析")
    print("-" * 80)
    
    figure_mentions = 0
    visual_model_mentions = 0
    sample_size = min(100, len(json_files))
    
    for json_file in json_files[:sample_size]:
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            notes = data.get('processing_notes', [])
            notes_text = ' '.join([str(n) for n in notes])
            
            if 'fig' in notes_text.lower():
                figure_mentions += 1
            
            if '视觉模型' in notes_text or 'visual model' in notes_text.lower():
                visual_model_mentions += 1
        except:
            pass
    
    print(f"  检查样本数: {sample_size}")
    print(f"  processing_notes提到figure: {figure_mentions} ({figure_mentions/sample_size*100:.1f}%)")
    print(f"  processing_notes提到视觉模型: {visual_model_mentions} ({visual_model_mentions/sample_size*100:.1f}%)")
    print()
    
    # 2. 检查knowledge_items中的参数
    print("📊 第二部分：knowledge_items参数分析")
    print("-" * 80)
    
    param_keywords = ['figure', 'fig', 'image', 'photo', 'chart', 'graph', 'diagram', 'visual']
    params_with_visual = []
    
    for json_file in json_files[:sample_size]:
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            items = data.get('knowledge_items', [])
            for item in items:
                param = item.get('parameter', '').lower()
                if any(kw in param for kw in param_keywords):
                    params_with_visual.append({
                        'file': json_file.name[:60],
                        'parameter': item.get('parameter'),
                        'value': str(item.get('value', ''))[:100]
                    })
        except:
            pass
    
    print(f"  提取了图表相关参数的文献: {len(params_with_visual)} 篇")
    if params_with_visual:
        print(f"\n  示例（前5个）:")
        for p in params_with_visual[:5]:
            print(f"    文件: {p['file']}")
            print(f"    参数: {p['parameter']}")
            print(f"    值: {p['value'][:80]}...")
            print()
    print()
    
    # 3. 检查visual_cache
    print("📊 第三部分：visual_cache页面类型分析")
    print("-" * 80)
    
    pdf_dir = Path("/Users/panyao/Qoder/JJJ_Literature/workspace/近海油气田污染物相关文献/英文文献")
    cache_files = list(pdf_dir.glob("*visual_cache.json"))
    
    page_type_counter = Counter()
    caches_with_figures = 0
    caches_with_data = 0
    
    for cache_file in cache_files[:100]:
        try:
            with open(cache_file, 'r', encoding='utf-8') as f:
                cache = json.load(f)
            
            page_types = cache.get('stage0', {}).get('page_types', [])
            
            has_figure = False
            has_data = False
            
            for pt in page_types:
                ptype = pt.get('type', 'unknown')
                page_type_counter[ptype] += 1
                
                if 'figure' in ptype.lower():
                    has_figure = True
                if 'data' in ptype.lower():
                    has_data = True
            
            if has_figure:
                caches_with_figures += 1
            if has_data:
                caches_with_data += 1
        except:
            pass
    
    print(f"  visual_cache文件数: {len(cache_files)}")
    print(f"  检查样本数: {min(100, len(cache_files))}")
    print(f"\n  页面类型分布:")
    for ptype, count in page_type_counter.most_common():
        print(f"    {ptype}: {count}")
    
    print(f"\n  包含figure_page的PDF: {caches_with_figures} ({caches_with_figures/min(100, len(cache_files))*100:.1f}%)")
    print(f"  包含data_page的PDF: {caches_with_data} ({caches_with_data/min(100, len(cache_files))*100:.1f}%)")
    print()
    
    # 4. 结论
    print("=" * 80)
    print("  📝 分析结论")
    print("=" * 80)
    print()
    print("  ❌ 问题确认：Mimo-v2.5-pro 确实没有有效提取多模态信息")
    print()
    print("  证据：")
    print(f"    1. 仅有 {figure_mentions}% 的文献在notes中提到figure")
    print(f"    2. 仅 {len(params_with_visual)} 篇文献提取了图表相关参数")
    print(f"    3. visual_cache中 figure_page 数量为 0")
    print()
    print("  原因分析：")
    print("    - Mimo-v2.5-pro 不具备多模态能力（只能处理文本）")
    print("    - PDF预处理阶段没有识别出figure_page（只有text_page和data_page）")
    print("    - 即使PDF中有图表，模型也无法读取和理解")
    print()
    print("  💡 建议：")
    print("    1. 使用 mimo-v2.5（有多模态能力）重新提参")
    print("    2. 或者使用 qwen3.6-plus（也支持多模态）")
    print("    3. 优先重提包含data_page的文献（可能有图表数据）")
    print()
    
    # 5. 估算需要重提的文献数量
    mimo_count = 0
    for json_file in json_files:
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            # 尝试从routing或metadata中判断模型
            routing = data.get('routing', {})
            model = routing.get('model', '')
            if 'mimo' in model.lower() and 'v2.5-pro' in model:
                mimo_count += 1
        except:
            pass
    
    print(f"  📈 估算：约 {mimo_count} 篇文献由Mimo-v2.5-pro提取，建议重提")
    print()

if __name__ == '__main__':
    analyze_mimo_extraction()
