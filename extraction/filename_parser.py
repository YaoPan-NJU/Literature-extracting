# extraction/filename_parser.py
"""Parse structured metadata from paper filenames.

Filename convention: YEAR-AuthorSurname-Keyword1-Keyword2-...[-review].pdf
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path

REVIEW_MARKERS = {"review", "综述", "研究进展", "progress", "overview"}


@dataclass
class PaperMeta:
    year: int | None = None
    author: str = ""
    keywords: list[str] = field(default_factory=list)
    is_review: bool = False
    is_patent: bool = False
    original_filename: str = ""


def parse_filename(filename: str) -> PaperMeta:
    stem = Path(filename).stem
    parts = stem.split("-")

    meta = PaperMeta(original_filename=filename)

    if len(parts) < 2:
        meta.author = stem
        return meta

    if parts[0].isdigit() and len(parts[0]) == 4:
        meta.year = int(parts[0])
    else:
        meta.author = stem
        return meta

    meta.author = parts[1]
    if re.match(r"CN\d+", meta.author):
        meta.is_patent = True

    remaining = parts[2:]
    for kw in remaining:
        kw_lower = kw.strip().lower()
        if kw_lower in REVIEW_MARKERS:
            meta.is_review = True
        else:
            meta.keywords.append(kw.strip())

    return meta
