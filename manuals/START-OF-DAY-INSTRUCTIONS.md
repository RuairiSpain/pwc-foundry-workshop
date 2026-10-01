# PwC AI-103 Workshop - Start-of-day instructions

Hello everyone,

Today you will use a browser-based Windows VM and your own Microsoft Foundry project.

## Your assigned details

Replace `NN` with your attendee number.

| Item | Value |
|---|---|
| Azure sign-in | `attendeeNN@MngEnvMCAP063772.onmicrosoft.com` |
| Entra password | `PwcAgents-2026-NN!` |
| VM name | `labvm-NN` |
| Foundry project | `proj-attendee-NN` |
| Windows username fallback | `labuser` |
| Windows password fallback | Provided by instructor |

## Open your VM desktop

1. Open <https://portal.azure.com>.
2. Sign in as `attendeeNN@MngEnvMCAP063772.onmicrosoft.com`.
3. Search for **Virtual machines**.
4. Open `labvm-NN`.
5. Select **Connect**.
6. Select **Bastion**.
7. Choose **Microsoft Entra ID** sign-in if shown.
8. If that option is not shown, use `labuser` and the instructor-provided VM password.
9. Wait for the Windows desktop to open in your browser.

Do not start, stop, resize, or delete VMs. The instructor manages power state.

## Open the guide

The workshop guide should open automatically in Microsoft Edge.

If it does not, open:

`C:\Labs\pwc-workshop-guide.html`

## Open Foundry

1. Go to <https://ai.azure.com>.
2. Sign in as `attendeeNN@MngEnvMCAP063772.onmicrosoft.com`.
3. Select `proj-attendee-NN`.

Only work inside your own project.

## Sign in to Azure CLI

Open a terminal in the VM and run:

```bash
az login --use-device-code
azd auth login --use-device-code --tenant-id 79915ee0-594c-4201-8653-6ad77a909f4d
az account show --query user.name -o tsv
$env:FOUNDRY_PROJECT_ENDPOINT
```

## AI-103 lab links

1. Day 1 - Develop generative AI solutions in Azure:  
   <https://microsoftlearning.github.io/mslearn-ai-agents/>

2. Day 2 - Develop AI Agents in Azure:  
   <https://microsoftlearning.github.io/mslearn-ai-agents/>

## Rules for every lab

1. Use your existing project: `proj-attendee-NN`.
2. Do not create a new Foundry project or resource.
3. Do not deploy a model.
4. Do not create or delete resource groups.
5. Do not use another attendee's project.
6. Use the shared hub models already available in your project.

If the portal asks you to deploy a model, stop and ask the instructor.
