"""Agent 3 - a MAF sequential workflow exposed as a single hosted agent.

Three specialists run in order: researcher -> analyst -> writer. The analyst
uses model-router so you can watch the router pick a model per request, while
the other two are pinned to specific cheap models.
"""
from __future__ import annotations

import logging
import os

from logic import RoleSpec, plan_execution, resolve_model, role_specs

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("pwc-workflow-agent")


def build_workflow():
    from agent_framework import Agent, SequentialBuilder
    from agent_framework.foundry import FoundryChatClient
    from azure.identity import DefaultAzureCredential

    endpoint = os.environ["FOUNDRY_PROJECT_ENDPOINT"]
    credential = DefaultAzureCredential()

    agents = []
    for spec in role_specs():
        deployment = resolve_model(spec.model_key, os.environ)
        log.info("role %-10s -> deployment %s", spec.name, deployment)
        agents.append(
            Agent(
                name=spec.name,
                description=spec.description,
                instructions=spec.instructions,
                client=FoundryChatClient(
                    project_endpoint=endpoint,
                    model=deployment,
                    credential=credential,
                ),
            )
        )

    log.info("execution order: %s", " -> ".join(plan_execution(role_specs())))
    return SequentialBuilder().participants(agents).build()


def main() -> None:
    from agent_framework_foundry_hosting import AgentHost

    workflow = build_workflow()
    host = AgentHost.create_builder()
    host.add_foundry_responses(workflow.as_agent(name="pwc-workflow-agent"))
    host.build().run()


if __name__ == "__main__":
    main()
