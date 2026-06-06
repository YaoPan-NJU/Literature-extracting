#!/usr/bin/env python3
"""
增量补充提取：为已提取的 JSON 补充仿生设计库所需字段。

需要补充的字段：
1. biomimetic_metadata (organism_scientific, biomimetic_dimension, features, applicability, engineering_constraints)
2. biomimetic_narrative (problem_definition, biological_solution, key_features, design_mapping, explainability_anchors)

策略：
- 从现有 knowledge_items + decision_summary 推断
- 用 LLM 补充提取
"""

import json
import os
import sys
import glob
from openai import OpenAI


# LLM 补充提取提示词
SUPPLEMENT_PROMPT = """你是一个仿生水处理吸附材料设计系统的知识整合 agent。

你的任务是基于已提取的文献知识，补充仿生设计库所需的元数据和叙事字段。

**输入**：文献的 knowledge_items 和 decision_summary
**输出**：biomimetic_metadata 和 biomimetic_narrative 的 JSON

**重要约束**：
1. 只从提供的 knowledge_items 和 decision_summary 中推断
2. 如果信息不足，填 null 或空数组
3. 不要编造文献中没有的信息
4. biomimetic_dimension 必须是以下之一：分子仿生/结构仿生/形态仿生/过程仿生/功能仿生/系统仿生

**输出格式**：
```json
{
  "biomimetic_metadata": {
    "organism_scientific": "学名或null",
    "biomimetic_dimension": "6选1",
    "features": ["特征标签"],
    "applicability": {
      "pH_range": [min, max] 或 null,
      "temp_range": [min, max] 或 null,
      "salinity": "low/moderate/high/low_to_moderate" 或 null
    },
    "engineering_constraints": [
      {"constraint": "约束名称", "relevance": "high/medium/low", "explanation": "说明"}
    ]
  },
  "biomimetic_narrative": {
    "problem_definition": "自然界挑战 + 水处理对应",
    "biological_solution": "进化策略 + 关键机制 + 成功案例",
    "key_features": "必须保留特征 + 可灵活调整特征",
    "design_mapping": "生物→材料映射 + 软约束建议",
    "explainability_anchors": "仿生故事线 + 设计溯源"
  }
}
```

只输出 JSON，不要解释。"""


def extract_context_for_llm(data: dict) -> str:
    """从 JSON 中提取 LLM 需要的上下文"""
    parts = []

    # routing
    routing = data.get('routing', {})
    parts.append(f"仿生来源: {routing.get('biomimetic_organism', 'N/A')}")
    parts.append(f"目标污染物: {', '.join(routing.get('target_pollutants', []))}")
    parts.append(f"领域方向: {', '.join(routing.get('domain_directions', []))}")

    # decision_summary
    ds = data.get('decision_summary', {})
    parts.append(f"\n一句话价值: {ds.get('one_sentence_value', 'N/A')}")
    parts.append(f"仿生洞察: {ds.get('biomimetic_insight', 'N/A')}")
    if ds.get('key_findings'):
        parts.append(f"关键发现: {'; '.join(ds['key_findings'][:5])}")

    # knowledge_items (取前20条)
    items = data.get('knowledge_items', [])
    parts.append(f"\n知识条目 (共{len(items)}条，显示前20条):")
    for i, item in enumerate(items[:20]):
        param = item.get('parameter', 'N/A')
        value = str(item.get('value', ''))[:100]
        unit = item.get('unit', '')
        ctx = item.get('context', {})
        ctx_str = ', '.join(f"{k}={v}" for k, v in ctx.items() if v)[:100]
        parts.append(f"  {i+1}. {param}: {value} {unit} ({ctx_str})")

    return '\n'.join(parts)


def call_llm(context: str, api_key: str, base_url: str, model: str) -> dict:
    """调用 LLM 补充提取"""
    client = OpenAI(api_key=api_key, base_url=base_url)

    try:
        response = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": SUPPLEMENT_PROMPT},
                {"role": "user", "content": context}
            ],
            temperature=0.3,
            max_tokens=2000
        )

        content = response.choices[0].message.content
        # 提取 JSON
        s = content.find('{')
        e = content.rfind('}')
        if s >= 0 and e >= 0:
            return json.loads(content[s:e+1])
    except Exception as e:
        print(f"  LLM 调用失败: {e}")

    return None


