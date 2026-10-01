"""Validation for hosted-agent azure.yaml files.

Catches, before a 6-minute azd deploy fails, the mistakes we actually hit:
an idle timeout outside the accepted range, a toolbox referenced but never
declared, a `uses` entry with no matching service.
"""
from __future__ import annotations

import yaml

IDLE_MIN, IDLE_DEFAULT, IDLE_MAX = 300, 900, 3600
AGENT_HOST = "azure.ai.agent"
PROJECT_HOST = "azure.ai.project"
TOOLBOX_HOST = "azure.ai.toolbox"
CONNECTION_HOST = "azure.ai.connection"
KNOWN_HOSTS = {
    AGENT_HOST, PROJECT_HOST, TOOLBOX_HOST, CONNECTION_HOST,
    "azure.ai.skill", "azure.ai.routine",
}


def load(text: str) -> dict:
    data = yaml.safe_load(text)
    if not isinstance(data, dict):
        raise ValueError("azure.yaml must parse to a mapping")
    return data


def validate_idle_timeout(seconds: int) -> None:
    if not isinstance(seconds, int):
        raise ValueError(f"idleTimeoutSeconds must be an integer, got {type(seconds).__name__}")
    if not IDLE_MIN <= seconds <= IDLE_MAX:
        raise ValueError(
            f"idleTimeoutSeconds={seconds} is outside the accepted "
            f"{IDLE_MIN}-{IDLE_MAX} range and is rejected at deploy time"
        )


def validate(doc: dict) -> list[str]:
    """Return a list of problems; empty means the manifest looks deployable."""
    problems: list[str] = []
    services = doc.get("services")
    if not isinstance(services, dict) or not services:
        return ["no 'services' block found"]

    names = set(services)
    hosts = {n: (s or {}).get("host") for n, s in services.items()}

    for name, host in hosts.items():
        if host not in KNOWN_HOSTS:
            problems.append(f"service {name!r} has unknown host {host!r}")

    if PROJECT_HOST not in hosts.values():
        problems.append(f"no service with host {PROJECT_HOST}")

    agents = [n for n, h in hosts.items() if h == AGENT_HOST]
    if not agents:
        problems.append(f"no service with host {AGENT_HOST}")

    for name, svc in services.items():
        svc = svc or {}
        for dep in svc.get("uses", []) or []:
            if dep not in names:
                problems.append(f"service {name!r} uses undeclared service {dep!r}")

        if svc.get("host") == AGENT_HOST:
            session = svc.get("sessionConfiguration") or {}
            if "idleTimeoutSeconds" in session:
                try:
                    validate_idle_timeout(session["idleTimeoutSeconds"])
                except ValueError as exc:
                    problems.append(f"service {name!r}: {exc}")
            for tb in svc.get("toolboxes", []) or []:
                if tb not in names:
                    problems.append(f"agent {name!r} references unknown toolbox {tb!r}")
                elif tb not in (svc.get("uses") or []):
                    problems.append(
                        f"agent {name!r} lists toolbox {tb!r} but does not 'uses' it; "
                        "azd will not order the deployment correctly"
                    )
            if not svc.get("protocols"):
                problems.append(f"agent {name!r} declares no protocols")

        if svc.get("host") == TOOLBOX_HOST:
            tools = svc.get("tools") or []
            if not tools:
                problems.append(f"toolbox {name!r} declares no tools")
            for tool in tools:
                if tool.get("type") == "mcp" and not tool.get("connection"):
                    problems.append(
                        f"toolbox {name!r} has an mcp tool with no 'connection'"
                    )
    return problems


def agent_names(doc: dict) -> list[str]:
    services = doc.get("services") or {}
    return sorted(
        (svc or {}).get("name", n)
        for n, svc in services.items()
        if (svc or {}).get("host") == AGENT_HOST
    )
