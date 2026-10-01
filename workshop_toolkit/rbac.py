"""Role-assignment planning for the hub-and-spoke Foundry topology.

Role GUIDs are used rather than display names: the Foundry roles were renamed
(Azure AI User -> Foundry User, etc.) and the rename is still rolling out, so
name-based assignment can fail depending on tenant. The IDs are stable.

Every grant below is traceable to the Foundry hosted-agent permissions
reference. See `reason` on each RoleAssignment.
"""
from __future__ import annotations

from dataclasses import dataclass

from .config import WorkshopConfig
from .identity import Attendee

# Verified GUIDs. Roles whose GUID we have NOT verified are resolved by name at
# runtime by the shell script (see infra/30-assign-rbac.sh: resolve_role).
ROLE_IDS = {
    "Foundry User": "53ca6127-db72-4b80-b1b0-d745d6d5456d",
    "Foundry Project Manager": "eadc314b-1a2d-4efa-be10-5d325db5065e",
    "Foundry Owner": "c883944f-8b7b-4483-af10-35834be79c4a",
    "Foundry Agent Consumer": "eed3b665-ab3a-47b6-8f48-c9382fb1dad6",
    "Reader": "acdd72a7-3385-48ef-bd42-f606fba81ae7",
    "Cognitive Services OpenAI User": "5e0bd9bd-7b93-4f28-af87-19fc36ad61bd",
    "Cognitive Services Usages Reader": "bba48692-92b0-4667-a9ad-c31c7b334ac2",
    "AcrPull": "7f951dda-4ed3-4680-a7ca-43fe172d538d",
    "AcrPush": "8311e382-0749-4cb8-b61a-304f252e45ec",
    "Monitoring Reader": "43d0d8ad-25c7-4714-9337-8ba259a9fe05",
    "Log Analytics Reader": "73c42c96-874c-492b-b04d-ab87d138a893",
}

# Roles that carry Foundry DATA-plane rights. Granting any of these outside an
# attendee's own spoke breaks isolation.
DATA_PLANE_ROLES = {"Foundry User", "Foundry Owner", "Foundry Project Manager"}


@dataclass(frozen=True)
class RoleAssignment:
    principal_upn: str
    role_name: str
    role_id: str
    scope: str
    reason: str
    principal_type: str = "User"

    def to_az_cli(self, object_id_var: str = "$OID") -> str:
        return (
            "az role assignment create "
            f'--assignee-object-id "{object_id_var}" '
            f"--assignee-principal-type {self.principal_type} "
            f'--role "{self.role_id}" '
            f'--scope "{self.scope}"'
        )


def plan_for_attendee(cfg: WorkshopConfig, attendee: Attendee) -> list[RoleAssignment]:
    """Least-privilege set that still lets an attendee complete every lab.

    Foundry Project Manager (not Foundry User) on their own spoke, because the
    labs create CONNECTIONS (azure.ai.connection services in azure.yaml) and
    Foundry User cannot do that:
      "Creating a connection requires ...projects/connections/write at the scope
       of the Foundry project. Foundry User: No. Foundry Project Manager: Yes."
    Project Manager also covers agent applications and can assign Foundry User,
    which agent-identity scenarios need. Scoped to their own project only, so it
    grants nothing over anyone else's spoke.
    """
    sub = f"/subscriptions/{cfg.subscription_id}"
    rg = f"{sub}/resourceGroups/{cfg.resource_group}"
    own = attendee.project_scope
    appi = f"{rg}/providers/Microsoft.Insights/components/{cfg.app_insights}"
    law = (f"{rg}/providers/Microsoft.OperationalInsights/workspaces/"
           f"{cfg.log_analytics_workspace}")

    return [
        RoleAssignment(
            attendee.upn, "Reader", ROLE_IDS["Reader"], cfg.account_scope,
            "See the hub, its shared model deployments, and that sibling spokes "
            "exist. Control plane only - no data access to siblings.",
        ),
        RoleAssignment(
            attendee.upn, "Foundry Project Manager",
            ROLE_IDS["Foundry Project Manager"], own,
            "Create agents AND connections on their own spoke. Foundry User "
            "cannot create connections, which every lab needs for MCP.",
        ),
        RoleAssignment(
            attendee.upn, "Cognitive Services OpenAI User",
            ROLE_IDS["Cognitive Services OpenAI User"], cfg.account_scope,
            "Direct account-level OpenAI endpoint access; required by the "
            "memory store's embedding calls. Without it, memory writes fail "
            "401 and the store stays silently empty.",
        ),
        RoleAssignment(
            attendee.upn, "Cognitive Services Usages Reader",
            ROLE_IDS["Cognitive Services Usages Reader"], sub,
            "Quota visibility, so portal deployment validation works.",
        ),
        RoleAssignment(
            attendee.upn, "AcrPush", ROLE_IDS["AcrPush"], rg,
            "Push the hosted-agent container image during azd deploy.",
        ),
        RoleAssignment(
            attendee.upn, "Monitoring Reader", ROLE_IDS["Monitoring Reader"], appi,
            "Read agent TRACES in Lab 5. Foundry User sees metrics but NOT "
            "traces - this role is what makes the tracing lab work.",
        ),
        RoleAssignment(
            attendee.upn, "Log Analytics Reader",
            ROLE_IDS["Log Analytics Reader"], law,
            "Run the KQL queries in Lab 5 directly against the workspace.",
        ),
    ]


