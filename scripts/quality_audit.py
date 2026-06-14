#!/usr/bin/env python3
"""
逐篇质量审计脚本
对每篇JSON提取结果做详细检查，输出审计报告
"""

import json
import os
import glob
import sys
from collections import Counter, defaultdict
from datetime import datetime

# 审计维度定义
RELEVANCE_LEVELS = {
    'R1_core_direct': '核心直接相关',
    'R2_domain_direct': '领域直接相关', 
    'R3_transferable_indirect': '可迁移间接相关',
    'R4_minimal_keep': '最低保留'
}

VALID_DOMAINS = [
    'D1_pollutant_source', 'D2_produced_water_fate', 'D3_toxicity_risk',
    'D4_monitoring_detection', 'D5_treatment_technology', 'D6_operation_performance',
    'D7_cost_constraint', 'D8_regulation_management', 'D9_optimization_decision',
    'D10_data_knowledge'
]

VALID_DOC_TYPES = ['T1_article', 'T2_patent', 'T3_manual_standard_guideline', 'T4_thesis_book_chapter']

def audit_single_file(filepath, base_dir):
    """审计单个JSON文件，返回审计结果"""
    result = {
        'file': os.path.relpath(filepath, base_dir),
        'file_size': os.path.getsize(filepath),
        'issues': [],
        'warnings': [],
        'score': 0,
        'max_score': 100
    }
    
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
    except Exception as e:
        result['issues'].append(f'JSON解析失败: {e}')
        return result
    
    # 1. Schema版本检查 (10分)
    schema = data.get('schema_version')
    if schema == 'jjj-v2':
        result['score'] += 10
    else:
        result['issues'].append(f'Schema版本异常: {schema}')
    
    # 2. 元数据完整性 (15分)
    meta = data.get('bibliographic_metadata', {})
    if meta:
        if meta.get('title'):
            result['score'] += 3
        else:
            result['issues'].append('缺少title')
        if meta.get('authors'):
            result['score'] += 3
        else:
            result['warnings'].append('缺少authors')
        if meta.get('year'):
            result['score'] += 3
        else:
            result['warnings'].append('缺少year')
        if meta.get('language'):
            result['score'] += 3
        else:
            result['issues'].append('缺少language')
        if meta.get('abstract'):
            result['score'] += 3
        else:
            result['warnings'].append('缺少abstract')
    else:
        result['issues'].append('缺少bibliographic_metadata')
    
    # 3. 路由信息 (15分)
    routing = data.get('routing', {})
    if routing:
        rel = routing.get('relevance_level')
        if rel in RELEVANCE_LEVELS:
            result['score'] += 5
        else:
            result['issues'].append(f'relevance_level无效: {rel}')
        
        if routing.get('relevance_reason'):
            result['score'] += 3
        else:
            result['issues'].append('缺少relevance_reason')
        
        doc_type = routing.get('document_type')
        if doc_type in VALID_DOC_TYPES:
            result['score'] += 4
        else:
            result['warnings'].append(f'document_type不标准: {doc_type}')
        
        if routing.get('domain_directions'):
            result['score'] += 3
        else:
            result['warnings'].append('缺少domain_directions')
    
    # 4. 决策摘要 (10分)
    ds = data.get('decision_summary', {})
    if ds and isinstance(ds, dict):
        if ds.get('one_sentence_value'):
            result['score'] += 4
        else:
            result['issues'].append('缺少one_sentence_value')
        if ds.get('key_findings'):
            result['score'] += 3
        else:
            result['warnings'].append('缺少key_findings')
        if ds.get('transferable_value'):
            result['score'] += 2
        if ds.get('main_limitations'):
            result['score'] += 1
    else:
        result['issues'].append('缺少decision_summary')
    
    # 5. 知识条目质量 (30分)
    ki = data.get('knowledge_items', []) or []
    ki_count = len(ki)
    
    if ki_count == 0:
        result['issues'].append('knowledge_items为空')
    else:
        result['score'] += min(10, ki_count)  # 每条1分，上限10分
        
        # 检查KI质量
        ki_with_param = 0
        ki_with_value = 0
        ki_with_unit = 0
        ki_with_evidence = 0
        ki_with_context = 0
        ki_with_embedding = 0
        invalid_domains = []
        chunk_types = Counter()
        
        for item in ki:
            if item.get('parameter'):
                ki_with_param += 1
            if item.get('value') and str(item['value']).strip():
                ki_with_value += 1
            if item.get('unit') and str(item['unit']).strip():
                ki_with_unit += 1
            if item.get('source_evidence'):
                ki_with_evidence += 1
            ctx = item.get('context')
            if ctx and isinstance(ctx, dict) and len(ctx) > 0:
                ki_with_context += 1
            if item.get('embedding_text_zh'):
                ki_with_embedding += 1
            
            ct = item.get('chunk_type', 'unknown')
            chunk_types[ct] += 1
            
            for d in (item.get('domain_direction') or []):
                if d not in VALID_DOMAINS:
                    invalid_domains.append(d)
        
        # parameter覆盖率 (5分)
        param_rate = ki_with_param / ki_count if ki_count > 0 else 0
        if param_rate >= 0.8:
            result['score'] += 5
        elif param_rate >= 0.5:
            result['score'] += 3
            result['warnings'].append(f'parameter覆盖率偏低: {param_rate:.0%}')
        else:
            result['issues'].append(f'parameter覆盖率过低: {param_rate:.0%}')
        
        # value覆盖率 (5分)
        value_rate = ki_with_value / ki_count if ki_count > 0 else 0
        if value_rate >= 0.7:
            result['score'] += 5
        elif value_rate >= 0.4:
            result['score'] += 3
            result['warnings'].append(f'value覆盖率偏低: {value_rate:.0%}')
        else:
            result['issues'].append(f'value覆盖率过低: {value_rate:.0%}')
        
        # unit覆盖率 (3分)
        unit_rate = ki_with_unit / ki_count if ki_count > 0 else 0
        if unit_rate >= 0.5:
            result['score'] += 3
        elif unit_rate >= 0.3:
            result['score'] += 1
        
        # evidence覆盖率 (5分)
        evidence_rate = ki_with_evidence / ki_count if ki_count > 0 else 0
        if evidence_rate >= 0.5:
            result['score'] += 5
        elif evidence_rate >= 0.2:
            result['score'] += 3
        elif evidence_rate >= 0.05:
            result['score'] += 1
        else:
            result['warnings'].append(f'evidence覆盖率过低: {evidence_rate:.0%}')
        
        # embedding覆盖率 (2分)
        embedding_rate = ki_with_embedding / ki_count if ki_count > 0 else 0
        if embedding_rate >= 0.3:
            result['score'] += 2
        elif embedding_rate >= 0.1:
            result['score'] += 1
        
        # context覆盖率
        context_rate = ki_with_context / ki_count if ki_count > 0 else 0
        if context_rate >= 0.5:
            result['score'] += 5
        elif context_rate >= 0.3:
            result['score'] += 3
        
        # 领域方向规范性
        if invalid_domains:
            result['warnings'].append(f'领域方向不规范: {invalid_domains[:3]}')
        
        result['ki_stats'] = {
            'count': ki_count,
            'param_rate': round(param_rate, 3),
            'value_rate': round(value_rate, 3),
            'unit_rate': round(unit_rate, 3),
            'evidence_rate': round(evidence_rate, 3),
            'context_rate': round(context_rate, 3),
            'embedding_rate': round(embedding_rate, 3),
            'chunk_types': dict(chunk_types)
        }
    
    # 6. 质量控制记录 (10分)
    qc = data.get('quality_control', {})
    if qc:
        result['score'] += 3
        if qc.get('json_parse_check') == 'pass':
            result['score'] += 3
        if qc.get('missing_important_fields'):
            result['warnings'].append(f'缺失重要字段: {qc["missing_important_fields"][:2]}')
        if qc.get('suspicious_items'):
            result['warnings'].append(f'可疑条目: {qc["suspicious_items"][:1]}')
        if qc.get('manual_review_recommendations'):
            result['review_recommendations'] = qc['manual_review_recommendations']
    
    # 7. 处理说明 (10分)
    notes = data.get('processing_notes', [])
    if notes:
        result['score'] += 5
    if data.get('paper_id'):
        result['score'] += 5
    
    # 评级
    score_rate = result['score'] / result['max_score']
    if score_rate >= 0.9:
        result['grade'] = 'A'
        result['grade_desc'] = '优秀'
    elif score_rate >= 0.75:
        result['grade'] = 'B'
        result['grade_desc'] = '良好'
    elif score_rate >= 0.6:
        result['grade'] = 'C'
        result['grade_desc'] = '合格'
    elif score_rate >= 0.4:
        result['grade'] = 'D'
        result['grade_desc'] = '较差'
    else:
        result['grade'] = 'E'
        result['grade_desc'] = '不合格'
    
    return result


