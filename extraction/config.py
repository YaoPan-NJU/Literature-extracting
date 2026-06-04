# extraction/config.py
"""Configuration loaded from .env file."""

import os
from pathlib import Path
from dotenv import load_dotenv

load_dotenv()

# API provider configurations
PROVIDERS = {
    "coding_plan": {
        "api_key": os.getenv("CODING_PLAN_API_KEY", ""),
        "base_url": os.getenv("CODING_PLAN_BASE_URL", "https://coding.dashscope.aliyuncs.com/v1"),
        "model": os.getenv("CODING_PLAN_MODEL", "qwen3.6-plus"),
    },
    "dashscope": {
        "api_key": os.getenv("DASHSCOPE_API_KEY", ""),
        "base_url": os.getenv("DASHSCOPE_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1"),
        "model": os.getenv("DASHSCOPE_MODEL", "qwen3.7-max"),
    },
    "mimo": {
        "api_key": os.getenv("MIMO_API_KEY", ""),
        "base_url": os.getenv("MIMO_BASE_URL", "https://token-plan-cn.xiaomimimo.com/v1"),
        "model": os.getenv("MIMO_MODEL", "mimo-v2.5"),
    },
}

# Model routing: task type -> provider
MODEL_ROUTING = {
    "coarse_scan": "coding_plan",
    "performance_extract": "coding_plan",
    "deep_read": "dashscope",
    "biomimetic_extract": "dashscope",
    "weight_assign": "dashscope",
    "multimodal_extract": "mimo",
}

# File paths
LITERATURE_DIR = Path(os.getenv("LITERATURE_DIR", ""))
PROJECT_DIR = Path(os.getenv("PROJECT_DIR", ".")).resolve()
OUTPUT_DIR = Path(os.getenv("OUTPUT_DIR", "./extraction-output"))

# Paper groups in literature library
PAPER_GROUPS = {
    "全局综述": "global_review",
    "第1组-配位螯合": "coordination_chelation",
    "第2组-超疏水": "superhydrophobic",
    "第3组-多孔结构": "porous_structure",
    "第4组-生物矿化": "biomineralization",
    "第5组-纤维结构": "fiber_structure",
    "第6组-功能仿生": "functional_biomimetics",
    "第7组-系统仿生": "system_biomimetics",
    "第8组-仿生材料": "biomimetic_materials",
}

# New supplementary groups
SUPPLEMENT_GROUPS = {
    "第9组-仿生方法论": "methodology_standards",
    "第10组-仿生设计综述": "biomimetic_reviews",
    "第11组-跨原型比较": "cross_prototype",
    "第12组-仿生设计案例": "design_cases",
}
