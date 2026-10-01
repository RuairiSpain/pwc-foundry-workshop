import json
import unittest
from workshop_toolkit.config import WorkshopConfig, ConfigError
from workshop_toolkit.endpoints import (
    agent_endpoint, build_curl, gateway_endpoint, is_https,
    project_endpoint, token_command,
)

GUID = "11111111-2222-3333-4444-555555555555"
CFG = WorkshopConfig(tenant_id=GUID, subscription_id=GUID,
                     tenant_domain="contoso.onmicrosoft.com")


class TestEndpoints(unittest.TestCase):
    def test_project_endpoint(self):
        url = project_endpoint(CFG, 7)
        self.assertTrue(url.startswith("https://"))
        self.assertIn("/api/projects/proj-attendee-07", url)

    def test_agent_endpoint(self):
        url = agent_endpoint(CFG, 1, "pwc-hello-agent")
        self.assertTrue(url.endswith("/agents/pwc-hello-agent/responses"))

    def test_agent_name_validated(self):
        with self.assertRaises(ConfigError):
            agent_endpoint(CFG, 1, "bad/name")
        with self.assertRaises(ConfigError):
            agent_endpoint(CFG, 1, "")

    def test_is_https(self):
        self.assertTrue(is_https("https://a.b"))
        self.assertFalse(is_https("http://a.b"))


class TestCurl(unittest.TestCase):
    def test_contains_url_and_auth(self):
        cmd = build_curl("https://x.example/responses", prompt="hi")
        self.assertIn("https://x.example/responses", cmd)
        self.assertIn("Authorization: Bearer $TOKEN", cmd)
        self.assertIn("curl -sS", cmd)

    def test_payload_is_valid_json(self):
        cmd = build_curl("https://x.example/r", prompt="hello world", stream=True)
        body = cmd.split(" -d ", 1)[1].strip("'")
        parsed = json.loads(body)
        self.assertEqual(parsed["input"], "hello world")
        self.assertTrue(parsed["stream"])

    def test_rejects_http(self):
        with self.assertRaises(ConfigError):
            build_curl("http://insecure/r")

    def test_quotes_injection_attempt(self):
        cmd = build_curl("https://x.example/r", prompt="'; rm -rf /; echo '")
        self.assertNotIn("; rm -rf /; ", cmd.split(" -d ")[0])

    def test_custom_token_var(self):
        self.assertIn("$MYTOK", build_curl("https://x/r", token_var="MYTOK"))

    def test_token_command(self):
        self.assertIn("az account get-access-token", token_command())
        self.assertIn("custom/.default", token_command("custom/.default"))


class TestGateway(unittest.TestCase):
    def test_builds_path(self):
        url = gateway_endpoint("https://gw.example.com/", "my-agent")
        self.assertEqual(url, "https://gw.example.com/agents/my-agent/responses")

    def test_rejects_http_gateway(self):
        with self.assertRaises(ConfigError):
            gateway_endpoint("http://gw", "a")


if __name__ == "__main__":
    unittest.main()
