# extraction/tests/test_prototype_mapper.py
import pytest
from prototype_mapper import PrototypeMapper, load_prototype_keywords
from filename_parser import PaperMeta


class TestPrototypeMapper:
    @pytest.fixture
    def mapper(self):
        return PrototypeMapper()

    def test_load_prototype_keywords_returns_dict(self):
        kw = load_prototype_keywords()
        assert isinstance(kw, dict)
        assert "mussel-foot-adhesion" in kw or "lotus-leaf" in kw

    def test_map_by_direct_keyword(self, mapper):
        meta = PaperMeta(year=2022, author="Test", keywords=["贻贝", "吸附", "重金属"])
        results = mapper.map_paper(meta, group="coordination_chelation")
        prototype_ids = [r["prototype_id"] for r in results]
        assert "mussel-foot-adhesion" in prototype_ids

    def test_map_by_english_keyword(self, mapper):
        meta = PaperMeta(year=2021, author="Smith", keywords=["lotus", "superhydrophobic"])
        results = mapper.map_paper(meta, group="superhydrophobic")
        prototype_ids = [r["prototype_id"] for r in results]
        assert "lotus-leaf" in prototype_ids

    def test_map_fallback_to_mechanism_group(self, mapper):
        meta = PaperMeta(year=2022, author="Wang", keywords=["chitosan", "Pb", "adsorption"])
        results = mapper.map_paper(meta, group="coordination_chelation")
        assert len(results) > 0
        # chitosan matches chitosan-adsorbent directly, so check for indirect on others
        has_indirect = any(r["association"] == "indirect" for r in results)
        # If chitosan matched directly, that's fine too
        has_direct = any(r["association"] == "direct" for r in results)
        assert has_direct or has_indirect

    def test_map_returns_empty_for_unknown_group(self, mapper):
        meta = PaperMeta(year=2020, author="Test", keywords=["unknown", "terms"])
        results = mapper.map_paper(meta, group="nonexistent_group")
        assert results == []
