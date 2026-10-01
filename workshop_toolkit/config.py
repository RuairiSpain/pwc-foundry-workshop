"""Workshop configuration: parameters, defaults and validation."""
from __future__ import annotations

import os
import re
from dataclasses import dataclass, field, asdict

# Azure resource naming rules we actually depend on.
_RG_RE = re.compile(r"^[A-Za-z0-9._\-()]{1,90}$")
_ACCOUNT_RE = re.compile(r"^[a-zA-Z0-9-]{2,64}$")
_DOMAIN_RE = re.compile(r"^[A-Za-z0-9.-]+\.[A-Za-z]{2,}$")
_GUID_RE = re.compile(
    r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-"
    r"[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
)

# Regions where we have verified the workshop model set is generally offered.
# Always re-check with `az cognitiveservices account list-skus` before the event.
SUGGESTED_REGIONS = ("swedencentral", "eastus2", "westus3")


class ConfigError(ValueError):
    """Raised when workshop configuration is unusable."""


@dataclass
class WorkshopConfig:
    """Every Azure dependency the workshop needs, in one parameterised object."""

    tenant_id: str
    subscription_id: str
    tenant_domain: str
    resource_group: str = "rg-pwc-agents-lab"
    location: str = "swedencentral"
    foundry_account: str = "fdy-pwc-agents-hub"
    attendee_count: int = 35
    attendee_prefix: str = "attendee"
    project_prefix: str = "proj-attendee"
    chat_model: str = "gpt-5.4-mini"
    chat_model_version: str = "2026-03-17"
    chat_capacity: int = 200
    router_model: str = "model-router"
    router_capacity: int = 100
    embedding_model: str = "text-embedding-3-small"
    embedding_capacity: int = 50
    log_analytics_workspace: str = "law-pwc-agents-lab"
    app_insights: str = "appi-pwc-agents-lab"
    existing_hub: bool = True
    tags: dict = field(default_factory=lambda: {"purpose": "workshop", "owner": "csa"})

    # -- validation -------------------------------------------------------
    def validate(self) -> "WorkshopConfig":
        """Raise ConfigError on anything that would fail late in Azure."""
        if not _GUID_RE.match(self.tenant_id):
            raise ConfigError(f"tenant_id is not a GUID: {self.tenant_id!r}")
        if not _GUID_RE.match(self.subscription_id):
            raise ConfigError(f"subscription_id is not a GUID: {self.subscription_id!r}")
        if not _DOMAIN_RE.match(self.tenant_domain):
            raise ConfigError(f"tenant_domain looks wrong: {self.tenant_domain!r}")
        if not _RG_RE.match(self.resource_group):
            raise ConfigError(f"resource_group is not a legal name: {self.resource_group!r}")
        if not _ACCOUNT_RE.match(self.foundry_account):
            raise ConfigError(
                f"foundry_account must be 2-64 chars of letters/digits/hyphen: "
                f"{self.foundry_account!r}"
            )
        if not 1 <= self.attendee_count <= 200:
            raise ConfigError(f"attendee_count out of range: {self.attendee_count}")
        if self.chat_capacity < 10:
            raise ConfigError(
                "chat_capacity below 10 will throttle a class immediately; "
                f"got {self.chat_capacity}"
            )
        return self

    # -- derived values ---------------------------------------------------
    @property
    def account_scope(self) -> str:
        return (
            f"/subscriptions/{self.subscription_id}"
            f"/resourceGroups/{self.resource_group}"
            f"/providers/Microsoft.CognitiveServices/accounts/{self.foundry_account}"
        )

    def project_scope(self, index: int) -> str:
        return f"{self.account_scope}/projects/{self.project_name(index)}"

    def project_name(self, index: int) -> str:
        return f"{self.project_prefix}-{self.pad(index)}"

    def upn(self, index: int) -> str:
        return f"{self.attendee_prefix}{self.pad(index)}@{self.tenant_domain}"

    @staticmethod
    def pad(index: int) -> str:
        if index < 1:
            raise ConfigError(f"attendee index is 1-based; got {index}")
        return f"{index:02d}"

    @property
    def indices(self) -> range:
        return range(1, self.attendee_count + 1)

    def as_dict(self) -> dict:
        return asdict(self)

    # -- construction -----------------------------------------------------
    @classmethod
    def from_env(cls, env: dict | None = None) -> "WorkshopConfig":
        """Build config from environment variables; unset keys fall back to defaults."""
        env = os.environ if env is None else env
        kwargs: dict = {}
        mapping = {
            "WS_TENANT_ID": ("tenant_id", str),
            "WS_SUBSCRIPTION_ID": ("subscription_id", str),
            "WS_TENANT_DOMAIN": ("tenant_domain", str),
            "WS_RESOURCE_GROUP": ("resource_group", str),
            "WS_LOCATION": ("location", str),
            "WS_FOUNDRY_ACCOUNT": ("foundry_account", str),
            "WS_ATTENDEE_COUNT": ("attendee_count", int),
            "WS_CHAT_MODEL": ("chat_model", str),
            "WS_CHAT_CAPACITY": ("chat_capacity", int),
            "WS_EXISTING_HUB": ("existing_hub", lambda v: str(v).lower() in ("1", "true", "yes")),
        }
        for key, (attr, caster) in mapping.items():
            if env.get(key):
                kwargs[attr] = caster(env[key])
        missing = [
            k for k, (a, _) in mapping.items()
            if a in ("tenant_id", "subscription_id", "tenant_domain") and a not in kwargs
        ]
        if missing:
            raise ConfigError(f"required environment variables not set: {', '.join(sorted(missing))}")
        return cls(**kwargs)
