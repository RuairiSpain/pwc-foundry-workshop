import unittest
from workshop_toolkit import manifest

GOOD = """
name: demo
services:
  ai-project:
    host: azure.ai.project
  learn-mcp:
    host: azure.ai.connection
    uses: [ai-project]
  tools:
    host: azure.ai.toolbox
    uses: [ai-project, learn-mcp]
    tools:
      - type: mcp
        connection: learn-mcp
  my-agent:
    host: azure.ai.agent
    name: my-agent
    uses: [ai-project, tools]
    toolboxes: [tools]
    protocols:
      - protocol: responses
        version: 2.0.0
    sessionConfiguration:
      idleTimeoutSeconds: 300
"""


class TestIdleTimeout(unittest.TestCase):
    def test_accepts_range(self):
        for v in (300, 900, 1800, 3600):
            manifest.validate_idle_timeout(v)

    def test_rejects_below_min(self):
        with self.assertRaises(ValueError):
            manifest.validate_idle_timeout(299)

    def test_rejects_above_max(self):
        with self.assertRaises(ValueError):
            manifest.validate_idle_timeout(3601)

    def test_rejects_non_int(self):
        with self.assertRaises(ValueError):
            manifest.validate_idle_timeout("300")

    def test_constants(self):
        self.assertEqual((manifest.IDLE_MIN, manifest.IDLE_DEFAULT, manifest.IDLE_MAX),
                         (300, 900, 3600))


class TestValidate(unittest.TestCase):
    def test_good_manifest_has_no_problems(self):
        self.assertEqual(manifest.validate(manifest.load(GOOD)), [])

    def test_load_rejects_non_mapping(self):
        with self.assertRaises(ValueError):
            manifest.load("- a\n- b")

    def test_missing_services(self):
        self.assertIn("no 'services' block found", manifest.validate({}))

    def test_missing_project(self):
        doc = {"services": {"a": {"host": "azure.ai.agent", "protocols": [1]}}}
        self.assertTrue(any("azure.ai.project" in p for p in manifest.validate(doc)))

    def test_missing_agent(self):
        doc = {"services": {"p": {"host": "azure.ai.project"}}}
        self.assertTrue(any("azure.ai.agent" in p for p in manifest.validate(doc)))

    def test_unknown_host(self):
        doc = {"services": {"p": {"host": "azure.ai.project"},
                            "x": {"host": "azure.ai.nonsense"},
                            "a": {"host": "azure.ai.agent", "protocols": [1]}}}
        self.assertTrue(any("unknown host" in p for p in manifest.validate(doc)))

    def test_undeclared_uses(self):
        bad = GOOD.replace("uses: [ai-project, tools]", "uses: [ai-project, ghost]")
        self.assertTrue(any("undeclared service 'ghost'" in p
                            for p in manifest.validate(manifest.load(bad))))

    def test_toolbox_not_in_uses(self):
        bad = GOOD.replace("uses: [ai-project, tools]\n    toolboxes: [tools]",
                           "uses: [ai-project]\n    toolboxes: [tools]")
        problems = manifest.validate(manifest.load(bad))
        self.assertTrue(any("does not 'uses' it" in p for p in problems))

    def test_unknown_toolbox(self):
        bad = GOOD.replace("toolboxes: [tools]", "toolboxes: [missing]")
        self.assertTrue(any("unknown toolbox" in p
                            for p in manifest.validate(manifest.load(bad))))

    def test_bad_idle_timeout_reported(self):
        bad = GOOD.replace("idleTimeoutSeconds: 300", "idleTimeoutSeconds: 60")
        problems = manifest.validate(manifest.load(bad))
        self.assertTrue(any("outside the accepted" in p for p in problems))

    def test_missing_protocols(self):
        bad = GOOD.replace("    protocols:\n      - protocol: responses\n        version: 2.0.0\n", "")
        self.assertTrue(any("declares no protocols" in p
                            for p in manifest.validate(manifest.load(bad))))

    def test_empty_toolbox(self):
        bad = GOOD.replace("    tools:\n      - type: mcp\n        connection: learn-mcp\n",
                           "    tools: []\n", 1)
        self.assertTrue(any("declares no tools" in p
                            for p in manifest.validate(manifest.load(bad))))

    def test_mcp_without_connection(self):
        bad = GOOD.replace("      - type: mcp\n        connection: learn-mcp",
                           "      - type: mcp")
        self.assertTrue(any("no 'connection'" in p
                            for p in manifest.validate(manifest.load(bad))))

    def test_agent_names(self):
        self.assertEqual(manifest.agent_names(manifest.load(GOOD)), ["my-agent"])


if __name__ == "__main__":
    unittest.main()
