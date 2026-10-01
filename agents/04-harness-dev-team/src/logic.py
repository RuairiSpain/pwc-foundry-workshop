"""Pure logic for Agent 4: harness selection, sub-agent team, git worktrees."""
from __future__ import annotations

import re
from dataclasses import dataclass

VALID_BACKENDS = ("magentic", "github")
_BRANCH_SAFE = re.compile(r"[^a-zA-Z0-9._/-]+")


class HarnessError(ValueError):
    pass


@dataclass(frozen=True)
class SubAgent:
    name: str
    description: str
    instructions: str


def dev_team() -> list[SubAgent]:
    """A small developer team, one sub-agent per role."""
    return [
        SubAgent(
            "architect",
            "Decides the approach and writes the plan. Writes no code.",
            "You are the tech lead. Break the request into concrete steps. "
            "State the files that will change and why. Do not write code.",
        ),
        SubAgent(
            "developer",
            "Implements the plan in the worktree.",
            "You implement the architect's plan. Make the smallest change that "
            "works. Run the tests before you claim to be finished.",
        ),
        SubAgent(
            "reviewer",
            "Reviews the diff for bugs and regressions.",
            "You review the developer's diff. Report only real defects: "
            "logic errors, missing error handling, broken tests. Ignore style.",
        ),
        SubAgent(
            "tester",
            "Writes and runs tests for the change.",
            "You write tests that would fail without the change and pass with "
            "it. Report the actual command output, never a summary of it.",
        ),
    ]


def select_backend(env: dict) -> str:
    """Resolve HARNESS_BACKEND, defaulting to magentic."""
    backend = (env.get("HARNESS_BACKEND") or "magentic").strip().lower()
    if backend not in VALID_BACKENDS:
        raise HarnessError(
            f"HARNESS_BACKEND={backend!r} is not supported; "
            f"choose one of {', '.join(VALID_BACKENDS)}"
        )
    return backend


def branch_name(session_id: str, task: str) -> str:
    """Deterministic, filesystem-safe branch name for one agent session."""
    if not session_id:
        raise HarnessError("session_id is required to isolate a worktree")
    slug = _BRANCH_SAFE.sub("-", task.lower()).strip("-")[:40] or "task"
    return f"agent/{session_id[:8]}/{slug}"


def worktree_path(root: str, session_id: str) -> str:
    """Each session gets its own worktree inside the per-session sandbox."""
    if not root.startswith("/"):
        raise HarnessError(f"worktree root must be absolute, got {root!r}")
    if not session_id:
        raise HarnessError("session_id is required")
    return f"{root.rstrip('/')}/{session_id[:8]}"


def worktree_commands(repo: str, root: str, session_id: str, task: str) -> list[str]:
    """The exact git commands the agent runs to isolate its work.

    Worktrees rather than clones: one fetch, many cheap branches, and each
    sub-agent can hold a different checkout of the same repository at once.
    """
    if not repo:
        raise HarnessError("REPO_URL is not set")
    path = worktree_path(root, session_id)
    branch = branch_name(session_id, task)
    return [
        f"git -C {root} fetch --all --prune",
        f"git -C {root} worktree add -b {branch} {path} origin/main",
        f"git -C {path} status --short",
    ]


def cleanup_commands(root: str, session_id: str) -> list[str]:
    path = worktree_path(root, session_id)
    return [
        f"git -C {root} worktree remove --force {path}",
        f"git -C {root} worktree prune",
    ]
