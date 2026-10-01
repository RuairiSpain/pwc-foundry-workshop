# Security notes

## Passwords are deliberately weak

`PwcAgents-2026-NN!` is predictable from the attendee number. That is **not** a
secure password for durable accounts.

Acceptable here because:
- a throwaway tenant, not production
- accounts have no access to anything but their own Foundry spoke
- the workshop lasts three days
- `99-teardown.sh` deletes every account afterwards

**Do not reuse this pattern.** If these identities will live in a tenant that
holds anything real, use `--force-change-password-next-sign-in true` and require
MFA instead.

## The roster file holds plaintext passwords

`.out/attendees.csv` is plaintext by necessity — you print it onto cards.
- It is in `.gitignore`. Never commit it.
- Delete it the moment the workshop ends: `rm .out/attendees.csv`
- `99-teardown.sh` removes it automatically.

## Least privilege is enforced, not assumed

Attendees get Reader on the hub and Foundry User on their own spoke only.
`40-verify.sh` step 7 actively tests that attendee01 has **no** data-plane rights
on attendee02's spoke, and `tests/test_rbac.py` tests the planner that produces
those assignments. If someone widens a scope, both fail.

## OBO limits blast radius

Agent 4's toolbox runs tool calls as the signed-in attendee rather than a shared
service identity. The agent therefore cannot do anything the attendee could not
do themselves. Prefer this wherever an agent touches data a human owns.

## Secrets

No secret is committed. `GITHUB_TOKEN` (Lab 4, GitHub harness) and the App
Insights connection string are set with `azd env set` and live in
`.azure/<env>/.env`, which is gitignored.

## After the workshop

```bash
cd infra && ./99-teardown.sh     # deletes the RG and all 35 identities
rm -f .out/attendees.csv
```
Tell attendees to delete their Codespaces at github.com/codespaces — storage
bills while a codespace exists, even stopped.