def supplement_json_file(json_path: str, api_key: str, base_url: str, model: str,
                         dry_run: bool = False) -> dict:
    """补充单个 JSON 文件"""
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 检查是否需要补充
    needs_biomimetic_metadata = 'biomimetic_metadata' not in data
    needs_biomimetic_narrative = 'biomimetic_narrative' not in data

    if not needs_biomimetic_metadata and not needs_biomimetic_narrative:
        return {'file': os.path.basename(json_path), 'status': 'skip', 'reason': 'already complete'}

    # 提取上下文
    context = extract_context_for_llm(data)

    if dry_run:
        return {
            'file': os.path.basename(json_path),
            'status': 'would_supplement',
            'needs': {
                'biomimetic_metadata': needs_biomimetic_metadata,
                'biomimetic_narrative': needs_biomimetic_narrative
            }
        }

    # 调用 LLM
    result = call_llm(context, api_key, base_url, model)

    if not result:
        return {'file': os.path.basename(json_path), 'status': 'error', 'reason': 'LLM failed'}

    # 更新数据
    if needs_biomimetic_metadata and 'biomimetic_metadata' in result:
        data['biomimetic_metadata'] = result['biomimetic_metadata']

    if needs_biomimetic_narrative and 'biomimetic_narrative' in result:
        data['biomimetic_narrative'] = result['biomimetic_narrative']

    # 保存
    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')

    return {
        'file': os.path.basename(json_path),
        'status': 'supplemented',
        'biomimetic_metadata': bool(result.get('biomimetic_metadata')),
        'biomimetic_narrative': bool(result.get('biomimetic_narrative'))
    }


def main():
    import argparse
    parser = argparse.ArgumentParser(description='增量补充提取')
    parser.add_argument('--json-dir', default=None, help='JSON 文件目录')
    parser.add_argument('--dry-run', action='store_true', help='只分析不保存')
    parser.add_argument('--limit', type=int, default=0, help='限制处理数量')
    args = parser.parse_args()

    json_dir = args.json_dir or os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        'outputs', 'extractions', '论文', 'json'
    )

    if not os.path.exists(json_dir):
        print(f"ERROR: 目录不存在: {json_dir}")
        sys.exit(1)

    # 加载 .env
    env_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), '.env')
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if '=' in line and not line.startswith('#'):
                    key, value = line.split('=', 1)
                    os.environ[key.strip()] = value.strip()

    api_key = os.environ.get('BAILIAN_CODING_PLAN_API_KEY')
    base_url = os.environ.get('BAILIAN_BASE', 'https://coding.dashscope.aliyuncs.com/v1')
    model = os.environ.get('SUPPLEMENT_MODEL', 'qwen3.6-plus')

    if not api_key:
        print("ERROR: 未设置 BAILIAN_CODING_PLAN_API_KEY")
        sys.exit(1)

    json_files = glob.glob(os.path.join(json_dir, '*.json'))
    print(f"找到 {len(json_files)} 个 JSON 文件")

    if args.limit > 0:
        json_files = json_files[:args.limit]
        print(f"限制处理 {args.limit} 个文件")

    if args.dry_run:
        print("=== DRY RUN 模式 ===\n")

    reports = []
    for i, json_file in enumerate(sorted(json_files)):
        print(f"[{i+1}/{len(json_files)}] {os.path.basename(json_file)}...")
        try:
            report = supplement_json_file(json_file, api_key, base_url, model, dry_run=args.dry_run)
            reports.append(report)
            print(f"  → {report['status']}")
        except Exception as e:
            reports.append({
                'file': os.path.basename(json_file),
                'status': 'error',
                'error': str(e)
            })
            print(f"  → ERROR: {e}")

    # 输出报告
    print("\n" + "=" * 60)
    print("补充提取报告")
    print("=" * 60)

    supplemented = sum(1 for r in reports if r['status'] == 'supplemented')
    skipped = sum(1 for r in reports if r['status'] == 'skip')
    errors = sum(1 for r in reports if r['status'] == 'error')
    would_supplement = sum(1 for r in reports if r['status'] == 'would_supplement')

    print(f"\n总文件: {len(reports)}")
    print(f"已补充: {supplemented}")
    print(f"跳过: {skipped}")
    print(f"错误: {errors}")
    if args.dry_run:
        print(f"需要补充: {would_supplement}")


if __name__ == '__main__':
    main()