def main():
    base_dir = '/Users/panyao/Qoder/JJJ_Literature/outputs/extractions'
    dirs = [
        os.path.join(base_dir, '英文文献', 'json'),
        os.path.join(base_dir, '中文文献', 'json'),
        os.path.join(base_dir, '专利', 'json'),
        os.path.join(base_dir, '书本', '中文', 'json'),
        os.path.join(base_dir, '书本', '英文', 'json'),
    ]
    
    all_files = []
    for d in dirs:
        if os.path.isdir(d):
            all_files.extend(glob.glob(os.path.join(d, '*.json')))
    
    total = len(all_files)
    print(f"开始审计 {total} 个文件...")
    print(f"时间: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    results = []
    grade_dist = Counter()
    relevance_dist = Counter()
    doc_type_dist = Counter()
    category_stats = defaultdict(lambda: {'count': 0, 'scores': []})
    all_issues = []
    all_warnings = []
    
    for i, filepath in enumerate(all_files):
        if (i + 1) % 500 == 0:
            print(f"  已处理 {i+1}/{total}...")
        
        result = audit_single_file(filepath, base_dir)
        results.append(result)
        grade_dist[result.get('grade', 'E')] += 1
        
        # 分类统计
        category = result['file'].split('/')[0]
        category_stats[category]['count'] += 1
        category_stats[category]['scores'].append(result['score'])
        
        if result.get('issues'):
            all_issues.append((result['file'], result['issues']))
        if result.get('warnings'):
            all_warnings.append((result['file'], result['warnings']))
    
    # 输出报告
    print("\n" + "=" * 60)
    print("📊 审计报告")
    print("=" * 60)
    
    print(f"\n📋 总体统计:")
    print(f"  审计文件数: {total}")
    print(f"  平均分: {sum(r['score'] for r in results) / total:.1f}/100")
    
    print(f"\n📈 评级分布:")
    for grade in ['A', 'B', 'C', 'D', 'E']:
        count = grade_dist.get(grade, 0)
        pct = count / total * 100
        print(f"  {grade}: {count:5d} ({pct:5.1f}%)")
    
    print(f"\n📂 分类统计:")
    for cat, stats in sorted(category_stats.items()):
        avg = sum(stats['scores']) / len(stats['scores']) if stats['scores'] else 0
        print(f"  {cat}: {stats['count']}篇, 平均分 {avg:.1f}")
    
    # 严重问题统计
    severe_files = [r for r in results if r.get('grade') in ['D', 'E']]
    print(f"\n⚠️  需关注文件 ({len(severe_files)}篇):")
    for r in severe_files[:20]:
        print(f"  [{r['grade']}] {r['file'][:60]}")
        for issue in r.get('issues', [])[:2]:
            print(f"       → {issue}")
    
    # 输出详细报告到文件
    report_file = os.path.join(base_dir, 'quality_audit_report.json')
    with open(report_file, 'w', encoding='utf-8') as f:
        json.dump({
            'audit_time': datetime.now().isoformat(),
            'total_files': total,
            'summary': {
                'avg_score': sum(r['score'] for r in results) / total,
                'grade_distribution': dict(grade_dist),
                'category_stats': {k: {'count': v['count'], 'avg_score': sum(v['scores'])/len(v['scores']) if v['scores'] else 0} for k, v in category_stats.items()}
            },
            'severe_files': [{'file': r['file'], 'grade': r['grade'], 'score': r['score'], 'issues': r.get('issues', [])} for r in severe_files],
            'all_results': results
        }, f, ensure_ascii=False, indent=2)
    
    print(f"\n✅ 详细报告已保存: {report_file}")
    
    # 输出CSV格式的评级列表
    csv_file = os.path.join(base_dir, 'quality_grades.csv')
    with open(csv_file, 'w', encoding='utf-8') as f:
        f.write('file,grade,score,ki_count,param_rate,evidence_rate,issues\n')
        for r in results:
            ki_stats = r.get('ki_stats', {})
            issues_str = '; '.join(r.get('issues', []))
            f.write(f'"{r["file"]}",{r.get("grade","E")},{r["score"]},{ki_stats.get("count",0)},{ki_stats.get("param_rate",0)},{ki_stats.get("evidence_rate",0)},"{issues_str}"\n')
    
    print(f"✅ 评级列表已保存: {csv_file}")


if __name__ == '__main__':
    main()
