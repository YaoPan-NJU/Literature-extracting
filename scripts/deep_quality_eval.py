#!/usr/bin/env python3
"""
深度质量评估脚本 - 逐篇读取内容，用LLM评估提取质量
"""
import json
import os
import sys
import glob
import random
from datetime import datetime

# 评估prompt模板
EVAL_PROMPT = """你是一个学术文献提取质量评估专家。请仔细阅读以下JSON提取结果，评估其质量。

## 评估维度（每项0-10分）

1. **信息完整性**（0-10）：是否完整提取了原文的核心信息？有无重大遗漏？
2. **参数准确性**（0-10）：提取的参数值、单位、上下文是否准确？有无明显错误？
3. **领域相关性**（0-10）：与"近海油气田多介质污染物特征与控制"领域的相关程度？
4. **知识可用性**（0-10）：提取的知识条目能否直接用于决策平台的知识库？
5. **证据链完整性**（0-10）：是否有原文证据支撑？证据是否可追溯？

## 评估要求
- 仔细阅读每个knowledge_item的内容
- 检查参数值是否合理（比如浓度、温度、压力等是否在合理范围）
- 检查单位是否正确
- 检查领域方向标注是否准确
- 检查relevance_level是否合理
- 给出每个维度的具体评分和理由

## 输出格式
请严格按以下JSON格式输出：
```json
{
  "completeness": {"score": X, "reason": "..."},
  "accuracy": {"score": X, "reason": "..."},
  "relevance": {"score": X, "reason": "..."},
  "usability": {"score": X, "reason": "..."},
  "evidence": {"score": X, "reason": "..."},
  "total_score": X,
  "grade": "A/B/C/D/E",
  "key_issues": ["问题1", "问题2"],
  "recommendation": "入库/需修正/不入库"
}
```

## 被评估的JSON内容
"""

def evaluate_file(filepath, model="mimo/mimo-v2.5-pro"):
    """用LLM评估单个文件"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        return {"error": f"JSON解析失败: {e}"}
    
    # 截取关键部分（避免token过多）
    eval_data = {
        "schema_version": data.get("schema_version"),
        "paper_id": data.get("paper_id"),
        "bibliographic_metadata": data.get("bibliographic_metadata"),
        "routing": data.get("routing"),
        "decision_summary": data.get("decision_summary"),
        "knowledge_items": data.get("knowledge_items", [])[:10],  # 最多取10条
        "quality_control": data.get("quality_control"),
    }
    
    json_str = json.dumps(eval_data, ensure_ascii=False, indent=2)
    
    # 如果太长，进一步截断
    if len(json_str) > 8000:
        eval_data["knowledge_items"] = eval_data["knowledge_items"][:5]
        json_str = json.dumps(eval_data, ensure_ascii=False, indent=2)
    
    prompt = EVAL_PROMPT + json_str
    
    # 这里返回prompt，由调用者发送给LLM
    return {"prompt": prompt, "file": os.path.basename(filepath), "data": eval_data}

def main():
    base_dir = '/Users/panyao/Qoder/JJJ_Literature/outputs/extractions'
    
    # 分层抽样
    dirs = {
        '英文文献_R1': os.path.join(base_dir, '英文文献', 'json'),
        '英文文献_R2': os.path.join(base_dir, '英文文献', 'json'),
        '英文文献_R3': os.path.join(base_dir, '英文文献', 'json'),
        '中文文献': os.path.join(base_dir, '中文文献', 'json'),
        '专利': os.path.join(base_dir, '专利', 'json'),
        '书本/中文': os.path.join(base_dir, '书本', '中文', 'json'),
        '书本/英文': os.path.join(base_dir, '书本', '英文', 'json'),
    }
    
    # 收集所有文件并按相关性分类
    all_files = {}
    for d in dirs.values():
        for f in glob.glob(os.path.join(d, '*.json')):
            try:
                data = json.load(open(f, 'r'))
                rel = data.get('routing', {}).get('relevance_level', 'unknown')
                key = f"{os.path.basename(os.path.dirname(os.path.dirname(f)))}_{rel}"
                if key not in all_files:
                    all_files[key] = []
                all_files[key].append(f)
            except:
                pass
    
    # 每个类别抽样2-3篇
    random.seed(42)
    samples = []
    for key, files in sorted(all_files.items()):
        n = min(3, len(files))
        sampled = random.sample(files, n)
        for f in sampled:
            data = json.load(open(f, 'r'))
            ki_count = len(data.get('knowledge_items', []) or [])
            title = data.get('bibliographic_metadata', {}).get('title', '')[:80]
            samples.append({
                'file': f,
                'category': key,
                'title': title,
                'ki_count': ki_count,
                'relevance': data.get('routing', {}).get('relevance_level', 'unknown')
            })
    
    # 输出抽样列表
    print(f"共抽取 {len(samples)} 篇进行深度评估")
    print()
    
    # 保存抽样结果
    with open(os.path.join(base_dir, 'eval_samples.json'), 'w', encoding='utf-8') as f:
        json.dump(samples, f, ensure_ascii=False, indent=2)
    
    # 输出每篇的评估prompt
    for i, s in enumerate(samples):
        result = evaluate_file(s['file'])
        print(f"=== [{i+1}/{len(samples)}] {s['category']} ===")
        print(f"文件: {os.path.basename(s['file'])}")
        print(f"标题: {s['title']}")
        print(f"KI数: {s['ki_count']}, 相关性: {s['relevance']}")
        print()

if __name__ == '__main__':
    main()
