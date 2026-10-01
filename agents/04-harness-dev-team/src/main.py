"""Agent 4 - Magentic developer team in a per-session sandbox.

The Magentic manager decides which specialist acts next based on progress,
rather than following a fixed order. Each session gets its own VM-isolated
sandbox with a persistent filesystem, so a git worktree created on turn 1 is
still there on turn 20.

Swap the harness with:  azd env set HARNESS_BACKEND github  &&  azd deploy
"""
from __future__ import annotations

import logging
import os

from logic import dev_team, select_backend, worktree_commands

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("pwc-dev-team-agent")


def build_chat_client(backend: str):
    """Return a chat client for the selected harness backend."""
    from azure.identity import DefaultAzureCredential

    if backend == "magentic":
        from agent_framework.foundry import FoundryChatClient

        return FoundryChatClient(
            project_endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
            model=os.environ.get("MICROSOFT_FOUNDRY_MODEL_DEPLOYMENT_NAME", "gpt-5.4-mini"),
            credential=DefaultAzureCredential(),
        )

    # backend == "github": the GitHub Copilot SDK connector runs its own
    # autonomous loop; MAF wraps it so it composes with the other agents.
    from agent_framework.github import GitHubCopilotChatClient

    return GitHubCopilotChatClient(token=os.environ["GITHUB_TOKEN"])


def build_agent():
    from agent_framework import Agent, MagenticBuilder
    from agent_framework.foundry import FoundryChatClient
    from azure.identity import DefaultAzureCredential

    backend = select_backend(os.environ)
    log.info("harness backend: %s", backend)

    client = build_chat_client(backend)
    members = [
        Agent(
            name=s.name,
            description=s.description,
            instructions=s.instructions,
            client=client,
        )
        for s in dev_team()
    ]

    manager = FoundryChatClient(
        project_endpoint=os.environ["FOUNDRY_PROJECT_ENDPOINT"],
        model=os.environ.get("MICROSOFT_FOUNDRY_MODEL_DEPLOYMENT_NAME", "gpt-5.4-mini"),
        credential=DefaultAzureCredential(),
    )

    log.info(
        "worktree bootstrap: %s",
        " && ".join(
            worktree_commands(
                os.environ.get("REPO_URL", ""),
                os.environ.get("WORKTREE_ROOT", "/home/agent/worktrees"),
                os.environ.get("FOUNDRY_SESSION_ID", "local000"),
                "bootstrap",
            )
        ),
    )

    return MagenticBuilder().participants(members).manager(manager).build()


def main() -> None:
    from agent_framework_foundry_hosting import AgentHost

    host = AgentHost.create_builder()
    host.add_foundry_responses(build_agent().as_agent(name="pwc-dev-team-agent"))
    host.build().run()


if __name__ == "__main__":
    main()
