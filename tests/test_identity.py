import unittest
from workshop_toolkit.config import WorkshopConfig, ConfigError
from workshop_toolkit.identity import (
    Attendee, PASSWORD_PREFIX, build_attendees, duplicate_upns,
    generate_password, is_valid_password, roster_to_csv,
)

GUID = "11111111-2222-3333-4444-555555555555"
CFG = WorkshopConfig(tenant_id=GUID, subscription_id=GUID,
                     tenant_domain="contoso.onmicrosoft.com", attendee_count=35)


class TestPassword(unittest.TestCase):
    def test_shape(self):
        for i in range(1, 36):
            pw = generate_password(i)
            self.assertTrue(pw.startswith(PASSWORD_PREFIX))
            self.assertEqual(len(pw), len(PASSWORD_PREFIX) + 3)
            self.assertTrue(pw[len(PASSWORD_PREFIX):len(PASSWORD_PREFIX) + 2].isdigit())
            self.assertTrue(pw.endswith("!"))

    def test_validator_accepts_generated(self):
        self.assertTrue(is_valid_password(generate_password(7)))

    def test_validator_rejects(self):
        self.assertFalse(is_valid_password("hunter2"))
        self.assertFalse(is_valid_password(PASSWORD_PREFIX + "12"))
        self.assertFalse(is_valid_password(PASSWORD_PREFIX + "abcd"))
        self.assertFalse(is_valid_password(PASSWORD_PREFIX + "12345"))
        self.assertFalse(is_valid_password(PASSWORD_PREFIX + "07"))
        self.assertFalse(is_valid_password(PASSWORD_PREFIX + "7!"))

    def test_deterministic_by_attendee_number(self):
        self.assertEqual(generate_password(1), "PwcAgents-2026-01!")
        self.assertEqual(generate_password(35), "PwcAgents-2026-35!")

    def test_rejects_zero_index(self):
        with self.assertRaises(ConfigError):
            generate_password(0)


class TestRoster(unittest.TestCase):
    def setUp(self):
        self.roster = build_attendees(CFG)

    def test_count_is_35(self):
        self.assertEqual(len(self.roster), 35)

    def test_no_duplicate_upns(self):
        self.assertEqual(duplicate_upns(self.roster), [])

    def test_duplicate_detection_works(self):
        dupe = self.roster + [self.roster[0]]
        self.assertEqual(duplicate_upns(dupe), [self.roster[0].upn])

    def test_every_password_valid(self):
        self.assertTrue(all(is_valid_password(a.password) for a in self.roster))
        self.assertEqual(self.roster[6].password, "PwcAgents-2026-07!")

    def test_each_has_own_project(self):
        self.assertEqual(len({a.project_name for a in self.roster}), 35)

    def test_number_property(self):
        self.assertEqual(self.roster[0].number, "01")
        self.assertEqual(self.roster[-1].number, "35")

    def test_scope_matches_project(self):
        a = self.roster[4]
        self.assertTrue(a.project_scope.endswith(a.project_name))


class TestCsv(unittest.TestCase):
    def test_header_and_rows(self):
        csv_text = roster_to_csv(build_attendees(CFG))
        lines = csv_text.strip().split("\n")
        self.assertEqual(lines[0], "number,display_name,upn,password,project")
        self.assertEqual(len(lines), 36)

    def test_empty_roster_rejected(self):
        with self.assertRaises(ConfigError):
            roster_to_csv([])


if __name__ == "__main__":
    unittest.main()
