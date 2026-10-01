# Runs once on each VM via Custom Script Extension. Installs everything the
# AI-103 labs need. Logs to C:\labsetup.log.
$ErrorActionPreference = "Continue"
Start-Transcript -Path C:\labsetup.log -Append

Write-Output "=== PwC lab VM setup starting $(Get-Date) ==="

# Server 2022 blocks browsing by default; the labs need a working browser.
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -PropertyType DWORD -Force | Out-Null
New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}" -Name "IsInstalled" -Value 0 -PropertyType DWORD -Force | Out-Null

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$tmp = "C:\labtmp"; New-Item -ItemType Directory -Force -Path $tmp | Out-Null

function Get-File($url, $out) {
  for ($i=1; $i -le 3; $i++) {
    try { Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing -TimeoutSec 300; return $true }
    catch { Write-Output "retry $i for $url : $_"; Start-Sleep 5 }
  }
  return $false
}

# --- Python 3.13 (labs state 3.14 is NOT supported) ---
Write-Output "--- Python 3.13"
if (Get-File "https://www.python.org/ftp/python/3.13.1/python-3.13.1-amd64.exe" "$tmp\python.exe") {
  Start-Process "$tmp\python.exe" -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1 Include_pip=1 Include_launcher=1" -Wait
}

# --- Git ---
Write-Output "--- Git"
if (Get-File "https://github.com/git-for-windows/git/releases/download/v2.47.1.windows.1/Git-2.47.1-64-bit.exe" "$tmp\git.exe") {
  Start-Process "$tmp\git.exe" -ArgumentList "/VERYSILENT /NORESTART /NOCANCEL /SP-" -Wait
}

# --- VS Code (system-wide) ---
Write-Output "--- VS Code"
if (Get-File "https://update.code.visualstudio.com/latest/win32-x64/stable" "$tmp\vscode.exe") {
  Start-Process "$tmp\vscode.exe" -ArgumentList "/VERYSILENT /NORESTART /MERGETASKS=!runcode,addcontextmenufiles,addcontextmenufolders,addtopath" -Wait
}

