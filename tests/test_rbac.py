import unittest
from workshop_toolkit.config import WorkshopConfig
from workshop_toolkit.identity import build_attendees
from workshop_toolkit.rbac import (
    DATA_PLANE_ROLES, ROLE_IDS, RoleAssignment, capability_matrix,
    cross_spoke_leakage, plan_all, plan_for_attendee,
    plan_for_project_identity, plan_for_shared_demo_access,
)

GUID = "11111111-2222-3333-4444-555555555555"
CFG = WorkshopConfig(tenant_id=GUID, subscription_id=GUID,
                     tenant_domain="contoso.onmicrosoft.com", attendee_count=5)
ROSTER = build_attendees(CFG)


class TestRoleIds(unittest.TestCase):
    def test_ids_are_guids(self):
        for name, rid in ROLE_IDS.items():
            self.assertRegex(rid, r"^[0-9a-f-]{36}$", name)

    def test_ids_are_unique(self):
        self.assertEqual(len(set(ROLE_IDS.values())), len(ROLE_IDS))

    def test_expected_roles_present(self):
        for r in ("Foundry User", "Foundry Project Manager", "Foundry Agent Consumer",
                  "Reader", "Cognitive Services OpenAI User", "AcrPush",
                  "Monitoring Reader", "Log Analytics Reader"):
            self.assertIn(r, ROLE_IDS)

    def test_data_plane_set(self):
        self.assertIn("Foundry Project Manager", DATA_PLANE_ROLES)
        self.assertNotIn("Reader", DATA_PLANE_ROLES)


class TestAttendeePlan(unittest.TestCase):
    def setUp(self):
        self.plan = plan_for_attendee(CFG, ROSTER[0])
        self.by_role = {p.role_name: p for p in self.plan}

    def test_seven_assignments(self):
        self.assertEqual(len(self.plan), 7)

    def test_reader_is_at_hub_scope(self):
        """Without this, the model dropdown is empty in the portal."""
        self.assertEqual(self.by_role["Reader"].scope, CFG.account_scope)

    def test_project_manager_not_foundry_user(self):
        """Foundry User cannot create connections; every lab needs them."""
        self.assertIn("Foundry Project Manager", self.by_role)
        self.assertNotIn("Foundry User", self.by_role)

    def test_project_manager_is_own_spoke_only(self):
        self.assertEqual(self.by_role["Foundry Project Manager"].scope,
                         ROSTER[0].project_scope)

    def test_can_read_traces(self):
        """Foundry User sees metrics but NOT traces - Lab 5 needs this."""
        self.assertIn("Monitoring Reader", self.by_role)
        self.assertIn("Microsoft.Insights/components", self.by_role["Monitoring Reader"].scope)

    def test_can_run_kql(self):
        self.assertIn("Log Analytics Reader", self.by_role)
        self.assertIn("OperationalInsights/workspaces",
                      self.by_role["Log Analytics Reader"].scope)

    def test_can_push_images(self):
        self.assertIn("AcrPush", self.by_role)

    def test_openai_user_at_hub_for_embeddings(self):
        self.assertEqual(self.by_role["Cognitive Services OpenAI User"].scope,
                         CFG.account_scope)

    def test_quota_at_subscription_scope(self):
        self.assertTrue(self.by_role["Cognitive Services Usages Reader"]
                        .scope.endswith(CFG.subscription_id))

    def test_every_assignment_has_a_reason(self):
        for ra in self.plan:
            self.assertTrue(ra.reason and len(ra.reason) > 20)

    def test_all_are_user_principals(self):
        for ra in self.plan:
            self.assertEqual(ra.principal_type, "User")


class TestProjectIdentityPlan(unittest.TestCase):
    def setUp(self):
        self.plan = plan_for_project_identity(CFG, 1)
        self.by_role = {p.role_name: p for p in self.plan}

    def test_three_assignments(self):
        self.assertEqual(len(self.plan), 3)

    def test_foundry_user_at_hub(self):
        """Project MI proxies inference to the hub's shared deployments."""
        self.assertEqual(self.by_role["Foundry User"].scope, CFG.account_scope)

    def test_acr_pull_not_push(self):
        self.assertIn("AcrPull", self.by_role)
        self.assertNotIn("AcrPush", self.by_role)

    def test_all_service_principals(self):
        for ra in self.plan:
            self.assertEqual(ra.principal_type, "ServicePrincipal")


