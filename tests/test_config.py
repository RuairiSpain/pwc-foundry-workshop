import unittest
from workshop_toolkit.config import WorkshopConfig, ConfigError, SUGGESTED_REGIONS

GUID = "11111111-2222-3333-4444-555555555555"


def make(**kw):
    base = dict(tenant_id=GUID, subscription_id=GUID, tenant_domain="contoso.onmicrosoft.com")
    base.update(kw)
    return WorkshopConfig(**base)


class TestValidation(unittest.TestCase):
    def test_valid_config_passes(self):
        cfg = make()
        self.assertIs(cfg.validate(), cfg)  # validate() returns self for chaining

    def test_bad_tenant_guid(self):
        with self.assertRaises(ConfigError) as e:
            make(tenant_id="nope").validate()
        self.assertIn("tenant_id", str(e.exception))

    def test_bad_subscription_guid(self):
        with self.assertRaises(ConfigError):
            make(subscription_id="123").validate()

    def test_bad_domain(self):
        with self.assertRaises(ConfigError):
            make(tenant_domain="notadomain").validate()

    def test_bad_resource_group(self):
        with self.assertRaises(ConfigError):
            make(resource_group="bad name!").validate()

    def test_bad_account_name(self):
        with self.assertRaises(ConfigError):
            make(foundry_account="a").validate()

    def test_attendee_count_bounds(self):
        with self.assertRaises(ConfigError):
            make(attendee_count=0).validate()
        with self.assertRaises(ConfigError):
            make(attendee_count=500).validate()

    def test_capacity_floor(self):
        with self.assertRaises(ConfigError):
            make(chat_capacity=5).validate()

    def test_suggested_regions_present(self):
        self.assertIn("swedencentral", SUGGESTED_REGIONS)


class TestDerived(unittest.TestCase):
    def test_account_scope(self):
        c = make()
        self.assertTrue(c.account_scope.startswith(f"/subscriptions/{GUID}"))
        self.assertIn("Microsoft.CognitiveServices/accounts", c.account_scope)

    def test_project_scope_nests_under_account(self):
        c = make()
        self.assertTrue(c.project_scope(3).startswith(c.account_scope))
        self.assertTrue(c.project_scope(3).endswith("proj-attendee-03"))

    def test_padding(self):
        self.assertEqual(WorkshopConfig.pad(7), "07")
        self.assertEqual(WorkshopConfig.pad(35), "35")

    def test_padding_rejects_zero(self):
        with self.assertRaises(ConfigError):
            WorkshopConfig.pad(0)

    def test_upn(self):
        self.assertEqual(make().upn(1), "attendee01@contoso.onmicrosoft.com")

    def test_indices_are_one_based(self):
        c = make(attendee_count=35)
        self.assertEqual(list(c.indices)[0], 1)
        self.assertEqual(list(c.indices)[-1], 35)
        self.assertEqual(len(list(c.indices)), 35)

    def test_as_dict(self):
        self.assertEqual(make().as_dict()["tenant_id"], GUID)


class TestFromEnv(unittest.TestCase):
    def test_reads_env(self):
        env = {
            "WS_TENANT_ID": GUID, "WS_SUBSCRIPTION_ID": GUID,
            "WS_TENANT_DOMAIN": "x.onmicrosoft.com",
            "WS_ATTENDEE_COUNT": "35", "WS_EXISTING_HUB": "true",
            "WS_LOCATION": "eastus2", "WS_CHAT_MODEL": "m", "WS_CHAT_CAPACITY": "50",
            "WS_RESOURCE_GROUP": "rg1", "WS_FOUNDRY_ACCOUNT": "acct1",
        }
        c = WorkshopConfig.from_env(env)
        self.assertEqual(c.attendee_count, 35)
        self.assertTrue(c.existing_hub)
        self.assertEqual(c.location, "eastus2")

    def test_missing_required(self):
        with self.assertRaises(ConfigError):
            WorkshopConfig.from_env({"WS_TENANT_ID": GUID})

    def test_existing_hub_false(self):
        env = {"WS_TENANT_ID": GUID, "WS_SUBSCRIPTION_ID": GUID,
               "WS_TENANT_DOMAIN": "x.onmicrosoft.com", "WS_EXISTING_HUB": "no"}
        self.assertFalse(WorkshopConfig.from_env(env).existing_hub)


if __name__ == "__main__":
    unittest.main()
