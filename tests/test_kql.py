import unittest
from workshop_toolkit import kql
from workshop_toolkit.config import ConfigError


class TestLookback(unittest.TestCase):
    def test_accepts_units(self):
        for lb in ("30m", "1h", "7d"):
            kql.agent_requests("p", lb)

    def test_rejects_bad(self):
        for bad in ("", "1y", "h", "abc"):
            with self.assertRaises(ConfigError):
                kql.agent_requests("p", bad)


class TestQueries(unittest.TestCase):
    def test_discovery(self):
        self.assertIn("summarize", kql.table_discovery())

    def test_requests_includes_project(self):
        q = kql.agent_requests("proj-attendee-07")
        self.assertIn("proj-attendee-07", q)
        self.assertIn("percentile", q)

    def test_requests_requires_project(self):
        with self.assertRaises(ConfigError):
            kql.agent_requests("")

    def test_errors_filters_failures(self):
        q = kql.agent_errors("p1")
        self.assertIn("ResultType != 'Success'", q)

    def test_gateway(self):
        self.assertIn("ApiManagementGatewayLogs", kql.gateway_calls())

    def test_tokens(self):
        self.assertIn("render timechart", kql.token_usage_by_model())

    def test_trace(self):
        self.assertIn("abc-123", kql.trace_by_correlation("abc-123"))

    def test_trace_requires_id(self):
        with self.assertRaises(ConfigError):
            kql.trace_by_correlation("")

    def test_all_queries_registry(self):
        self.assertEqual(len(kql.ALL_QUERIES), 6)
        self.assertIn("00-discover-tables", kql.ALL_QUERIES)


if __name__ == "__main__":
    unittest.main()
