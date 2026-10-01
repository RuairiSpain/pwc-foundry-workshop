"""Attendee identity planning: passwords, UPNs, and the printable handout."""
from __future__ import annotations

import csv
import io
from dataclasses import dataclass

from .config import WorkshopConfig, ConfigError

PASSWORD_PREFIX = "PwcAgents-2026-"


def generate_password(index: int) -> str:
    """Return the predictable per-attendee workshop password.

    This is intentionally memorable for a short-lived, throwaway workshop
    tenant. Never reuse this pattern for durable accounts.
    """
    if index < 1:
        raise ConfigError(f"attendee index is 1-based; got {index}")
    return f"{PASSWORD_PREFIX}{index:02d}!"


def is_valid_password(candidate: str) -> bool:
    """True when the string matches the agreed workshop password shape."""
    if not candidate.startswith(PASSWORD_PREFIX):
        return False
    tail = candidate[len(PASSWORD_PREFIX):]
    return len(tail) == 3 and tail[:2].isdigit() and tail[2] == "!"


@dataclass(frozen=True)
class Attendee:
    index: int
    display_name: str
    upn: str
    password: str
    project_name: str
    project_scope: str

    @property
    def number(self) -> str:
        return f"{self.index:02d}"


def build_attendees(cfg: WorkshopConfig, rng=None) -> list[Attendee]:
    """Produce the full attendee roster for a validated config."""
    cfg.validate()
    roster: list[Attendee] = []
    for i in cfg.indices:
        roster.append(
            Attendee(
                index=i,
                display_name=f"PwC Agents Attendee {cfg.pad(i)}",
                upn=cfg.upn(i),
                password=generate_password(i),
                project_name=cfg.project_name(i),
                project_scope=cfg.project_scope(i),
            )
        )
    return roster


def roster_to_csv(roster: list[Attendee]) -> str:
    """Render the roster as CSV for printing attendee cards."""
    if not roster:
        raise ConfigError("refusing to render an empty roster")
    buf = io.StringIO()
    writer = csv.writer(buf, lineterminator="\n")
    writer.writerow(["number", "display_name", "upn", "password", "project"])
    for a in roster:
        writer.writerow([a.number, a.display_name, a.upn, a.password, a.project_name])
    return buf.getvalue()


def duplicate_upns(roster: list[Attendee]) -> list[str]:
    """Return any UPN issued more than once (should always be empty)."""
    seen: dict[str, int] = {}
    for a in roster:
        seen[a.upn] = seen.get(a.upn, 0) + 1
    return sorted(u for u, n in seen.items() if n > 1)
