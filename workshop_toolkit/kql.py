"""KQL builders for the observability lab.

Attendees run these in Log Analytics after talking to their agents, so they can
see the same turn from three angles: Foundry traces, gateway access logs, and
the raw dependency telemetry.

NOTE ON TABLE NAMES: the exact table a Foundry agent writes to depends on the
diagnostic settings you configure on the account (see infra/25-observability.sh)
and on whether you route app telemetry to Application Insights. Confirm the
table names in your own workspace with the `table_discovery()` query below
before handing these to attendees.
"""
from __future__ import annotations

from .config import ConfigError

DEFAULT_LOOKBACK = "1h"
_ALLOWED_UNITS = ("m", "h", "d")


def _check_lookback(lookback: str) -> str:
    if not lookback or lookback[-1] not in _ALLOWED_UNITS or not lookback[:-1].isdigit():
        raise ConfigError(
            f"lookback must look like 30m/1h/7d, got {lookback!r}"
        )
    return lookback


def table_discovery() -> str:
    """Step 0: find out which tables actually received data."""
    return (
        "search *\n"
        "| where TimeGenerated > ago(1d)\n"
        "| summarize Rows=count() by $table\n"
        "| order by Rows desc"
    )


def agent_requests(project_name: str, lookback: str = DEFAULT_LOOKBACK) -> str:
    """Request volume and latency for one attendee's spoke project."""
    _check_lookback(lookback)
    if not project_name:
        raise ConfigError("project_name is required")
    return (
        f"AzureDiagnostics\n"
        f"| where TimeGenerated > ago({lookback})\n"
        f"| where ResourceProvider == 'MICROSOFT.COGNITIVESERVICES'\n"
        f"| where Resource contains '{project_name}'\n"
        f"| summarize Calls=count(), P95Latency=percentile(DurationMs, 95) "
        f"by OperationName, bin(TimeGenerated, 5m)\n"
        f"| order by TimeGenerated desc"
    )


def agent_errors(project_name: str, lookback: str = DEFAULT_LOOKBACK) -> str:
    """Only the failures - the query to run when an attendee says 'it broke'."""
    _check_lookback(lookback)
    return (
        f"AzureDiagnostics\n"
        f"| where TimeGenerated > ago({lookback})\n"
        f"| where Resource contains '{project_name}'\n"
        f"| where ResultType != 'Success'\n"
        f"| project TimeGenerated, OperationName, ResultType, ResultSignature, "
        f"ResultDescription, CorrelationId\n"
        f"| order by TimeGenerated desc\n"
        f"| take 50"
    )


def gateway_calls(lookback: str = DEFAULT_LOOKBACK) -> str:
    """Access log for calls that went through the AI gateway.

    Lets attendees prove a request took the gateway path, not the direct one.
    """
    _check_lookback(lookback)
    return (
        f"ApiManagementGatewayLogs\n"
        f"| where TimeGenerated > ago({lookback})\n"
        f"| summarize Calls=count(), Failures=countif(ResponseCode >= 400), "
        f"P95=percentile(TotalTime, 95) by ApiId, OperationId\n"
        f"| order by Calls desc"
    )


def token_usage_by_model(lookback: str = "1d") -> str:
    """Cost lab: which model burned the tokens."""
    _check_lookback(lookback)
    return (
        f"AzureMetrics\n"
        f"| where TimeGenerated > ago({lookback})\n"
        f"| where MetricName in ('TokenTransaction', 'ProcessedPromptTokens', "
        f"'GeneratedTokens')\n"
        f"| summarize Tokens=sum(Total) by MetricName, bin(TimeGenerated, 1h)\n"
        f"| render timechart"
    )


def trace_by_correlation(correlation_id: str) -> str:
    """Follow one conversation end to end from a trace id in the portal."""
    if not correlation_id:
        raise ConfigError("correlation_id is required")
    return (
        f"union AzureDiagnostics, AppTraces, AppDependencies\n"
        f"| where TimeGenerated > ago(1d)\n"
        f"| where * has '{correlation_id}'\n"
        f"| project TimeGenerated, Type, OperationName, Message, DurationMs\n"
        f"| order by TimeGenerated asc"
    )


ALL_QUERIES = {
    "00-discover-tables": table_discovery,
    "01-agent-requests": agent_requests,
    "02-agent-errors": agent_errors,
    "03-gateway-calls": gateway_calls,
    "04-token-usage": token_usage_by_model,
    "05-follow-one-trace": trace_by_correlation,
}
