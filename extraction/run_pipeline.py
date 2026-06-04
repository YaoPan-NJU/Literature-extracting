# extraction/run_pipeline.py
"""CLI entry point for the biomimetic extraction pipeline.

Usage:
    python run_pipeline.py phase1          # Coarse scan
    python run_pipeline.py phase2          # Gap analysis
    python run_pipeline.py phase3          # Supplementation planning
    python run_pipeline.py phase4          # Deep extraction
    python run_pipeline.py all             # Run all phases sequentially
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from config import OUTPUT_DIR, LITERATURE_DIR, PROJECT_DIR

PHASES = {
    "phase1": ("Phase 1: Coarse Scan", "pipeline.phase1_coarse_scan", "run_phase1"),
    "phase2": ("Phase 2: Gap Analysis", "pipeline.phase2_gap_analysis", "run_phase2"),
    "phase3": ("Phase 3: Supplementation Planning", "pipeline.phase3_supplement_plan", "run_phase3"),
    "phase4": ("Phase 4: Deep Extraction", "pipeline.phase4_deep_extract", "run_phase4"),
}


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)

    phases_to_run = sys.argv[1:]
    if "all" in phases_to_run:
        phases_to_run = list(PHASES.keys())

    for phase_key in phases_to_run:
        if phase_key not in PHASES:
            print(f"Unknown phase: {phase_key}. Available: {list(PHASES.keys())}")
            sys.exit(1)

    for phase_key in phases_to_run:
        name, module_name, func_name = PHASES[phase_key]
        print(f"\n{'='*60}")
        print(f"  {name}")
        print(f"{'='*60}\n")

        module = __import__(module_name, fromlist=[func_name])
        func = getattr(module, func_name)

        if phase_key == "phase1":
            func(literature_dir=LITERATURE_DIR, output_dir=OUTPUT_DIR)
        elif phase_key == "phase4":
            func(output_dir=OUTPUT_DIR, project_dir=PROJECT_DIR)
        else:
            func(output_dir=OUTPUT_DIR)

    print(f"\nAll requested phases complete. Output: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
