# extraction/tests/test_llm_client.py
import pytest
from unittest.mock import patch, MagicMock
from llm_client import LLMClient


class TestLLMClient:
    def test_init_loads_provider_config(self):
        client = LLMClient(provider="coding_plan")
        assert client.model == "qwen3.6-plus"
        assert "coding.dashscope" in client.base_url

    def test_route_task_returns_correct_provider(self):
        assert LLMClient.route_task("coarse_scan") == "coding_plan"
        assert LLMClient.route_task("deep_read") == "dashscope"
        assert LLMClient.route_task("multimodal_extract") == "mimo"

    def test_chat_calls_openai_api(self):
        client = LLMClient(provider="coding_plan")
        mock_response = MagicMock()
        mock_response.choices = [MagicMock()]
        mock_response.choices[0].message.content = '{"result": "ok"}'
        with patch.object(client.client.chat.completions, "create", return_value=mock_response) as mock_create:
            result = client.chat("Extract data from this abstract: ...")
            mock_create.assert_called_once()
            assert result == '{"result": "ok"}'

    def test_chat_json_parses_structured_output(self):
        client = LLMClient(provider="coding_plan")
        with patch.object(client, "chat", return_value='{"pollutants": ["Pb", "Cd"], "qmax": "120 mg/g"}'):
            result = client.chat_json("test prompt")
            assert result == {"pollutants": ["Pb", "Cd"], "qmax": "120 mg/g"}

    def test_chat_json_handles_markdown_fences(self):
        client = LLMClient(provider="coding_plan")
        raw = '```json\n{"key": "value"}\n```'
        with patch.object(client, "chat", return_value=raw):
            result = client.chat_json("test prompt")
            assert result == {"key": "value"}

    def test_from_task_type_creates_routed_client(self):
        client = LLMClient.from_task_type("biomimetic_extract")
        assert client.provider == "dashscope"
        assert client.model == "qwen3.7-max"
