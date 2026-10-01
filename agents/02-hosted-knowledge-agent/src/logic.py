"""Pure logic for Agent 2. No network, no Azure - fully unit tested."""
from __future__ import annotations

from dataclasses import dataclass

DEFAULT_MODEL = "gpt-5.4-mini"
DEFAULT_MEMORY_STORE = "pwc-workshop-memory"


class SettingsError(ValueError):
    """Configuration that would fail at runtime."""


@dataclass(frozen=True)
class Settings:
    project_endpoint: str
    model: str
    memory_store: str
    embedding: str
    tracing: bool
    app_insights: str


def resolve_settings(env: dict) -> Settings:
    """Read the platform-injected environment into a validated Settings object.

    FOUNDRY_PROJECT_ENDPOINT is injected by the hosted-agent platform; we must
    never set it ourselves in azure.yaml.
    """
    endpoint = env.get("FOUNDRY_PROJECT_ENDPOINT", "").strip()
    if not endpoint:
        raise SettingsError(
            "FOUNDRY_PROJECT_ENDPOINT is not set. Running locally? "
            "Use `azd ai agent run`, which injects it for you."
        )
    if not endpoint.startswith("https://"):
        raise SettingsError(f"project endpoint must be https, got {endpoint!r}")
    return Settings(
        project_endpoint=endpoint.rstrip("/"),
        model=env.get("MICROSOFT_FOUNDRY_MODEL_DEPLOYMENT_NAME", DEFAULT_MODEL),
        memory_store=env.get("MEMORY_STORE_NAME", "").strip(),
        embedding=env.get("EMBEDDING_DEPLOYMENT_NAME", "text-embedding-3-small"),
        tracing=env.get("ENABLE_TRACING", "true").lower() in ("1", "true", "yes"),
        app_insights=env.get("APPLICATIONINSIGHTS_CONNECTION_STRING", ""),
    )


def should_enable_memory(settings: Settings) -> bool:
    """Memory needs both a store name and an embedding deployment."""
    return bool(settings.memory_store) and bool(settings.embedding)


def build_instructions() -> str:
    """The agent's system prompt. Kept here so a test can assert its contract."""
    return (
        "You are the PwC Agents Workshop knowledge assistant.\n"
        "\n"
        "Tool policy - follow it exactly:\n"
        "1. For questions about Microsoft products, APIs or Azure, call the "
        "Microsoft Learn MCP tools first. They return official documentation.\n"
        "2. For questions about PwC, call pwc_site_search.\n"
        "3. For questions about this workshop's own content, call the "
        "workshop_pdfs file search.\n"
        "4. Never answer a factual question from memory alone when a tool could "
        "verify it. Say which tool you used.\n"
        "\n"
        "If the tools disagree, say so and show both answers rather than "
        "silently picking one.\n"
        "Remember stable facts about the user (their name, their role, what "
        "they are building) so later sessions do not start from nothing."
    )


def summarise_tool_policy() -> list[str]:
    """The tool routing rules, for the README and for assertions."""
    return [
        "Microsoft/Azure questions -> Learn MCP",
        "PwC questions -> pwc_site_search",
        "Workshop content -> workshop_pdfs file search",
        "Always name the tool used",
    ]
