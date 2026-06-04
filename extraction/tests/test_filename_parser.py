# extraction/tests/test_filename_parser.py
import pytest
from filename_parser import parse_filename, PaperMeta


class TestFilenameParser:
    def test_parse_english_paper(self):
        meta = parse_filename("2022-Eltaweil-alginate-bone-magnetic-adsorption-review.pdf")
        assert meta.year == 2022
        assert meta.author == "Eltaweil"
        assert meta.keywords == ["alginate", "bone", "magnetic", "adsorption"]
        assert meta.is_review is True

    def test_parse_chinese_paper(self):
        meta = parse_filename("2021-李-壳聚糖-吸附-重金属-铅.pdf")
        assert meta.year == 2021
        assert meta.author == "李"
        assert meta.keywords == ["壳聚糖", "吸附", "重金属", "铅"]
        assert meta.is_review is False

    def test_parse_patent(self):
        meta = parse_filename("2022-CN114873705A-壳聚糖-磁性-重金属-废水.pdf")
        assert meta.year == 2022
        assert meta.author == "CN114873705A"
        assert meta.is_patent is True

    def test_parse_review_markers(self):
        meta1 = parse_filename("2022-Smith-chitosan-review.pdf")
        assert meta1.is_review is True
        meta2 = parse_filename("2021-王-纤维素-综述.pdf")
        assert meta2.is_review is True
        meta3 = parse_filename("2020-Zhang-MOF-adsorption.pdf")
        assert meta3.is_review is False

    def test_parse_handles_unknown_format(self):
        meta = parse_filename("random-document.pdf")
        assert meta.year is None
        assert meta.author == "random-document"
        assert meta.keywords == []