# --- Azure CLI ---
Write-Output "--- Azure CLI"
if (Get-File "https://aka.ms/installazurecliwindowsx64" "$tmp\azcli.msi") {
  Start-Process msiexec.exe -ArgumentList "/i `"$tmp\azcli.msi`" /quiet /norestart" -Wait
}

# --- azd ---
Write-Output "--- azd"
try { Invoke-RestMethod 'https://aka.ms/install-azd.ps1' | Invoke-Expression } catch { Write-Output "azd failed: $_" }

# --- Clone the lab repos so attendees don't spend session time on it ---
Write-Output "--- lab repos"
$git = "C:\Program Files\Git\bin\git.exe"
New-Item -ItemType Directory -Force -Path C:\Labs | Out-Null
if (Test-Path $git) {
  & $git clone --depth 1 https://github.com/MicrosoftLearning/mslearn-ai-agents.git C:\Labs\mslearn-ai-agents 2>&1 | Out-Null
}

# --- Workshop guide pages, opened automatically on first login ---
Write-Output "--- workshop guide"
$attendeeNumber = "NN"
if ($env:COMPUTERNAME -match '(\d{2})$') { $attendeeNumber = $Matches[1] }
$foundryProject = "proj-attendee-$attendeeNumber"
$foundryEndpoint = "https://fdy-pwc-agents-hub.services.ai.azure.com/api/projects/$foundryProject"
[Environment]::SetEnvironmentVariable("ATTENDEE_NUMBER", $attendeeNumber, "Machine")
[Environment]::SetEnvironmentVariable("FOUNDRY_PROJECT_NAME", $foundryProject, "Machine")
[Environment]::SetEnvironmentVariable("FOUNDRY_PROJECT_ENDPOINT", $foundryEndpoint, "Machine")

$guide = @'
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>PwC AI-103 Foundry Workshop</title>
<style>body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:#f5f7fb;color:#172033}header{background:linear-gradient(135deg,#1f3a8a,#7c3aed);color:white;padding:30px 44px}main{max-width:1120px;margin:auto;padding:28px}section{background:white;border-radius:16px;padding:22px 26px;margin:18px 0;box-shadow:0 4px 18px rgba(15,23,42,.08)}h1{margin:0}h2{color:#1f3a8a;margin-top:0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:16px}.card{border:1px solid #d8e0f0;border-radius:12px;padding:16px;background:#fbfdff}.warn{border-left:6px solid #f59e0b;background:#fff7ed}.ok{border-left:6px solid #10b981;background:#ecfdf5}code{background:#eef2ff;padding:2px 6px;border-radius:6px}pre{background:#111827;color:#e5e7eb;padding:14px;border-radius:10px;overflow-x:auto}table{border-collapse:collapse;width:100%}th,td{border-bottom:1px solid #e5e7eb;padding:10px;text-align:left;vertical-align:top}th{background:#eef2ff}a{color:#1d4ed8;font-weight:600}li{margin:6px 0}</style></head>
<body><header><h1>PwC AI-103 Foundry Workshop Guide</h1><p>Keep this page open during the workshop.</p></header><main>
<section class="grid"><div class="card"><h2>Your details</h2><p>Replace <code>NN</code> with your attendee number.</p><table><tr><th>Item</th><th>Value</th></tr><tr><td>Azure sign-in</td><td><code>attendeeNN@MngEnvMCAP063772.onmicrosoft.com</code></td></tr><tr><td>Entra password</td><td><code>PwcAgents-2026-NN!</code></td></tr><tr><td>VM</td><td><code>labvm-NN</code></td></tr><tr><td>Foundry project</td><td><code>proj-attendee-NN</code></td></tr><tr><td>Windows fallback</td><td><code>labuser</code> / instructor-provided password</td></tr></table></div><div class="card"><h2>Lab links</h2><ol><li><a href="https://microsoftlearning.github.io/mslearn-ai-agents/">Day 1 - Develop generative AI solutions in Azure</a></li><li><a href="https://microsoftlearning.github.io/mslearn-ai-agents/">Day 2 - Develop AI Agents in Azure</a></li><li><a href="pwc-lab-05-foundry-lifecycle.html">PwC Lab 5 - Foundry lifecycle, traces, KQL, evaluations</a></li></ol></div></section>
<section><h2>Architecture: hub and spokes</h2><div class="grid"><div class="card ok"><h3>Shared Foundry hub</h3><p>The instructor manages shared model deployments: <code>gpt-5.4-mini</code>, <code>gpt-5.4-nano</code>, <code>model-router</code>, and <code>text-embedding-3-small</code>.</p></div><div class="card ok"><h3>Your spoke project</h3><p>You build in <code>proj-attendee-NN</code>. You can create, edit, test, and delete your own agents.</p></div><div class="card warn"><h3>Model rule</h3><p>Do not deploy models in your spoke. Use the shared hub models already available to your project.</p></div></div></section>
<section><h2>Connect to your VM</h2><ol><li>Open <a href="https://portal.azure.com">portal.azure.com</a>.</li><li>Sign in as <code>attendeeNN@MngEnvMCAP063772.onmicrosoft.com</code>.</li><li>Open <b>Virtual machines</b> then <code>labvm-NN</code>.</li><li>Select <b>Connect</b> then <b>Bastion</b>.</li><li>Use <b>Microsoft Entra ID</b> if shown, otherwise use <code>labuser</code> and the instructor-provided VM password.</li></ol></section>
<section><h2>Open Foundry and sign in to CLI</h2><ol><li>Open <a href="https://ai.azure.com">ai.azure.com</a>.</li><li>Select <code>proj-attendee-NN</code>.</li><li>Open Terminal and run:</li></ol><pre>az login --use-device-code
azd auth login --use-device-code --tenant-id 79915ee0-594c-4201-8653-6ad77a909f4d
az account show --query user.name -o tsv
$env:FOUNDRY_PROJECT_ENDPOINT</pre></section>
<section><h2>Universal skip rules</h2><table><tr><th>If the lab says...</th><th>You do...</th></tr><tr><td>Create a Foundry project/resource</td><td>Skip. Use <code>proj-attendee-NN</code>.</td></tr><tr><td>Deploy a model</td><td>Skip. Use the shared hub model.</td></tr><tr><td>Create or delete a resource group</td><td>Skip.</td></tr><tr><td>Create AI Search or Storage</td><td>Use the instructor handout for shared resources.</td></tr><tr><td>Create Azure Bot Service or publish to Teams</td><td>Skip unless the instructor demonstrates it.</td></tr></table></section>
<section><h2>Exercise guidance</h2><div class="grid"><div class="card"><h3>Exercise 01</h3><p>Do agents, File Search, Code Interpreter, playground. Skip project/model creation and cleanup.</p></div><div class="card"><h3>Exercise 02</h3><p>Use your endpoint and <code>MODEL_DEPLOYMENT_NAME=gpt-5.4-mini</code>.</p></div><div class="card"><h3>Exercise 03</h3><p>Use MCP tools. Skip model deployment and quota changes.</p></div><div class="card"><h3>Exercise 04</h3><p>Use shared Search/Storage. Name your knowledge base <code>ks-contosoproducts-NN</code>.</p></div><div class="card"><h3>Exercises 05a/05b</h3><p>Skip unless instructor-led.</p></div><div class="card"><h3>Exercises 06-09</h3><p>Existing project, shared model, no cleanup of Azure resources.</p></div></div></section>
</main></body></html>
'@
$guide = $guide.Replace("attendeeNN", "attendee$attendeeNumber")
$guide = $guide.Replace("labvm-NN", "labvm-$attendeeNumber")
$guide = $guide.Replace("proj-attendee-NN", $foundryProject)
$guide = $guide.Replace("PwcAgents-2026-NN!", "PwcAgents-2026-$attendeeNumber!")
$guide | Out-File -FilePath "C:\Labs\pwc-workshop-guide.html" -Encoding UTF8 -Force

$lab5 = @'
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>PwC Lab 5 - Foundry lifecycle</title>
<style>body{margin:0;font-family:Segoe UI,Arial,sans-serif;background:#f8fafc;color:#172033}header{background:linear-gradient(135deg,#0f766e,#1d4ed8);color:white;padding:30px 44px}main{max-width:1080px;margin:auto;padding:28px}section{background:white;border-radius:14px;padding:22px 26px;margin:16px 0;box-shadow:0 3px 14px rgba(15,23,42,.08)}h2{color:#0f766e;margin-top:0}code{background:#ecfeff;padding:2px 6px;border-radius:6px}pre{background:#111827;color:#e5e7eb;padding:14px;border-radius:10px;overflow-x:auto}li{margin:7px 0}.note{border-left:6px solid #0ea5e9;background:#f0f9ff}.warn{border-left:6px solid #f59e0b;background:#fff7ed}a{color:#1d4ed8;font-weight:600}</style></head>
<body><header><h1>PwC Lab 5 - Publish, test, trace, query, evaluate</h1><p>Extra Foundry lifecycle features for the PwC workshop.</p></header><main>
<section class="note"><h2>Goal</h2><p>Use <code>pwc-knowledge-agent</code> to practise publishing, API calls, traces, Log Analytics/KQL, gateway concepts, and evaluations.</p></section>
<section><h2>1. Confirm project and agent</h2><pre>$env:FOUNDRY_PROJECT_ENDPOINT
az account show --query user.name -o tsv
azd ai agent list</pre></section>
<section><h2>2. Confirm the pre-deployed agent</h2><ol><li>The instructor pre-deployed four sample agents into your project.</li><li>Use <code>pwc-knowledge-agent</code> for this lab.</li><li>If you edit instructions in the portal, save a new version before testing again.</li></ol><p>Publishing from source with <code>azd deploy</code> is instructor-led for this locked-down workshop.</p></section>
<section><h2>3. Call the agent</h2><pre>$TOKEN = az account get-access-token --scope https://ai.azure.com/.default --query accessToken -o tsv
$ENDPOINT = "$env:FOUNDRY_PROJECT_ENDPOINT/agents/pwc-knowledge-agent/responses"
curl.exe -fsS $ENDPOINT -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"input":"What is the maximum hosted-agent idle timeout?","stream":false}'</pre></section>
<section><h2>4. Inspect traces</h2><ol><li>Open <a href="https://ai.azure.com">ai.azure.com</a>.</li><li>Select <code>proj-attendee-NN</code>.</li><li>Open <b>Tracing</b>.</li><li>Find your curl request and review tokens, tool calls, latency, model name, and correlation ID.</li></ol></section>
<section><h2>5. Query logs with KQL</h2><pre>search *
| where TimeGenerated > ago(1d)
| summarize Rows=count() by $table
| order by Rows desc</pre><pre>search *
| where TimeGenerated > ago(1d)
| where tostring(*) contains "proj-attendee-NN"
| take 100</pre></section>
<section class="warn"><h2>6. AI Gateway discussion</h2><p>Direct endpoints are simplest. Gateway endpoints add central policy, throttling, keys, and consumer reporting. Ask the instructor before changing gateway or API Management settings.</p></section>
<section><h2>7. Evaluate</h2><ol><li>Open <b>Evaluations</b>.</li><li>Create a small evaluation for your agent.</li><li>Review groundedness, relevance, coherence, and failed rows.</li><li>Change a prompt, deploy again, and compare.</li></ol></section>
<section><p><a href="pwc-workshop-guide.html">Back to main guide</a></p></section>
</main></body></html>
'@
$lab5 = $lab5.Replace("proj-attendee-NN", $foundryProject)
$lab5 = $lab5.Replace("attendeeNN", "attendee$attendeeNumber")
$lab5 | Out-File -FilePath "C:\Labs\pwc-lab-05-foundry-lifecycle.html" -Encoding UTF8 -Force

# --- First-logon script: VS Code extensions + azd Foundry extensions ---
# Extensions install per-user, so this must run when the attendee logs in.
$firstLogon = @'
$code = "C:\Program Files\Microsoft VS Code\bin\code.cmd"
$done = "$env:USERPROFILE\.labready"
if (Test-Path "C:\Labs\pwc-workshop-guide.html") {
  Start-Process "msedge.exe" "C:\Labs\pwc-workshop-guide.html"
}
if (Test-Path $done) { exit }
Write-Host "Preparing your lab environment - this takes about two minutes..." -ForegroundColor Cyan
& $code --install-extension ms-windows-ai-studio.windows-ai-studio --force
& $code --install-extension ms-azuretools.vscode-azureresourcegroups --force
& $code --install-extension ms-python.python --force
& $code --install-extension ms-python.vscode-pylance --force
& $code --install-extension redhat.vscode-yaml --force
try { azd ext install microsoft.foundry } catch { Write-Host "azd extension install failed - run: azd ext install microsoft.foundry" }
New-Item -ItemType File -Path $done -Force | Out-Null
Write-Host ""
Write-Host "READY. Your labs are in C:\Labs" -ForegroundColor Green
Write-Host "Sign in with:  az login --use-device-code" -ForegroundColor Green
Write-Host "Your Foundry project endpoint is already set in FOUNDRY_PROJECT_ENDPOINT." -ForegroundColor Green
Write-Host ""
pause
'@
$firstLogon | Out-File -FilePath "C:\ProgramData\lab-firstlogon.ps1" -Encoding UTF8 -Force

$startup = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"
New-Item -ItemType Directory -Force -Path $startup | Out-Null
@"
@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File C:\ProgramData\lab-firstlogon.ps1
"@ | Out-File -FilePath "$startup\lab-firstlogon.cmd" -Encoding ASCII -Force

# Desktop shortcut to the labs folder
$ws = New-Object -ComObject WScript.Shell
$sc = $ws.CreateShortcut("C:\Users\Public\Desktop\LABS.lnk")
$sc.TargetPath = "C:\Labs"; $sc.Save()
$sc = $ws.CreateShortcut("C:\Users\Public\Desktop\WORKSHOP GUIDE.lnk")
$sc.TargetPath = "C:\Labs\pwc-workshop-guide.html"; $sc.Save()

Write-Output "=== setup complete $(Get-Date) ==="
Stop-Transcript
