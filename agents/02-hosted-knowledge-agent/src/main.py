"""Agent 2 - hosted agent with memory, MCP tools, and PDF grounding.

Runs under the Foundry hosted-agent runtime and serves the Responses protocol.
The pure-logic helpers live in `logic.py` so they can be unit tested without
Azure; this file is the thin wiring layer.
"""
from __future__ import annotations

import logging
import os

from logic import (
    build_instructions,
    resolve_settings,
    should_enable_memory,
)

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("pwc-knowledge-agent")


def build_agent():
    """Compose the agent. Imported lazily so tests need no Azure packages."""
    from agent_framework import Agent
    from agent_framework.foundry import FoundryChatClient
    from azure.identity import DefaultAzureCredential

    settings = resolve_settings(os.environ)
    log.info("starting with model=%s memory=%s", settings.model, settings.memory_store)

    client = FoundryChatClient(
        project_endpoint=settings.project_endpoint,
        model=settings.model,
        credential=DefaultAzureCredential(),
    )

    context_providers = []
    if should_enable_memory(settings):
        from agent_framework.foundry import FoundryMemoryProvider
        context_providers.append(
            FoundryMemoryProvider(
                project_endpoint=settings.project_endpoint,
                memory_store_name=settings.memory_store,
                credential=DefaultAzureCredential(),
            )
        )
        log.info("memory provider attached: %s", settings.memory_store)

    return Agent(
        name="pwc-knowledge-agent",
        instructions=build_instructions(),
        client=client,
        context_providers=context_providers,
    )


def main() -> None:
    from agent_framework_foundry_hosting import AgentHost

    host = AgentHost.create_builder()
    host.add_foundry_responses(build_agent())
    host.build().run()


if __name__ == "__main__":
    main()