def plan_for_project_identity(cfg: WorkshopConfig, index: int) -> list[RoleAssignment]:
    """Grants the PROJECT MANAGED IDENTITY needs (not the human)."""
    rg = f"/subscriptions/{cfg.subscription_id}/resourceGroups/{cfg.resource_group}"
    law = (f"{rg}/providers/Microsoft.OperationalInsights/workspaces/"
           f"{cfg.log_analytics_workspace}")
    name = f"{cfg.project_name(index)}-identity"
    return [
        RoleAssignment(
            name, "Foundry User", ROLE_IDS["Foundry User"], cfg.account_scope,
            "Project proxies model inference to the hub deployment using its "
            "own managed identity.", "ServicePrincipal",
        ),
        RoleAssignment(
            name, "AcrPull", ROLE_IDS["AcrPull"], rg,
            "Pull the agent container image at runtime.", "ServicePrincipal",
        ),
        RoleAssignment(
            name, "Log Analytics Reader", ROLE_IDS["Log Analytics Reader"], law,
            "Read telemetry for the evaluations step in Lab 5.",
            "ServicePrincipal",
        ),
    ]


def plan_for_shared_demo_access(cfg: WorkshopConfig, attendee: Attendee,
                                demo_project: str) -> list[RoleAssignment]:
    """Let attendees INVOKE the instructor's demo agents without editing them.

    Agents are data-plane objects living inside a project. Reader on the hub
    does NOT expose them. Foundry Agent Consumer is the least-privilege role
    that allows runtime interaction and nothing else.
    """
    scope = f"{cfg.account_scope}/projects/{demo_project}"
    return [
        RoleAssignment(
            attendee.upn, "Foundry Agent Consumer",
            ROLE_IDS["Foundry Agent Consumer"], scope,
            "Invoke the instructor's shared demo agents. Cannot create, edit "
            "or delete them.",
        ),
    ]


def plan_all(cfg: WorkshopConfig, roster: list[Attendee]) -> list[RoleAssignment]:
    out: list[RoleAssignment] = []
    for a in roster:
        out.extend(plan_for_attendee(cfg, a))
    for i in cfg.indices:
        out.extend(plan_for_project_identity(cfg, i))
    return out


def cross_spoke_leakage(plan: list[RoleAssignment], roster: list[Attendee]) -> list[str]:
    """Detect data-plane grants that would let one attendee write another's spoke.

    Returns human-readable problems; empty list means the isolation holds.
    Service principals (project managed identities) are exempt: they legitimately
    hold Foundry User at hub scope so the project can reach shared models.
    """
    own_scope = {a.upn: a.project_scope for a in roster}
    problems: list[str] = []
    for ra in plan:
        if ra.role_name not in DATA_PLANE_ROLES:
            continue
        if ra.principal_type == "ServicePrincipal":
            continue
        mine = own_scope.get(ra.principal_upn)
        if mine is None:
            problems.append(f"{ra.principal_upn} is not on the roster")
        elif not ra.scope.startswith(mine):
            problems.append(
                f"{ra.principal_upn} has {ra.role_name} at {ra.scope}, "
                f"outside their own spoke {mine}"
            )
    return problems


def capability_matrix() -> list[tuple[str, str, str]]:
    """(capability, granted by, scope) - the table in the README, as data."""
    return [
        ("See the hub and its shared models", "Reader", "hub"),
        ("See that sibling spokes exist", "Reader", "hub"),
        ("Read a sibling's agents or data", "-- deliberately NOT granted --", "-"),
        ("Create agents on own spoke", "Foundry Project Manager", "own project"),
        ("Create MCP connections", "Foundry Project Manager", "own project"),
        ("Deploy hosted agents / versions", "Foundry Project Manager", "own project"),
        ("Push agent container images", "AcrPush", "resource group"),
        ("Call shared models", "Foundry Project Manager + Reader", "project + hub"),
        ("Memory store embeddings", "Cognitive Services OpenAI User", "hub"),
        ("See quota in the portal", "Cognitive Services Usages Reader", "subscription"),
        ("Read agent traces", "Monitoring Reader", "App Insights"),
        ("Run KQL in Lab 5", "Log Analytics Reader", "workspace"),
        ("Invoke instructor demo agents", "Foundry Agent Consumer", "demo project"),
    ]
