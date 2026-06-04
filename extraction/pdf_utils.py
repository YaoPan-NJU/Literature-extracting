# extraction/pdf_utils.py
"""PDF text extraction utilities using PyMuPDF and pdfplumber."""

from pathlib import Path


def extract_first_page_text(pdf_path: Path) -> str:
    try:
        import fitz
        doc = fitz.open(str(pdf_path))
        if doc.page_count == 0:
            doc.close()
            return ""
        text = doc[0].get_text()
        doc.close()
        return text
    except (FileNotFoundError, Exception):
        return ""


def extract_full_text(pdf_path: Path) -> str:
    try:
        import fitz
        doc = fitz.open(str(pdf_path))
        texts = []
        for page in doc:
            texts.append(page.get_text())
        doc.close()
        return "\n\n".join(texts)
    except (FileNotFoundError, Exception):
        return ""


def extract_tables(pdf_path: Path) -> list:
    try:
        import pdfplumber
        tables = []
        with pdfplumber.open(str(pdf_path)) as pdf:
            for page in pdf.pages:
                page_tables = page.extract_tables()
                if page_tables:
                    tables.extend(page_tables)
        return tables
    except (FileNotFoundError, Exception):
        return []
