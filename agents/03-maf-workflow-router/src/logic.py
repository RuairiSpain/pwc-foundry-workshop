"""Pure workflow logic for Agent 3: role definitions and model routing."""
from __future__ import annotations

from dataclasses import dataclass

# Which model each role should use when NOT delegating to model-router.
# The point of the lab: you can route per-role, or let model-router decide.
ROLE_MODEL_HINTS = {
    "researcher": "cheap_b",   # lots of short tool calls -> cheapest model
    "analyst": "router",       # variable difficulty -> let the router choose
    "writer": "cheap_a",       # longer output, needs better prose
}


class WorkflowError(ValueError):
    pass


@dataclass(frozen=True)
class RoleSpec:
    name: str
    description: str
    instructions: str
    model_key: str


def role_specs() -> list[RoleSpec]:
    """The three workers in the workflow."""
    return [
        RoleSpec(
            "researcher",
            "Gathers facts from Microsoft Learn. Does no analysis.",
            "You gather facts only. Call the Microsoft Learn MCP tools. "
            "Return bullet points with the source URL for each. "
            "Do not interpret, rank, or conclude.",
            ROLE_MODEL_HINTS["researcher"],
        ),
        RoleSpec(
            "analyst",
            "Turns gathered facts into findings. Calls no tools.",
            "You receive facts. Identify what matters, what conflicts, and what "
            "is missing. Never invent a fact that was not given to you.",
            ROLE_MODEL_HINTS["analyst"],
        ),
        RoleSpec(
            "writer",
            "Writes the final answer for a business reader.",
            "Write the final answer in British English for a busy executive. "
            "Lead with the conclusion. Keep every source the analyst cited.",
            ROLE_MODEL_HINTS["writer"],
        ),
    ]


def resolve_model(model_key: str, env: dict) -> str:
    """Map a role's model key onto an actual deployment name."""
    table = {
        "router": env.get("ROUTER_DEPLOYMENT_NAME", "model-router"),
        "cheap_a": env.get("CHEAP_MODEL_A", "gpt-5.4-mini"),
        "cheap_b": env.get("CHEAP_MODEL_B", "gpt-5.4-nano"),
    }
    if model_key not in table:
        raise WorkflowError(
            f"unknown model key {model_key!r}; expected one of {sorted(table)}"
        )
    return table[model_key]


def plan_execution(specs: list[RoleSpec]) -> list[str]:
    """Sequential order. Named so a test can pin the contract."""
    if not specs:
        raise WorkflowError("a workflow needs at least one role")
    return [s.name for s in specs]


def estimate_calls(specs: list[RoleSpec], turns: int = 1) -> int:
    """Rough model-call count, used in the cost discussion in the lab."""
    if turns < 1:
        raise WorkflowError("turns must be >= 1")
    return len(specs) * turns
