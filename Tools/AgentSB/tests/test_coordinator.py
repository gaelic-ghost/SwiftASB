from __future__ import annotations

from agentsb.coordinator import DEFAULT_OPENAI_MODEL, build_coordinator, default_openai_model


def test_default_openai_model_uses_agentsb_override(monkeypatch):
    monkeypatch.setenv("AGENTSB_OPENAI_MODEL", "gpt-5.5")
    monkeypatch.setenv("OPENAI_DEFAULT_MODEL", "gpt-5.4-mini")

    assert default_openai_model() == "gpt-5.5"


def test_default_openai_model_uses_openai_default_when_agentsb_unset(monkeypatch):
    monkeypatch.delenv("AGENTSB_OPENAI_MODEL", raising=False)
    monkeypatch.setenv("OPENAI_DEFAULT_MODEL", "gpt-5.4")

    assert default_openai_model() == "gpt-5.4"


def test_default_openai_model_falls_back_to_repo_default(monkeypatch):
    monkeypatch.delenv("AGENTSB_OPENAI_MODEL", raising=False)
    monkeypatch.delenv("OPENAI_DEFAULT_MODEL", raising=False)

    assert default_openai_model() == DEFAULT_OPENAI_MODEL


def test_coordinator_uses_explicit_model():
    coordinator = build_coordinator("gpt-5.5")

    assert coordinator.model == "gpt-5.5"
