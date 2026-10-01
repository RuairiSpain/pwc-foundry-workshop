"""Endpoint and client-call construction for testing published agents."""
from __future__ import annotations

import json
import shlex
from urllib.parse import urlparse

from .config import WorkshopConfig, ConfigError


def project_endpoint(cfg: WorkshopConfig, index: int) -> str:
    """Data-plane endpoint for one attendee's Foundry project."""
    return (
        f"https://{cfg.foundry_account}.services.ai.azure.com"
        f"/api/projects/{cfg.project_name(index)}"
    )


def agent_endpoint(cfg: WorkshopConfig, index: int, agent_name: str) -> str:
    """Responses-protocol endpoint for a published hosted agent."""
    if not agent_name or "/" in agent_name:
        raise ConfigError(f"invalid agent name: {agent_name!r}")
    return f"{project_endpoint(cfg, index)}/agents/{agent_name}/responses"


def is_https(url: str) -> bool:
    return urlparse(url).scheme == "https"


def build_curl(url: str, token_var: str = "TOKEN", prompt: str = "Hello",
               stream: bool = False) -> str:
    """A copy-pasteable curl command for the Responses protocol.

    Attendees run this in the Codespaces terminal after publishing.
    """
    if not is_https(url):
        raise ConfigError(f"refusing to build a non-HTTPS call: {url!r}")
    payload = {"input": prompt, "stream": stream}
    body = shlex.quote(json.dumps(payload))
    return (
        f"curl -sS {shlex.quote(url)} "
        f'-H "Authorization: Bearer ${token_var}" '
        '-H "Content-Type: application/json" '
        f"-d {body}"
    )


def token_command(scope: str = "https://ai.azure.com/.default") -> str:
    """az command that mints the bearer token the curl call needs."""
    return f'TOKEN=$(az account get-access-token --scope {scope} --query accessToken -o tsv)'


def gateway_endpoint(gateway_host: str, agent_name: str) -> str:
    """Route the same agent through an AI gateway host instead of direct.

    NOTE: confirm the exact gateway path with your gateway deployment; this
    builds the conventional /agents/<name>/responses shape.
    """
    host = gateway_host.rstrip("/")
    if not is_https(host):
        raise ConfigError(f"gateway host must be https: {gateway_host!r}")
    return f"{host}/agents/{agent_name}/responses"