class TestDemoAccess(unittest.TestCase):
    def test_agent_consumer_only(self):
        plan = plan_for_shared_demo_access(CFG, ROSTER[0], "proj-instructor-demo")
        self.assertEqual(len(plan), 1)
        self.assertEqual(plan[0].role_name, "Foundry Agent Consumer")

    def test_scoped_to_demo_project(self):
        plan = plan_for_shared_demo_access(CFG, ROSTER[0], "proj-instructor-demo")
        self.assertTrue(plan[0].scope.endswith("proj-instructor-demo"))

    def test_consumer_is_not_data_plane_builder(self):
        """Agent Consumer must not appear in the leakage-triggering set."""
        self.assertNotIn("Foundry Agent Consumer", DATA_PLANE_ROLES)


class TestPlanAll(unittest.TestCase):
    def test_scales(self):
        plan = plan_all(CFG, ROSTER)
        self.assertEqual(len(plan), 5 * 7 + 5 * 3)

    def test_cli_uses_role_guid_not_name(self):
        ra = plan_for_attendee(CFG, ROSTER[0])[0]
        cli = ra.to_az_cli()
        self.assertIn(ra.role_id, cli)
        self.assertNotIn('--role "Reader"', cli)

    def test_cli_sets_principal_type(self):
        sp = plan_for_project_identity(CFG, 1)[0]
        self.assertIn("--assignee-principal-type ServicePrincipal", sp.to_az_cli())

    def test_cli_accepts_custom_var(self):
        self.assertIn("$MYOID", plan_for_attendee(CFG, ROSTER[0])[0].to_az_cli("$MYOID"))


class TestIsolation(unittest.TestCase):
    def test_clean_plan_has_no_leakage(self):
        self.assertEqual(cross_spoke_leakage(plan_all(CFG, ROSTER), ROSTER), [])

    def test_detects_cross_spoke_grant(self):
        bad = RoleAssignment(ROSTER[0].upn, "Foundry Project Manager",
                             ROLE_IDS["Foundry Project Manager"],
                             ROSTER[1].project_scope, "oops")
        problems = cross_spoke_leakage([bad], ROSTER)
        self.assertEqual(len(problems), 1)
        self.assertIn("outside their own spoke", problems[0])

    def test_hub_scoped_data_role_is_a_leak(self):
        """Foundry User at hub scope inherits to all 35 spokes."""
        bad = RoleAssignment(ROSTER[0].upn, "Foundry User",
                             ROLE_IDS["Foundry User"], CFG.account_scope, "oops")
        self.assertTrue(cross_spoke_leakage([bad], ROSTER))

    def test_detects_unknown_principal(self):
        bad = RoleAssignment("ghost@x.com", "Foundry Owner",
                             ROLE_IDS["Foundry Owner"], "/scope", "oops")
        self.assertIn("not on the roster", cross_spoke_leakage([bad], ROSTER)[0])

    def test_project_identity_at_hub_is_exempt(self):
        """Project MIs legitimately hold Foundry User at hub scope."""
        sp = plan_for_project_identity(CFG, 1)
        self.assertEqual(cross_spoke_leakage(sp, ROSTER), [])

    def test_reader_at_hub_is_not_flagged(self):
        ok = RoleAssignment(ROSTER[0].upn, "Reader", ROLE_IDS["Reader"],
                            CFG.account_scope, "fine")
        self.assertEqual(cross_spoke_leakage([ok], ROSTER), [])

    def test_agent_consumer_on_demo_is_not_flagged(self):
        plan = plan_for_shared_demo_access(CFG, ROSTER[0], "demo")
        self.assertEqual(cross_spoke_leakage(plan, ROSTER), [])


class TestCapabilityMatrix(unittest.TestCase):
    def test_shape(self):
        for row in capability_matrix():
            self.assertEqual(len(row), 3)

    def test_documents_the_deliberate_gap(self):
        caps = {r[0]: r[1] for r in capability_matrix()}
        self.assertIn("NOT granted", caps["Read a sibling's agents or data"])

    def test_covers_every_lab_need(self):
        caps = " ".join(r[0] for r in capability_matrix())
        for need in ("shared models", "connections", "traces", "KQL"):
            self.assertIn(need, caps)


if __name__ == "__main__":
    unittest.main()
