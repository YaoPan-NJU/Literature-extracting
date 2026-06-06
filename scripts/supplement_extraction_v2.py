#!/usr/bin/env python3
"""
增量补充提取 v2：3 路并发，使用不同 API。

3 个 API：
1. qwen3.7-max (按量付费) - 推理能力强
2. mimo-v2.5 (MiMo Token Plan) - 速度快
3. qwen3.6-plus (Coding Plan) - 多模态备用

任务：从已有 knowledge_items + decision_summary 推断 biomimetic_metadata 和 biomimetic_narrative
"""

import json
import os
import sys
import glob
from concurrent.futures import ThreadPoolExecutor, as_completed
from openai import OpenAI
import time


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


def call_llm(context: str, api_key: str, base_url: str, model: str, provider_name: str) -> dict:
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
        print(f"  [{provider_name}] LLM 调用失败: {e}")

    return None


def supplement_single_file(json_path: str, api_key: str, base_url: str,
                           model: str, provider_name: str, dry_run: bool = False) -> dict:
    """补充单个 JSON 文件"""
    try:
        with open(json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        # 检查是否需要补充
        if 'biomimetic_metadata' in data and 'biomimetic_narrative' in data:
            return {'file': os.path.basename(json_path), 'status': 'skip', 'reason': 'already complete'}

        # 提取上下文
        context = extract_context_for_llm(data)

        if dry_run:
            return {'file': os.path.basename(json_path), 'status': 'would_supplement', 'provider': provider_name}

        # 调用 LLM
        result = call_llm(context, api_key, base_url, model, provider_name)

        if not result:
            return {'file': os.path.basename(json_path), 'status': 'error', 'reason': 'LLM failed', 'provider': provider_name}

        # 更新数据
        if 'biomimetic_metadata' not in data and 'biomimetic_metadata' in result:
            data['biomimetic_metadata'] = result['biomimetic_metadata']

        if 'biomimetic_narrative' not in data and 'biomimetic_narrative' in result:
            data['biomimetic_narrative'] = result['biomimetic_narrative']

        # 保存
        with open(json_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
            f.write('\n')

        return {
            'file': os.path.basename(json_path),
            'status': 'supplemented',
            'provider': provider_name,
            'biomimetic_metadata': bool(result.get('biomimetic_metadata')),
            'biomimetic_narrative': bool(result.get('biomimetic_narrative'))
        }
    except Exception as e:
        return {'file': os.path.basename(json_path), 'status': 'error', 'reason': str(e), 'provider': provider_name}


def main():
    import argparse
    parser = argparse.ArgumentParser(description='增量补充提取 v2 (3路并发)')
    parser.add_argument('--json-dir', default=None, help='JSON 文件目录')
    parser.add_argument('--dry-run', action='store_true', help='只分析不保存')
    parser.add_argument('--limit', type=int, default=0, help='限制处理数量')
    parser.add_argument('--workers', type=int, default=3, help='并发数 (默认3)')
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

    # 3 个 API 配置
    providers = [
        {
            'name': 'qwen3.7-max',
            'api_key': os.environ.get('DASHSCOPE_API_KEY'),
            'base_url': 'https://dashscope.aliyuncs.com/compatible-mode/v1',
            'model': 'qwen3.7-max'
        },
        {
            'name': 'mimo-v2.5',
            'api_key': os.environ.get('MIMO_API_KEY'),
            'base_url': 'https://token-plan-cn.xiaomimimo.com/v1',
            'model': 'mimo-v2.5'
        },
        {
            'name': 'qwen3.6-plus',
            'api_key': os.environ.get('BAILIAN_CODING_PLAN_API_KEY'),
            'base_url': 'https://coding.dashscope.aliyuncs.com/v1',
            'model': 'qwen3.6-plus'
        }
    ]

    # 检查 API key
    for p in providers:
        if not p['api_key']:
            print(f"ERROR: 未设置 {p['name']} 的 API key")
            sys.exit(1)

    json_files = sorted(glob.glob(os.path.join(json_dir, '*.json')))

    # 过滤需要补充的文件
    files_to_process = []
    for f in json_files:
        try:
            with open(f, 'r', encoding='utf-8') as fh:
                data = json.load(fh)
            if 'biomimetic_metadata' not in data or 'biomimetic_narrative' not in data:
                files_to_process.append(f)
        except:
            pass

    print(f"总文件: {len(json_files)}")
    print(f"需要补充: {len(files_to_process)}")

    if args.limit > 0:
        files_to_process = files_to_process[:args.limit]
        print(f"限制处理: {args.limit}")

    if args.dry_run:
        print("\n=== DRY RUN 模式 ===")
        for i, f in enumerate(files_to_process[:10]):
            provider = providers[i % 3]
            print(f"  {os.path.basename(f)} → {provider['name']}")
        return

    # 3 路并发处理
    print(f"\n启动 {args.workers} 路并发...")
    print(f"  Worker 1: {providers[0]['name']} ({len(files_to_process[::3])} 篇)")
    print(f"  Worker 2: {providers[1]['name']} ({len(files_to_process[1::3])} 篇)")
    print(f"  Worker 3: {providers[2]['name']} ({len(files_to_process[2::3])} 篇)")

    reports = []
    start_time = time.time()

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = []
        for i, json_file in enumerate(files_to_process):
            provider = providers[i % 3]
            future = executor.submit(
                supplement_single_file,
                json_file,
                provider['api_key'],
                provider['base_url'],
                provider['model'],
                provider['name']
            )
            futures.append((future, json_file, provider['name']))

        # 收集结果
        for future, json_file, provider_name in futures:
            try:
                report = future.result()
                reports.append(report)
                status = report['status']
                print(f"  [{provider_name}] {os.path.basename(json_file)}: {status}")
            except Exception as e:
                reports.append({
                    'file': os.path.basename(json_file),
                    'status': 'error',
                    'reason': str(e),
                    'provider': provider_name
                })

    elapsed = time.time() - start_time

    # 输出报告
    print("\n" + "=" * 60)
    print("补充提取报告 (3路并发)")
    print("=" * 60)

    supplemented = sum(1 for r in reports if r['status'] == 'supplemented')
    skipped = sum(1 for r in reports if r['status'] == 'skip')
    errors = sum(1 for r in reports if r['status'] == 'error')

    print(f"\n总文件: {len(reports)}")
    print(f"已补充: {supplemented}")
    print(f"跳过: {skipped}")
    print(f"错误: {errors}")
    print(f"耗时: {elapsed:.0f}s ({elapsed/60:.1f}min)")

    # 按 provider 统计
    print(f"\n按 Provider 统计:")
    for p in providers:
        p_reports = [r for r in reports if r.get('provider') == p['name']]
        p_ok = sum(1 for r in p_reports if r['status'] == 'supplemented')
        p_err = sum(1 for r in p_reports if r['status'] == 'error')
        print(f"  {p['name']}: {p_ok} 成功, {p_err} 错误")


if __name__ == '__main__':
    main()
