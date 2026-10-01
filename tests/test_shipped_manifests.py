"""Every azure.yaml we ship must pass our own validator."""
import pathlib
import unittest
from workshop_toolkit import manifest

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFESTS = sorted((ROOT / "agents").glob("*/azure.yaml"))


class TestShippedManifests(unittest.TestCase):
    def test_we_ship_four_agents(self):
        self.assertEqual(len(MANIFESTS), 4)

    def test_each_manifest_is_valid(self):
        for path in MANIFESTS:
            with self.subTest(manifest=path.parent.name):
                doc = manifest.load(path.read_text())
                self.assertEqual(manifest.validate(doc), [], f"{path} failed validation")

    def test_each_declares_an_idle_timeout(self):
        """The whole point of the teaching knob - none may rely on the default."""
        for path in MANIFESTS:
            doc = manifest.load(path.read_text())
            agents = [s for s in doc["services"].values()
                      if (s or {}).get("host") == "azure.ai.agent"]
            for a in agents:
                if a.get("kind") == "prompt":
                    continue  # prompt agents have no session sandbox
                with self.subTest(manifest=path.parent.name):
                    self.assertIn("sessionConfiguration", a)
                    manifest.validate_idle_timeout(
                        a["sessionConfiguration"]["idleTimeoutSeconds"])

    def test_no_agent_declares_the_injected_endpoint_in_env(self):
        """FOUNDRY_PROJECT_ENDPOINT is platform-injected; declaring it breaks deploys."""
        for path in MANIFESTS:
            doc = manifest.load(path.read_text())
            for name, svc in doc["services"].items():
                env = ((svc or {}).get("env") or {})
                with self.subTest(manifest=path.parent.name, service=name):
                    self.assertNotIn("FOUNDRY_PROJECT_ENDPOINT", env)

    def test_agent_names_are_unique_across_the_workshop(self):
        """Spoke projects are separate, but duplicate names confuse the class."""
        names = []
        for path in MANIFESTS:
            names.extend(manifest.agent_names(manifest.load(path.read_text())))
        self.assertEqual(len(names), len(set(names)), f"duplicate agent names: {names}")


if __name__ == "__main__":
    unittest.main()
