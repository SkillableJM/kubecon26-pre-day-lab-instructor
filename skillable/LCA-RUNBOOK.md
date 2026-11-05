# KubeCon CTF lab: life cycle action (LCA) runbook

How the Skillable life cycle actions (LCAs) build each attendee's environment for the KubeCon AKS
capture-the-flag lab, and how to add, test, and troubleshoot them. Modeled on the LAB723 (Ignite 2026)
LCAs, but much shorter: the LCAs run the lab repository's own tested deployment scripts.

## Files

The scripts are in the lab repository, in
[`skillable/lca`](https://github.com/bbenz/kubecon26-pre-day-lab/tree/main/skillable/lca), and the VM image has a
clone of it in `C:\LabFiles\kubecon26-pre-day-lab`.

| File | Where it goes | Purpose |
| --- | --- | --- |
| [`prepare-lab-environment.ps1`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/lca/prepare-lab-environment.ps1) | Pasted into the **prepare** LCA (First Displayable) | 247 lines, about 180 of them code. Moves the VM's clone of the lab repository to `RepoRef`, saves the settings and the cloud subscription's service principal, and starts the worker as SYSTEM. Waits for it, and reports the result. Has the pool's secure tokens, commented out until a pool admin turns them on. |
| [`readiness-gate.ps1`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/lca/readiness-gate.ps1) | Pasted into the **readiness gate** LCA (Running Preinstance Assigned To User) | 44 lines. Runs the readiness gate, and removes the service principal from the VM before the attendee gets it, even if the prepare LCA stopped early. No secure tokens. |
| [`Invoke-CtfLabSetup.ps1`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/lca/Invoke-CtfLabSetup.ps1) | Stays in the lab repository on the VM. Both LCAs run it from there. | The worker, in PowerShell 7. Keeps only the checked-out commit in the clone, deploys the begin state with the clone's [`begin-challenge/azure-cli-powershell/deploy.ps1`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/azure-cli-powershell/deploy.ps1), gives the portal user its roles, sets up the lab user, and runs the readiness gate. |
| [`manual-test-access.ps1`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/lca/manual-test-access.ps1) | Pasted into a cloud platform LCA, **test profiles only** | Gives the cloud portal user Owner on the resource group and registers the resource providers, so you can build the begin state by hand. |
| [`manual-begin-state-bootstrap.txt`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/lca/manual-begin-state-bootstrap.txt) | Pasted into PowerShell in a lab VM | The prepare LCA with `Manual = $true`, compressed: builds the begin state by hand, as you. See [Build the begin state by hand](#build-the-begin-state-by-hand). |
| [`make-bootstraps.ps1`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/make-bootstraps.ps1) | Your computer | Regenerates the bootstraps after you change `prepare-lab-environment.ps1` or the VM image script. |
| [`leaderboard/skillable/lca-windows.ps1`](../leaderboard/skillable/lca-windows.ps1) (this repository) | Optional third LCA | Registers the VM with the event leaderboard. `leaderboard/setup.ps1` generates the real script, with its token; see [The event leaderboard](#the-event-leaderboard-optional). |

## Why the prepare LCA is short

Skillable asked for LAB723's 3,416-line prepare LCA to be reduced. This lab's is 247 lines, mostly comments and
the settings block, because it doesn't embed the deployment:

- The VM image has a shallow clone of the lab repository, the folder that attendees work in. The LCA moves it to
  `RepoRef`, a branch or tag of <https://github.com/bbenz/kubecon26-pre-day-lab>, so a reviewer can read exactly
  what runs at that tag.
- The **worker** (`Invoke-CtfLabSetup.ps1`, about 650 lines) and the deployment it calls (`deploy.ps1` and
  `shared/azure-cli-powershell`) are the same scripts that the lab repository's deployment approaches are tested
  with, that people run by hand, and that attendees run to reset a challenge.
- The LCA downloads nothing else. The worker installs the `k8s-extension` Azure CLI extension (when
  `InspektorGadget` is on), and the cluster pulls the challenge images from public registries.

## Identities

| Identity | Replacement tokens | Use |
| --- | --- | --- |
| Cloud subscription service principal | `@lab.CloudSubscription.TenantId`, `.Id`, `.AppId`, and `.AppSecret`: the pool's secure tokens, only in the prepare LCA's **CLOUD CREDENTIALS** section, which a pool admin turns on | The worker signs in with it in its own Azure CLI profile (`C:\ProgramData\kubecon-ctf-lca\azure-cli`), and deploys as it. The readiness gate LCA deletes that profile, and clears the PowerShell event logs. The attendee never gets it. |
| Cloud portal user (`User1`) | `@lab.CloudPortalCredential(User1).Username`. The lab's **Resources** tab shows its password and Temporary Access Pass. | The attendee's Azure portal sign-in, and their own `az login`, which `kubectl`, the scoring scripts, the reset command, and AKS-MCP use. Scripts never sign in as this user: Azure's mandatory multifactor authentication applies to users who change resources from the Azure CLI, and a script can't complete it. |

The service principal needs no Microsoft Graph permission. The deployment reads its own object ID from its
access token, and the worker finds the portal user's object ID from the role that Skillable gives the
portal user on the resource group, when the service principal can't look the user up by name.

### The pool's secure tokens

Skillable lets only an admin of the cloud subscription pool save a script that has the pool's secure tokens.
So the prepare LCA has the four tokens in its **CLOUD CREDENTIALS** section, turned off:

1. **You save the prepare LCA as it is.** The four lines are commented out, with a space after each `@`
   (`# ClientSecret   = '@ lab.CloudSubscription.AppSecret'`), so Skillable doesn't treat them as tokens.
   Until a pool admin turns them on, the LCA stops at once with
   `KubeCon CTF prepare can't start: the CLOUD CREDENTIALS section at the top of this script is still commented out`.
2. **A pool admin turns them on**: in those four lines only, they delete the `#` and the space after each `@`, and save.
3. **The prepare LCA** writes the credentials to `C:\ProgramData\kubecon-ctf-lca\config.json` (only SYSTEM and
   administrators can open the folder). The worker reads the secret, removes it from the file, and signs in.
4. **The readiness gate LCA**, the last one before the attendee gets the VM, deletes the worker's Azure CLI
   profile and clears the PowerShell event logs (Windows PowerShell logs the text of scripts that it considers
   suspicious, event 4104, with the token values that Skillable substituted), even if the gate fails.

Once a pool admin saves the LCA with the tokens, only a pool admin can save it again, so change `RepoRef` and
the other settings first. Because the logic is in the repository, most fixes don't need a new LCA: tag a new
release, and ask the pool admin to change only `RepoRef`.

**Request for the pool admin** (for example, SkillableEventSupport in a GitHub issue):

> The KubeCon CTF lab deploys each lab's Azure resources from one VM life cycle action, **KubeCon CTF prepare**
> (First Displayable). It signs in as the cloud subscription's service principal. I can't save a script with
> the pool's secure tokens, so they're in the script's **CLOUD CREDENTIALS** section, near the top, commented
> out. Could you open that LCA's script and, in that section's four lines only: (1) delete the `#` at the start
> of each line, (2) delete the space after the `@` in each line, and (3) save the script? The service principal
> signs in only in the worker's own Azure CLI profile, never the attendee's, and my readiness gate LCA deletes
> that profile and clears the VM's PowerShell event logs before the attendee gets the VM.

### Identities and roles

| Identity | Roles |
| --- | --- |
| Cloud subscription service principal | Owner of the lab's subscription (Skillable); **Azure Kubernetes Service RBAC Cluster Admin** on the resource group, which `deploy.ps1` assigns |
| Portal user (`User1`) | The role in the resource group's **Permissions** (Contributor, which Skillable implements as LOD Contributor); **Azure Kubernetes Service RBAC Cluster Admin** and **Monitoring Data Reader** on the resource group; **Managed Identity Contributor** on `id-ctf-config-reader` (A4). The worker assigns them. AKS Automatic turns off local accounts, and Owner or Contributor doesn't give Kubernetes access. [Participant permissions](../docs/participant-permissions.md) has what each challenge needs. |
| `id-ctf-ai-service` (C4) | Cognitive Services OpenAI User on the Foundry account |
| `id-ctf-config-reader` (A4) | Key Vault Secrets User on the `lab-config` secret |

## What the prepare LCA does

| Step | Result |
| --- | --- |
| Repository | In the LCA, as SYSTEM: `git fetch --depth 1` of `RepoRef` from `RepoUrl` into the clone in `LabRoot`, and a checkout of it as the branch `lab`, which discards any local changes. If the fetch fails, the image's commit is used, and the result says so. If `LabRoot` has no clone, a shallow `git clone`; the LCA fails if that fails. The commit is in the logs. |
| Start | Writes `config.json` (only SYSTEM and administrators can open `C:\ProgramData\kubecon-ctf-lca`), and starts the worker from the clone in the **KubeCon CTF LCA worker** scheduled task, as SYSTEM, with a 3-hour limit. A retry of the LCA waits for the running worker instead of starting another. A run with the same settings and commit after a successful run does nothing else. |
| Lab repository | Keeps only the checked-out commit: deletes every other branch, tag, and remote-tracking reference, expires the reflog, and runs `git gc`, so the clone has no history to look through. Only on a shallow clone, so it never touches a developer's full clone. Warning only. |
| Azure sign-in | The service principal, in the worker's own Azure CLI profile, with retries for up to 5 minutes |
| Resource group | Reads the resource group's region. The lab's resources go there, unless `Location` is set. C4's Foundry account goes to westus3 instead when that region doesn't offer the model. |
| Resource providers | Registers missing providers, and waits up to 10 minutes: ContainerService, Compute, Network, ManagedIdentity, PolicyInsights, CognitiveServices, KeyVault, Monitor, Insights, OperationalInsights, AlertsManagement, Dashboard, Storage, KubernetesConfiguration. Warning only. |
| Begin state | Runs the clone's `deploy.ps1 -ResourceGroup <rg> -Location <region> -ClusterName aks-kubecon-ctf -Challenges <list>`: Azure Monitor and Log Analytics workspaces, the AKS Automatic cluster with the application routing add-on (managed NGINX and Gateway API), Managed Prometheus, the C4 Foundry account and model deployment, the A4 Key Vault and identity, and each challenge with its seeded fault. It renders the manifests in the clone's `.lab\rendered\<resource group>`. Its output is in the log. Required: the LCA fails if it fails. |
| Portal user access | The portal user's roles (see [Identities and roles](#identities-and-roles)). Warning only; the readiness gate fails without the cluster role. |
| Attendee Azure CLI | The lab user's Azure CLI: browser sign-in (`core.enable_broker_on_windows=false`), so `az login` reuses the attendee's portal session in Edge; no subscription prompt, telemetry, or survey. Removes a service principal sign-in if one is there. The attendee isn't signed in. |
| Inspektor Gadget | Only with `InspektorGadget = $true` (off by default): the `microsoft.inspektorgadget` AKS cluster extension (preview), without waiting for it to finish, and up to 4 minutes for a ready `gadget` pod. On AKS Automatic, its DaemonSet never reports every pod ready: an AKS policy (`aks-managed-restrict-hosted-vm-node-pinning`) denies its pods on the AKS-managed hosted system nodes, and a full node leaves its pod (200m CPU, 400 MiB) Pending, so the extension can stay in **Creating**. Pods on the lab's other nodes work, which is what A1's optional DNS tracing needs. Warning only. |
| Readiness gate | See [Readiness gate checks](#readiness-gate-checks). |

`deploy.ps1` writes the lab user's kubeconfig (`C:\Users\<lab user>\.kube\config`): one context,
`aks-kubecon-ctf`, converted with `kubelogin convert-kubeconfig -l azurecli --tenant-id`, so `kubectl` uses
whoever is signed in to the Azure CLI. The worker uses it with the service principal's profile, and the attendee
with theirs.

The attendee's reset command runs the same `deploy.ps1` for one challenge, as the attendee. It takes the region
from the existing resource group, and never re-creates the resource group, so Skillable's resource group and its
tags stay as they are.

### Logs and results

- `C:\ProgramData\kubecon-ctf-lca\prepare-<time>.log` and `verify-<time>.log`: everything, including
  `deploy.ps1`'s output. `state-prepare.json` and `state-verify.json` have the steps and checks.
- A copy of each log, ending with a summary, in the lab repository's `.lab\skillable` folder
  (`begin-state-<time>.log`, `readiness-gate-<time>.log`), where a proctor can open it in VS Code. Git ignores
  `.lab`.

| Result | When | What Skillable sees |
| --- | --- | --- |
| Succeeded | Every step finished, and every readiness check passed (warning checks can warn) | Success: `KubeCon CTF lab is ready.` |
| Incomplete | A step warned, or a check failed while `GateFailsPrepare` is `$false` | Success, with `KubeCon CTF prepare finished, but the environment isn't complete.` A retry repeats every step. |
| Failed | A required step failed, or a check failed while `GateFailsPrepare` is `$true` | Failure. Skillable retries the LCA, then applies the error action. |

Each result ends with `Summary for troubleshooting: <the log's copy in .lab\skillable>` and the total elapsed time.

## Before you start

- **Lab VM image:** built with the current
  [`kubecon-ctf-vm-image-setup.ps1`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/vm-image/kubecon-ctf-vm-image-setup.ps1)
  ([VM image runbook](VM-IMAGE-RUNBOOK.md)). Automatic sign-in and the Skillable integration service must work.
  Size: 4 vCPUs and 16 GiB (D4s_v5 class), the lab design's VM.
- **Cloud resources in the profile:** a cloud subscription pool; a resource group, `ResourceGroup1`, with
  **Override Region** set to the event's region (`westus3` is the tested default), where AKS Automatic is generally
  available and the C4 model is offered as Global Standard; and a cloud portal user, `User1`, with the Contributor
  role in the resource group's **Permissions**. No cloud resource template: the LCA deploys the resources. Without
  an Override Region, a launch can land in a region that offers no OpenAI models, as westcentralus did: `deploy.ps1`
  then creates the Foundry account in westus3, which the ACP must allow ([Regions](AZURE-RESOURCES.md#regions)).
- **Access control policy (ACP):** allow everything in [What the Skillable access control policy must allow](AZURE-RESOURCES.md),
  which has a message for Skillable. A resource scrape misses part of it, notably the role assignments
  (`Microsoft.Authorization/roleAssignments`): the prepare LCA's first one, Azure Kubernetes Service RBAC Cluster Admin
  for the service principal, is where the first Skillable launch stopped. Also: what AKS creates in the node resource
  group (individual VMs and their extensions, network interfaces, and disks, a NAT gateway, load balancers, public IP
  addresses, and managed identities), Azure Monitor's `MA_..._managed` resource group, child resources such as
  federated identity credentials, the Foundry model deployment, and the Key Vault secret, and the D-family VM sizes
  that node autoprovisioning picks.
- **Quota in each lab subscription and region:** about 16 to 24 D-family vCPUs (two to four NAP nodes) and
  50,000 tokens per minute of `gpt-6-luna` (`2026-09-22`) Global Standard for C4, in the Foundry account's region.
  Without the model quota, the begin state fails at C4: confirm it with Skillable, or leave `c4` out of `Challenges`.
- **Preinstances:** the begin state takes 20 to 30 minutes (20 in testing, 18 of them in `deploy.ps1`), so use
  running preinstances with at least 45 minutes of lead time, plus spares.
- **GitHub Copilot:** attendees sign in to GitHub in VS Code with an account that has a Copilot seat. If the
  seats come from a GitHub organization or enterprise (Copilot Business or Enterprise), an owner must turn on the
  **MCP servers in Copilot** policy, which is off by default: in the organization's **Settings** > **Copilot** >
  **Policies**, set **MCP servers in Copilot** to **Enabled** (for an enterprise: **AI controls** > **MCP**).
  Without it, Copilot can't use the AKS-MCP server that the image configures. Copilot Free and Pro accounts
  don't have the policy.

## Add the LCAs in Skillable

In Skillable Studio, edit the lab profile, and select **Life Cycle Actions**.

| Setting | Prepare | Readiness gate | Manual test access (test profiles only) |
| --- | --- | --- | --- |
| Name | KubeCon CTF prepare | KubeCon CTF readiness gate | KubeCon CTF manual test access |
| Action | Execute Script in Virtual Machine | Execute Script in Virtual Machine | Execute Script in Cloud Platform |
| Language | PowerShell | PowerShell | PowerShell |
| Event | First Displayable | Running Preinstance Assigned To User | Post-Build |
| Blocking | Yes | Yes | No |
| Delay | 60 seconds | 0 | 0 |
| Timeout | 60 minutes | 20 minutes | 10 minutes |
| Retries | 2 | 0 | 0 |
| Error action | End Lab (event) or Log (testing) | Notify user ("Your lab environment isn't ready. Ask a proctor for another lab.") | Log |
| Script | `prepare-lab-environment.ps1`, whole file | `readiness-gate.ps1`, whole file | `manual-test-access.ps1`, whole file |

Paste the scripts from the `.ps1` files, not from a document or chat: they're ASCII only, and a copy that turns
quotes into curly quotes makes Skillable report unsupported characters. In each script, change `ResourceGroup1`
and `User1` if the profile uses other names.

## Settings

The settings block near the top of `prepare-lab-environment.ps1`:

| Setting | Default | Meaning |
| --- | --- | --- |
| `ResourceGroup`, `PortalUser` | `@lab.CloudResourceGroup(ResourceGroup1).Name`, `@lab.CloudPortalCredential(User1).Username` | Skillable replaces them |
| `Location` | Empty | Empty uses the resource group's region. Set the resource group's **Override Region** instead, where possible. |
| `ClusterName` | `aks-kubecon-ctf` | Also the kubectl context name. The lab instructions' reset command uses it. |
| `Challenges` | `all` | Or a list, such as `c1,c2,c3,c4` |
| `InspektorGadget` | `$false` | `$true` adds the Inspektor Gadget AKS cluster extension (preview), for A1's optional DNS tracing. See **Inspektor Gadget** in [What the prepare LCA does](#what-the-prepare-lca-does) for its limits on AKS Automatic. Attendees can also deploy it themselves, or through AKS-MCP. |
| `RepoUrl`, `RepoRef` | `https://github.com/bbenz/kubecon26-pre-day-lab`, `main` | The lab repository, and a branch or tag of it (not a commit hash). Use a tag for the event, such as `v1.0.0`, so every lab gets the same tested scripts and instructions. Never the instructors' repository: the readiness gate fails if the clone has solutions. |
| `LabRoot` | `C:\LabFiles\kubecon26-pre-day-lab` | The lab repository on the VM: the image's clone, which VS Code opens at sign-in, and which the lab instructions' commands use. |
| `RemoveCredentials` | `AfterGate` | `AfterGate`: the readiness gate LCA removes the service principal. `AfterPrepare`: a clean prepare run does, for a profile without the readiness gate LCA. `Never`: testing only. |
| `GateFailsPrepare` | `$false` | `$true` for the event: a failed readiness gate fails the prepare LCA, and End Lab discards the preinstance |
| `WaitMinutes` | `50` | How long the LCA waits for the worker. Keep it 10 minutes below the Timeout. The worker keeps running, and a retry waits for it. |
| `Manual` | `$false` | `$true` runs everything in the PowerShell window as you. The manual bootstrap sets it. |

## Readiness gate checks

The prepare LCA runs the gate at the end of each run, and the readiness gate LCA runs it again when a
preinstance is assigned.

| Severity | Checks |
| --- | --- |
| Fail | **Azure sign-in** (the worker's profile, in the lab's subscription), **Cluster** (power state Running, and provisioning not Failed; AKS Automatic's own background updates show as Updating), **Nodes** (at least one Ready), **Challenge namespaces** (all selected), **Challenge workloads** (every challenge namespace has pods; some fail on purpose), **Portal user access** (AKS RBAC Cluster Admin), **kubeconfig** (the lab user's current context is the cluster, in kubelogin `azurecli` mode), **Attendee Azure CLI** (not signed in, browser sign-in on), **Lab folder** (the lab repository has `deploy.ps1`, `scoring\verify.ps1`, the PowerShell module, each selected challenge's instructions, and the rendered manifests), **No solutions on the VM** (no `SOLUTION.md`, `FEASIBILITY.md`, or `challenge-end-state` anywhere in `C:\LabFiles`, or in the lab repository's git history) |
| Warning | **Portal user monitoring access** (Monitoring Data Reader, for A2's dashboards with Grafana), **Inspektor Gadget** (with `InspektorGadget = $true`: at least one `gadget` pod is ready), **Lab tools** (the image's tools, and Azure CLI 2.86 or later) |
| Fail, when the credentials are removed | **Cloud credentials removed**: the worker's Azure CLI profile is gone, the PowerShell event logs are cleared, and no event has the service principal's application ID |

## Test a launch

1. Launch the profile. When the lab is displayable, wait for the prepare LCA. A first run takes 20 to 30 minutes.
2. In the VM, VS Code shows the lab repository. Open `.lab\skillable`: the newest `begin-state-*.log` ends with
   the summary and the readiness gate table. The full log is in `C:\ProgramData\kubecon-ctf-lca` (elevated).
3. In the VS Code terminal, run `az login`, and select the lab account you signed in to the portal with. Then
   run `kubectl get nodes`, `kubectl get namespaces -l kubecon.lab/challenge`, and
   `.\scoring\verify.ps1 -Quick -NoReport`: every challenge shows **NOT PASSED**, because the begin state has the
   seeded faults. Reset C1 with the lab instructions' reset command, as the attendee, and confirm that it takes 2 to
   5 minutes:

    ```powershell
    C:\LabFiles\kubecon26-pre-day-lab\begin-challenge\azure-cli-powershell\deploy.ps1 -ResourceGroup <resource group> -ClusterName aks-kubecon-ctf -Challenges c1
    ```

4. Confirm that the VM has no solutions: the gate's **No solutions on the VM** row passed,
   `git -C C:\LabFiles\kubecon26-pre-day-lab log --all --oneline` shows one commit, and
   `Get-ChildItem C:\ -Recurse -Force -Filter SOLUTION.md -ErrorAction SilentlyContinue` finds nothing.
5. To run the readiness gate yourself (a test launch without preinstances doesn't), open PowerShell as
   administrator, and run the following command. Like the readiness gate LCA, it then removes the service
   principal's sign-in and clears the PowerShell event logs, unless `RemoveCredentials` is `Never`:

    ```powershell
    & 'C:\Program Files\PowerShell\7\pwsh.exe' -File C:\LabFiles\kubecon26-pre-day-lab\skillable\lca\Invoke-CtfLabSetup.ps1 -Mode Verify
    ```

6. Confirm that `C:\ProgramData\kubecon-ctf-lca\azure-cli` no longer exists, and that the gate's last row,
   **Cloud credentials removed**, passed.

## Build the begin state by hand

To test before a pool admin turns on the cloud credentials, build the same begin state as yourself, the lab's
cloud portal user, in a running lab:

1. The test profile's cloud portal user needs **Owner** on the resource group (the begin state assigns roles), and
   the subscription's resource providers must be registered. Change the user's role in the resource group's
   **Permissions** to Owner, or add `manual-test-access.ps1` as a cloud platform LCA, which does both. Keep
   Contributor in the event's profile.
2. Launch the lab, and sign in to the Azure portal in Edge with the lab's username and Temporary Access Pass.
3. In the VM, open Windows PowerShell **as administrator**, and paste `manual-begin-state-bootstrap.txt` (right-click
   pastes). It writes `C:\LabSetup\kubecon-ctf-begin-state.ps1`, checks its hash, and runs it.
4. If the Azure CLI isn't signed in, a browser tab opens: select your lab account. The run shows each step and
   the readiness gate in the window, and takes 20 to 30 minutes. To run it again, run
   `powershell -ExecutionPolicy Bypass -File C:\LabSetup\kubecon-ctf-begin-state.ps1` as administrator.

A manual run is as the resource group's Owner, which can't purge deleted Foundry accounts: that needs
subscription-level access. So a lab where a run before November 5, 2026 left the Foundry account in a region
without the model (westcentralus) can't fix it by hand: `deploy.ps1` stops at C4 with the two commands to run with
an identity that has that access, and leaves the account as it is. Launch a new lab instead.

Outside Skillable, you can also run the deployment directly from a clone of the lab repository, the way its README
describes: `pwsh ./begin-challenge/azure-cli-powershell/deploy.ps1 -ResourceGroup <rg>`. Never clone the
instructors' repository in a lab VM that an attendee gets.

## GitHub Copilot, AKS-MCP, and az aks agent

- **AKS-MCP**: the image installs `aks-mcp.exe` and configures it in the lab user's VS Code `mcp.json`
  (`--access-level readwrite`). It runs as the attendee, with their `az login` and kubeconfig. VS Code asks the
  attendee to trust the server the first time it starts. The **MCP servers in Copilot** policy must be on for
  organization or enterprise Copilot seats (see [Before you start](#before-you-start)).
- **az aks agent**: the image installs the `aks-agent` extension. The agent needs a large language model: its
  `az aks agent-init` asks for an Azure OpenAI (or other) endpoint and key, and deploys the agent to the cluster
  (cluster mode), or runs it in Docker (client mode, which the lab VM doesn't have). The LCA doesn't configure a
  model. Decide whether the lab provides one (for example, a shared deployment), or whether attendees use Copilot
  with AKS-MCP instead. Until then, treat `az aks agent` as optional. Never put a model's key in either repository.

## The event leaderboard (optional)

The verify scripts can report results to an event leaderboard ([leaderboard/README.md](../leaderboard/README.md)).
`leaderboard/setup.ps1` writes `.lab/leaderboard/skillable-lca-windows.ps1`, a third VM LCA with the
leaderboard's write-only token: add it with the event **Running Preinstance Assigned To User** or later, so
that it has the attendee's `@lab.User` name. Never commit the generated script.

## What the LCAs don't do

- **Teardown:** Skillable deletes the resource group, which removes the cluster and its node resource group. Run
  an orphan sweep after the event. The C4 Foundry account and A4 Key Vault are soft-deleted; each lab subscription
  has its own names, so they don't collide.
- **Maintenance windows:** set planned maintenance windows that exclude the event days if the profile keeps
  clusters for long.
- **Managed NGINX support:** Microsoft supports the application routing add-on's managed NGINX through November
  2026. C2 depends on it being enableable: re-check before the event.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `KubeCon CTF prepare can't start: the CLOUD CREDENTIALS section ... is still commented out` | A pool admin hasn't turned the credentials on. See [The pool's secure tokens](#the-pools-secure-tokens). |
| `... the ClientId token still has a space after the @`, or `wasn't replaced` | The section was edited incompletely, or the profile has no cloud subscription pool. Only a pool admin can fix the lines once they have tokens. |
| Skillable says **You do not have permission to edit scripts that contain secure tokens** | The script has an active token. Paste the `.ps1` file again (its tokens are commented out), or ask a pool admin. |
| Skillable reports unsupported characters | Paste from the `.ps1` file. The scripts are ASCII only. |
| `C:\Program Files\PowerShell\7\pwsh.exe is missing` | The VM image predates PowerShell 7. Rebuild it with the current image script. |
| `Expected one signed-in user, found 0` | Automatic sign-in isn't working in the image. See the VM image runbook. |
| `... has no copy of the lab repository, and git clone failed` | The image has no clone of the lab repository (rebuild it with the current image script), and the VM couldn't clone it either: check that the VM can reach GitHub, and that `RepoRef` is a branch or tag of `RepoUrl`. |
| The result says `WARNING: couldn't fetch <RepoRef>, so the image's copy is used` | The VM couldn't reach GitHub, or `RepoRef` doesn't exist. The lab works, with the image's commit, but its scripts and instructions can differ from the event's. Check `RepoRef`, and relaunch. |
| `git checkout of <RepoRef> failed` | Read the error. Usually a file in the clone is open in another process: relaunch. |
| **FAIL** No solutions on the VM | The lab repository on the VM has solution content, in its files or its git history, or something else in `C:\LabFiles` does. Usually `RepoUrl` is the instructors' repository, or `RepoRef` is a version of the lab repository from before the solutions moved out (November 4, 2026). Fix the settings, and relaunch; rebuild the image if the image's clone has them. Don't give the VM to an attendee. |
| **FAIL** Lab folder | The clone lacks a file that the lab needs: `RepoRef` is a version with another layout, or `deploy.ps1` didn't render the manifests (read the **Begin state** step). |
| **WARN** Lab repository: `git gc failed` | The clone keeps its other references until the next run. The **No solutions on the VM** check still reads the whole history. |
| `The service principal couldn't sign in and see the subscription within 5 minutes` | Read the last error. Check the pool's health in Skillable Studio, and relaunch. |
| **WARN** Resource providers: `Can't read the subscription's resource providers` | The service principal has no subscription-level read. The deployment fails later if a provider is missing: register them in the pool, or use `manual-test-access.ps1`. |
| **FAIL** Begin state (deploy.ps1) | Read the `\|` lines before it in the log, which are `deploy.ps1`'s output. Usual causes: `RequestDisallowedByPolicy` (the ACP blocks a type, region, or size), `InsufficientQuota` or `quota` at C4 (no `gpt-6-luna` Global Standard quota: ask Skillable, or leave `c4` out), or a region without AKS Automatic. Fix the cause and retry: `deploy.ps1` reuses what exists. |
| **FAIL** Begin state, at **C4**: `SpecialFeatureOrQuotaIdRequired` ... `does not have access to this model` | The Foundry account is in a region that doesn't offer the model: westcentralus offers no OpenAI models. Since November 5, 2026, `deploy.ps1` creates the account in a region that offers it (westus3, for westcentralus), and a retry re-creates an account that an earlier run left in the wrong region, which adds about 3 minutes. That needs the service principal: a manual run, as the resource group's Owner, can't purge the old account, so it stops with the commands to run (see [Build the begin state by hand](#build-the-begin-state-by-hand)). If it still fails in the new region, the subscription has no access to the model there: ask Skillable, or leave `c4` out. |
| **FAIL** Begin state, after **Kubernetes data-plane access (Azure RBAC)**: `Could not assign 'Azure Kubernetes Service RBAC Cluster Admin' ... (RequestDisallowedByPolicy)` | The ACP denies role assignments; the message names the policy assignment. Send Skillable the [message in AZURE-RESOURCES.md](AZURE-RESOURCES.md#message-for-skillable): it lists every role assignment that a launch makes, so the next one doesn't stop it too. The same error can name another role later in the log, such as Cognitive Services OpenAI User (C4) or Key Vault Secrets User (A4). |
| **FAIL** Begin state: `Could not assign '<role>' ... (AuthorizationFailed)` | The service principal may not create role assignments: it isn't Owner (or User Access Administrator, or Role Based Access Control Administrator) of the lab's subscription, or a condition limits which roles it can assign. Ask Skillable. In a manual run, the cloud portal user needs Owner on the resource group: see [Build the begin state by hand](#build-the-begin-state-by-hand). |
| **WARN** Portal user access: `Couldn't assign '<role>' ... (RequestDisallowedByPolicy)` or `(AuthorizationFailed)` | The same causes, for the portal user's roles. The readiness gate then fails **Portal user access**, because the attendee's `kubectl` needs Azure Kubernetes Service RBAC Cluster Admin. |
| **WARN** Portal user access: `Couldn't find the object ID of the portal user` | The service principal can't read Microsoft Graph, and not exactly one user has a role on the resource group. Check `PortalUser` and the resource group's **Permissions**. |
| **WARN** Inspektor Gadget | Read the error. `RequestDisallowedByPolicy`: the ACP must allow `Microsoft.KubernetesConfiguration/extensions`. `No Inspektor Gadget pod is ready after 4 minutes`: the lab's nodes are full; the pods start when NAP or the challenges free room. The lab works without it: A1 lists it as optional. |
| **FAIL** Challenge workloads: `No pods in: <namespace>` | That challenge didn't deploy. Read `deploy.ps1`'s output for it in the log, and retry. |
| `KubeCon CTF prepare is still running after 50 minutes` | The worker keeps running, and a retry waits for it. If it happens often, raise the Timeout and `WaitMinutes`. |
| **FAIL** Cloud credentials removed | Don't give the VM to an attendee. Delete `C:\ProgramData\kubecon-ctf-lca\azure-cli`, run `wevtutil cl Microsoft-Windows-PowerShell/Operational` and `wevtutil cl "Windows PowerShell"` as administrator, or discard the preinstance. |
| **FAIL** Azure sign-in in the readiness gate LCA | The worker's profile is already gone, for example because the gate already ran. Run the prepare LCA again. |
| An attendee's `kubectl` says to run `az login`, or a check can't reach the cluster | Expected until the attendee runs `az login`. If it continues, they signed in with another account: run `az login` again with the lab account. |
| An attendee's reset command fails | Read its output: it's `deploy.ps1`'s. Run it again; it reuses what exists. `AuthorizationFailed`: the portal user's roles are missing (see the gate's **Portal user access** row). Transient errors, such as an Azure RBAC webhook timeout, are retried; if one still stops it, run it again. |
| Manual: `Run this script in PowerShell as administrator` | Open Windows PowerShell with **Run as administrator**, and paste the bootstrap again. |
| Manual: `Hash mismatch` or `Decode failed` | A part was missed or pasted twice. Open a new window, and paste all the parts again. |
| Manual: `AuthorizationFailed` on a role assignment in the log | Your lab account isn't Owner of the resource group. See step 1 of [Build the begin state by hand](#build-the-begin-state-by-hand). |
