# extraction/tests/test_pdf_utils.py
import pytest
from pathlib import Path
from pdf_utils import extract_first_page_text, extract_full_text, extract_tables


@pytest.fixture
def sample_pdf(tmp_path):
    import fitz
    doc = fitz.open()
    page = doc.new_page()
    page.insert_text((72, 72), "Abstract: This study investigates biomimetic adsorption.")
    page.insert_text((72, 100), "Keywords: chitosan, heavy metal, lead, adsorption")
    doc.save(str(tmp_path / "test.pdf"))
    doc.close()
    return tmp_path / "test.pdf"


class TestPdfUtils:
    def test_extract_first_page_text(self, sample_pdf):
        text = extract_first_page_text(sample_pdf)
        assert "Abstract" in text
        assert "biomimetic" in text

    def test_extract_full_text(self, sample_pdf):
        text = extract_full_text(sample_pdf)
        assert "adsorption" in text

    def test_extract_first_page_handles_missing_file(self, tmp_path):
        result = extract_first_page_text(tmp_path / "nonexistent.pdf")
        assert result == ""

    def test_extract_tables_returns_list(self, sample_pdf):
        tables = extract_tables(sample_pdf)
        assert isinstance(tables, list)
