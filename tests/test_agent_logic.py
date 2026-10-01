"""Tests for the per-agent pure logic modules."""
import importlib.util
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


def load(path, name):
    """Import a module by file path.

    The module must be registered in sys.modules *before* exec_module, or
    dataclasses cannot resolve string annotations (PEP 563) and blows up with a
    confusing AttributeError on NoneType.
    """
    spec = importlib.util.spec_from_file_location(name, ROOT / path)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


know = load("agents/02-hosted-knowledge-agent/src/logic.py", "know_logic")
flow = load("agents/03-maf-workflow-router/src/logic.py", "flow_logic")
team = load("agents/04-harness-dev-team/src/logic.py", "team_logic")
mem = load("agents/02-hosted-knowledge-agent/scripts/provision_memory_store.py", "mem_prov")

ENV_OK = {
    "FOUNDRY_PROJECT_ENDPOINT": "https://acct.services.ai.azure.com/api/projects/p1",
    "MICROSOFT_FOUNDRY_MODEL_DEPLOYMENT_NAME": "gpt-5.4-mini",
    "MEMORY_STORE_NAME": "store1",
    "EMBEDDING_DEPLOYMENT_NAME": "text-embedding-3-small",
}


class TestKnowledgeAgent(unittest.TestCase):
    def test_settings_ok(self):
        s = know.resolve_settings(ENV_OK)
        self.assertEqual(s.model, "gpt-5.4-mini")
        self.assertTrue(s.tracing)

    def test_missing_endpoint(self):
        with self.assertRaises(know.SettingsError) as e:
            know.resolve_settings({})
        self.assertIn("azd ai agent run", str(e.exception))

    def test_http_endpoint_rejected(self):
        with self.assertRaises(know.SettingsError):
            know.resolve_settings({"FOUNDRY_PROJECT_ENDPOINT": "http://x"})

    def test_trailing_slash_stripped(self):
        s = know.resolve_settings({**ENV_OK, "FOUNDRY_PROJECT_ENDPOINT": "https://x/p1/"})
        self.assertFalse(s.project_endpoint.endswith("/"))

    def test_tracing_can_be_disabled(self):
        s = know.resolve_settings({**ENV_OK, "ENABLE_TRACING": "false"})
        self.assertFalse(s.tracing)

    def test_memory_enabled(self):
        self.assertTrue(know.should_enable_memory(know.resolve_settings(ENV_OK)))

    def test_memory_disabled_without_store(self):
        s = know.resolve_settings({**ENV_OK, "MEMORY_STORE_NAME": ""})
        self.assertFalse(know.should_enable_memory(s))

    def test_instructions_mention_each_tool(self):
        text = know.build_instructions()
        for token in ("Learn MCP", "pwc_site_search", "workshop_pdfs"):
            self.assertIn(token, text)

    def test_tool_policy_summary(self):
        self.assertEqual(len(know.summarise_tool_policy()), 4)


class TestMemoryProvisioning(unittest.TestCase):
    def test_spec(self):
        spec = mem.build_store_spec("s", "chat", "embed")
        self.assertEqual(spec["name"], "s")
        self.assertEqual(spec["embeddingModel"]["deploymentName"], "embed")
        self.assertEqual(spec["scope"], "user")

    def test_spec_requires_name(self):
        with self.assertRaises(ValueError):
            mem.build_store_spec("", "c", "e")

    def test_main_skips_without_endpoint(self):
        self.assertEqual(mem.main(["prog"]), 0)


class TestWorkflowAgent(unittest.TestCase):
    def test_three_roles(self):
        self.assertEqual(len(flow.role_specs()), 3)

    def test_order(self):
        self.assertEqual(flow.plan_execution(flow.role_specs()),
                         ["researcher", "analyst", "writer"])

    def test_empty_plan_rejected(self):
        with self.assertRaises(flow.WorkflowError):
            flow.plan_execution([])

    def test_analyst_uses_router(self):
        analyst = [s for s in flow.role_specs() if s.name == "analyst"][0]
        self.assertEqual(analyst.model_key, "router")

    def test_resolve_model(self):
        env = {"ROUTER_DEPLOYMENT_NAME": "mr", "CHEAP_MODEL_A": "a", "CHEAP_MODEL_B": "b"}
        self.assertEqual(flow.resolve_model("router", env), "mr")
        self.assertEqual(flow.resolve_model("cheap_a", env), "a")
        self.assertEqual(flow.resolve_model("cheap_b", env), "b")

    def test_resolve_model_defaults(self):
        self.assertEqual(flow.resolve_model("router", {}), "model-router")

    def test_unknown_model_key(self):
        with self.assertRaises(flow.WorkflowError):
            flow.resolve_model("gpt-9", {})

    def test_estimate_calls(self):
        self.assertEqual(flow.estimate_calls(flow.role_specs(), 2), 6)

    def test_estimate_rejects_zero_turns(self):
        with self.assertRaises(flow.WorkflowError):
            flow.estimate_calls(flow.role_specs(), 0)


class TestDevTeamAgent(unittest.TestCase):
    def test_four_subagents(self):
        self.assertEqual(len(team.dev_team()), 4)
        self.assertEqual([s.name for s in team.dev_team()],
                         ["architect", "developer", "reviewer", "tester"])

    def test_backend_default(self):
        self.assertEqual(team.select_backend({}), "magentic")

    def test_backend_github(self):
        self.assertEqual(team.select_backend({"HARNESS_BACKEND": "GitHub"}), "github")

    def test_backend_invalid(self):
        with self.assertRaises(team.HarnessError):
            team.select_backend({"HARNESS_BACKEND": "langchain"})

    def test_branch_name_safe(self):
        b = team.branch_name("abcdef123456", "Add OAuth login!! (urgent)")
        self.assertTrue(b.startswith("agent/abcdef12/"))
        self.assertNotIn(" ", b)
        self.assertNotIn("!", b)

    def test_branch_name_truncates(self):
        b = team.branch_name("s1234567", "x" * 200)
        self.assertLessEqual(len(b.split("/")[-1]), 40)

    def test_branch_name_empty_task(self):
        self.assertTrue(team.branch_name("s1234567", "!!!").endswith("task"))

    def test_branch_requires_session(self):
        with self.assertRaises(team.HarnessError):
            team.branch_name("", "t")

    def test_worktree_path(self):
        self.assertEqual(team.worktree_path("/root/", "abcdefgh12"), "/root/abcdefgh")

    def test_worktree_path_relative_rejected(self):
        with self.assertRaises(team.HarnessError):
            team.worktree_path("relative", "s1")

    def test_worktree_path_requires_session(self):
        with self.assertRaises(team.HarnessError):
            team.worktree_path("/root", "")

    def test_worktree_commands(self):
        cmds = team.worktree_commands("https://github.com/x/y", "/root", "sess1234", "fix bug")
        self.assertEqual(len(cmds), 3)
        self.assertIn("worktree add", cmds[1])
        self.assertIn("fetch", cmds[0])

    def test_worktree_requires_repo(self):
        with self.assertRaises(team.HarnessError):
            team.worktree_commands("", "/root", "s1", "t")

    def test_cleanup_commands(self):
        cmds = team.cleanup_commands("/root", "sess1234")
        self.assertIn("worktree remove", cmds[0])
        self.assertIn("prune", cmds[1])


if __name__ == "__main__":
    unittest.main()
