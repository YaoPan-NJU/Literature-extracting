# extraction/llm_client.py
"""Unified LLM client supporting three API providers via OpenAI-compatible interface."""

from __future__ import annotations

import json
import re
from openai import OpenAI
from config import PROVIDERS, MODEL_ROUTING


class LLMClient:
    """A unified client for calling LLMs across three providers.

    All three providers expose OpenAI-compatible chat completion endpoints,
    so we use the openai SDK with custom base_url and api_key per provider.
    """

    def __init__(self, provider: str):
        if provider not in PROVIDERS:
            raise ValueError(f"Unknown provider: {provider}. Must be one of {list(PROVIDERS.keys())}")

        self.provider = provider
        cfg = PROVIDERS[provider]
        self.model = cfg["model"]
        self.base_url = cfg["base_url"]

        # Use placeholder key if none set (allows instantiation without .env)
        api_key = cfg["api_key"] or "sk-placeholder"

        self.client = OpenAI(
            api_key=api_key,
            base_url=cfg["base_url"],
        )

    @classmethod
    def from_task_type(cls, task_type: str) -> "LLMClient":
        if task_type not in MODEL_ROUTING:
            raise ValueError(f"Unknown task type: {task_type}. Must be one of {list(MODEL_ROUTING.keys())}")
        provider = MODEL_ROUTING[task_type]
        return cls(provider=provider)

    @staticmethod
    def route_task(task_type: str) -> str:
        if task_type not in MODEL_ROUTING:
            raise ValueError(f"Unknown task type: {task_type}")
        return MODEL_ROUTING[task_type]

    def chat(
        self,
        prompt: str,
        system_prompt: str = "You are a scientific literature analysis assistant. Respond in the language of the input.",
        temperature: float = 0.1,
        max_tokens: int = 4096,
    ) -> str:
        response = self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt},
            ],
            temperature=temperature,
            max_tokens=max_tokens,
        )
        return response.choices[0].message.content

    def chat_json(
        self,
        prompt: str,
        system_prompt: str = "You are a scientific literature analysis assistant. Always respond with valid JSON.",
        temperature: float = 0.1,
        max_tokens: int = 4096,
    ) -> dict:
        raw = self.chat(prompt, system_prompt=system_prompt, temperature=temperature, max_tokens=max_tokens)
        cleaned = re.sub(r"```(?:json)?\s*\n?", "", raw).strip()
        return json.loads(cleaned)
