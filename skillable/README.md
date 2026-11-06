# Skillable deployment

How the KubeCon AKS capture-the-flag lab runs on [Skillable](https://www.skillable.com/): a lab VM image with the
lab repository on it, life cycle actions (LCAs) that build each attendee's environment in the begin state, and the
lab instructions, generated from the challenges. Modeled on the LAB723 (Ignite 2026) Skillable artifacts, with a
much shorter prepare LCA.

The scripts and the lab instructions are in the lab repository's
[`skillable`](https://github.com/bbenz/kubecon26-pre-day-lab/tree/main/skillable) folder, because every lab VM runs
them from its clone of that repository. The runbooks are here:

| What | Where | Runbook |
| --- | --- | --- |
| The VM image setup script, run by hand in the lab VM, and its paste-in bootstrap | Lab repository: [`skillable/vm-image`](https://github.com/bbenz/kubecon26-pre-day-lab/tree/main/skillable/vm-image) | [VM-IMAGE-RUNBOOK.md](VM-IMAGE-RUNBOOK.md) |
| The prepare LCA, the worker and cleanup scripts it runs, a test-only access LCA, and a manual begin-state bootstrap | Lab repository: [`skillable/lca`](https://github.com/bbenz/kubecon26-pre-day-lab/tree/main/skillable/lca) | [LCA-RUNBOOK.md](LCA-RUNBOOK.md) |
| The lab instructions to import into Skillable Studio (generated: don't edit them) | Lab repository: [`skillable/skillable lab steps.md`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/skillable%20lab%20steps.md) | [The lab instructions](#the-lab-instructions) |
| The generator and its template | Lab repository: [`skillable/build-lab-steps.ps1`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/build-lab-steps.ps1), [`skillable/lab-steps-template.md`](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/skillable/lab-steps-template.md) | [The lab instructions](#the-lab-instructions) |
| The leaderboard (optional): its setup, and `publish`, which opens it to attendees through https://aka.ms/aksctfsecrets | This repository: [`leaderboard`](../leaderboard/README.md) | [leaderboard/README.md](../leaderboard/README.md) |
| What the lab profile's access control policy must allow, with a message for Skillable | This repository | [AZURE-RESOURCES.md](AZURE-RESOURCES.md) |

## How a lab launches

```mermaid
sequenceDiagram
    participant S as Skillable
    participant VM as Lab VM (image)
    participant W as Worker (SYSTEM)
    participant AZ as Attendee's subscription
    S->>AZ: Pre-Build: resource group, cloud portal user (Contributor)
    S->>VM: Start the VM; automatic sign-in; VS Code opens the lab repository
    S->>VM: First Displayable: prepare LCA (service principal)
    VM->>VM: git fetch RepoRef into the image's shallow clone (C:\LabFiles\kubecon26-pre-day-lab)
    VM->>W: Scheduled task: the clone's Invoke-CtfLabSetup.ps1 -Mode Prepare
    W->>VM: Keep only the checked-out commit (no other branches, tags, or history)
    W->>AZ: The clone's deploy.ps1: AKS Automatic + challenge services, 10 challenges broken
    W->>AZ: Portal user: AKS RBAC Cluster Admin, Monitoring Data Reader
    W->>VM: kubeconfig (azurecli), browser sign-in for az, readiness checks
    W->>VM: Delete the service principal's profile, write the setup log in the clone's .lab\skillable
    VM->>VM: After the LCA ends, a cleanup task clears the PowerShell logs and adds its result to the log
    S->>VM: Preinstance assigned to an attendee
    Note over VM: Attendee: az login (Temporary Access Pass), then the challenges
```

| Order | Event | Action | Time |
| ---: | --- | --- | --- |
| 1 | Pre-Build | Skillable creates the resource group, the cloud portal user, and the VM from the committed image | Skillable |
| 2 | First Displayable | **Prepare LCA**, the only required LCA: the lab repository at `RepoRef`, the begin state of all ten challenges, the portal user's roles, the lab user's kubeconfig and Azure CLI, optionally Inspektor Gadget, and the readiness checks. Then it removes the service principal from the VM, and writes the results to the setup log, `.lab\skillable\begin-state-<time>.log` in the lab repository ([Logs and results](LCA-RUNBOOK.md#logs-and-results)) | 20 to 30 minutes (20 in testing) |
| 3 | When the prepare LCA ends | **Cleanup task**, started by the prepare LCA: clears the PowerShell event logs, which can have the service principal's secret, and adds its result to the setup log | Seconds |
| 4 | Tearing Down | Skillable deletes the resource group and the cluster | Skillable |

The leaderboard, if the event has one, needs no LCA: attendees join it from the lab instructions (**Get started**,
Task 6), and the organizer publishes its token without changing the profile ([The event leaderboard](LCA-RUNBOOK.md#the-event-leaderboard-optional)).

## The lab VM

The image setup script installs every tool from the lab design's VM prerequisites, verified against
published checksums or signatures:

- Azure CLI (2.86 or later) with the **aks-agent** extension, and **k8s-extension**
- **kubectl**, **kubelogin**, and **Helm**
- **GitHub CLI**
- **AKS desktop** and **Inspektor Gadget** (`kubectl gadget`; the prepare LCA can add its AKS cluster extension,
  off by default: see the LCA runbook)
- **VS Code** with **GitHub Copilot** (built into current VS Code) and the **Kubernetes** and **AKS** extensions,
  with **AKS-MCP** set up as a user MCP server, without its `cilium` and `hubble` components, which it can't start
  without (the prepare LCA sets the same arguments at each launch, and checks that it starts)
- **PowerShell 7**, **Git** (Git Bash), **Terraform**, **ingress2gateway** (C2), and **WSL** with Ubuntu and the
  Azure CLI, kubectl, kubelogin, and Helm inside it
- **The lab repository** in `C:\LabFiles\kubecon26-pre-day-lab`, a shallow clone with one commit, opened by VS
  Code at sign-in. The prepare LCA moves it to the event's tag at each launch. Attendees use its scoring script
  to check a challenge and its deployment script to reset one, and can take the repository home.

Two prerequisites aren't VM settings:

- **Azure Kubernetes Service RBAC Cluster Admin**: AKS Automatic turns off local accounts, and Owner isn't
  enough. The prepare LCA gives it to the cloud portal user, and deploys (and scores) as the service principal,
  which `deploy.ps1` gives the same role. [Participant permissions](../docs/participant-permissions.md) has what
  each challenge needs.
- **MCP servers in Copilot**: a GitHub organization or enterprise policy, off by default, for Copilot Business
  and Enterprise seats. Attendees get Copilot from the Skillable Events enterprise, through its single sign-on
  (the lab instructions' **Get started**, Task 3), so an owner of that enterprise turns it on (enterprise
  **AI controls** > **MCP**). See the [LCA runbook](LCA-RUNBOOK.md#before-you-start).

## Readiness checklist for an event profile

- [ ] The lab repository tagged for the event (such as `v1.0.0`), after `./skillable/build-lab-steps.ps1 -Check`
      passes there
- [ ] VM image built and committed with the image setup script from that tag ([VM image runbook](VM-IMAGE-RUNBOOK.md))
- [ ] Profile: cloud subscription pool; resource group `ResourceGroup1` with **Override Data Center** set to West US 3
      (AKS Automatic, and `gpt-6-luna` Global Standard for C4; another region needs an ACP that allows the Foundry
      account in westus3: [Regions](AZURE-RESOURCES.md#regions)); portal user `User1` with Contributor
- [ ] Access control policy allows everything in [AZURE-RESOURCES.md](AZURE-RESOURCES.md), including the role
      assignments
- [ ] Quota per lab subscription: about 16 to 24 D-family vCPUs, and 50,000 TPM of `gpt-6-luna` Global Standard
- [ ] The prepare LCA added ([settings](LCA-RUNBOOK.md#add-the-lca-in-skillable)), with `RepoRef` set to the
      event's tag, and a pool admin has turned on its cloud credentials
- [ ] Lab instructions imported from `skillable lab steps.md` at the same tag
- [ ] A test launch's setup log, `.lab\skillable\begin-state-<time>.log` in the lab repository, shows every step and
      readiness check passed, and ends with the cleanup task's **Cloud credentials removed** line, passed;
      `.\scoring\verify.ps1 -Quick -NoReport` in the lab repository shows every challenge **NOT PASSED**; and the
      lab instructions' reset command for C1 works as the attendee
- [ ] Preinstances with at least 45 minutes of lead time, plus spares
- [ ] GitHub Copilot through the Skillable Events single sign-on works in a test launch (the lab instructions'
      **Get started**, Task 3), and Copilot can use AKS-MCP: the enterprise's **MCP servers in Copilot** policy is on
- [ ] Decision on a model for `az aks agent` ([LCA runbook](LCA-RUNBOOK.md#github-copilot-aks-mcp-and-az-aks-agent))
- [ ] Optional: the event leaderboard ([leaderboard/README.md](../leaderboard/README.md)), with
      https://aka.ms/aksctfsecrets pointing at its secret gist, and a join from **Get started**, Task 6, tested in a launch

## The lab instructions

`build-lab-steps.ps1`, in the lab repository, generates `skillable lab steps.md` from `lab-steps-template.md` and
each challenge's `README.md`: an introduction, getting started, tools and tips, checking and resetting, a page for
each challenge, and a wrap-up. On a challenge's page, the hints become collapsible sections, and the check and
reset commands become type text that runs the lab repository's own scripts on the VM:

```text
C:\LabFiles\kubecon26-pre-day-lab\scoring\verify.ps1 -Challenges <id>
C:\LabFiles\kubecon26-pre-day-lab\begin-challenge\azure-cli-powershell\deploy.ps1 -ResourceGroup @lab.CloudResourceGroup(ResourceGroup1).Name -ClusterName aks-kubecon-ctf -Challenges <id>
```

**When you change a challenge,** edit its `README.md` in the lab repository, and its `SOLUTION.md`, end state, and
notes here. Then, in the lab repository, run `./skillable/build-lab-steps.ps1` and
`./skillable/build-lab-steps.ps1 -Check`, which fails if the instructions are out of date, or if the lab repository
has instructor-only content. Commit, tag the release, set the prepare LCA's `RepoRef` to the tag, and import the new
instructions into Skillable Studio.

## Where the solutions are

Only here. The lab repository is public, and it's on every lab VM, so it has no solutions, end state, feasibility
notes, or proctor material, and no links to them. Three checks keep it that way:

| Check | Where | What it looks for |
| --- | --- | --- |
| `build-lab-steps.ps1 -Check` | The lab repository, before you commit | Instructor-only files and folders (`SOLUTION.md`, `FEASIBILITY.md`, `challenge-end-state`, the leaderboard's setup), instructor-only markers in its markdown, and solution words in the challenges' READMEs and the lab instructions |
| **Lab repository and startup shortcuts**, and **No solutions in the lab folder** | The VM image setup script, and its `-Finalize` | `SOLUTION.md`, `FEASIBILITY.md`, or `challenge-end-state` in `C:\LabFiles\kubecon26-pre-day-lab`, or in its git history |
| **No solutions on the VM** | The prepare LCA's readiness checks, at each launch | The same, anywhere in `C:\LabFiles`, and in the clone's git history |

The VM's clone is shallow (one commit), and the worker removes every other branch, tag, and remote-tracking
reference, so `git log` on the VM can't reach older versions of the lab repository, which had the solutions.

**What attendees can still see on the VM:** the scoring scripts show what each check looks at (the check's
output names each criterion anyway), and the deployment scripts and manifests show each challenge's starting
state, such as C4's model deployment name. That's by design: attendees run these scripts, and take them home. If a
leaderboard with prizes makes it matter, consider Skillable's activity-based assessments, whose scripts are kept
in the lab profile instead of the VM.

**What the public can still see:** the lab repository's history on GitHub, until it's published again with a
clean history. See [Publish the lab repository without its old history](../README.md#publish-the-lab-repository-without-its-old-history).

## Test results

The tests before November 5, 2026 had a second LCA, a readiness gate at **Running Preinstance Assigned To User**,
which removed the service principal. Skillable doesn't run scripts in a VM at that event, so the prepare LCA now
does it, and a cleanup task clears the PowerShell event logs after the LCA ends.

### Credential cleanup (2026-11-05)

Tested in Azure (westus3), on a Windows Server 2022 VM with PowerShell 7.6, with the prepare LCA run as SYSTEM
through `powershell.exe` (Azure Run Command), and a clone of a test repository with the worker and the cleanup
script. Each run's LCA had its own fake service principal ID and secret, and the event logs were searched for them.

| Run | Result |
| --- | --- |
| `AfterPrepare`, no signed-in user, so the LCA stops before the worker | The cleanup task waited for the LCA's process to end, cleared the PowerShell event logs, and wrote a **PASS** line to `.lab\skillable\cleanup-<time>.log` 7 seconds later. |
| `AfterPrepare`, a signed-in lab user, and a stand-in Azure CLI profile, so the worker runs (and stops at its first step) | The worker's **Cloud credentials removed** check passed: it deleted the profile. The secret in `config.json` was blank, and the setup log ended with the cleanup task's **PASS** line, 16 seconds after its summary. No PowerShell event log had a fake secret. |
| `Never`, as a control | A Windows PowerShell event 4104 had the LCA's text, with its fake secret. |

Only a Skillable launch can show how its integration service starts the script, and whether it leaves a copy of the
script on the VM: check a test launch's setup log for the cleanup task's line.

### AKS-MCP (2026-11-05)

In a Skillable launch, Copilot's **Configure Tools** didn't keep **aks-mcp** selected: VS Code's output showed
`cilium is not installed or not found in PATH`, the same for `hubble`, `Validation failed`, and exit code 1. Without
`--enabled-components`, aks-mcp 0.0.22 turns on every component, and checks that each one's CLI is on the PATH when
it starts. The image's checks only looked at `mcp.json`, and never started the server. Tested with the image's pinned
binary (SHA-256 matched), on Windows:

| Test | Result |
| --- | --- |
| The image's earlier arguments (`--access-level readwrite --timeout 600`), with `az`, `kubectl`, and `helm` on the PATH | Exit code 1, `Validation failed` |
| The same, plus `--enabled-components az_cli,monitor,fleet,network,compute,detectors,advisor,inspektorgadget,kubectl,helm` | Starts, and lists 11 tools: `call_az`, `call_kubectl`, `call_helm`, `inspektor_gadget_observability`, `aks_monitoring`, `aks_network_resources`, `aks_detector`, `aks_advisor_recommendation`, `az_fleet`, `get_aks_vmss_info`, and `collect_aks_node_logs` |
| The same, with an empty Azure CLI profile (not signed in) | Starts in under a second; aks-mcp doesn't run `az` when it starts |
| The worker's new step and check, loaded from the script, with a copy of the image's `mcp.json` | The check warned with aks-mcp's errors, the step set the arguments, and the check then passed. A second run changed nothing; other servers and settings in `mcp.json` stayed; with the worker's `AZURE_` variables set, the server got none of them. |
| The image script's new **AKS-MCP** row, in Windows PowerShell 5.1, with the `mcp.json` its own code writes | Passed with the new arguments; failed with the earlier ones, with aks-mcp's errors |

### Repository on the VM (2026-11-04)

Tested outside Skillable, in Azure (westus3), as close to a Skillable launch as possible: a clean Windows 11 Pro
26H2 VM (D4s_v5, automatic sign-in), a test service principal that was Owner of the lab resource group only (no
Microsoft Graph permissions) as the cloud subscription's service principal, and a user with Contributor on the
resource group as the cloud portal user. The lab repository's new commit wasn't pushed yet, so the VM fetched it
from a local bare repository (`RepoUrl` `file:///C:/Bundle/repo.git`, `RepoRef` `skl-e2e`), which was deleted before
`-Finalize`.

| Step | Result |
| --- | --- |
| Image setup script, first pass, with the default `RepoUrl` and `RepoRef` (GitHub's `main`, still the version with the solutions) | Items 1 to 11 READY, with the restart for WSL. Item 12 FAILED with "has solution content", as designed: the clone of that `main` has the solutions. |
| Second pass, after the restart, with the new commit | ALL ITEMS READY. Item 12 moved the clone to the new commit and dropped the old one: 1 commit, only `refs/heads/lab`. **No solutions in the lab folder** passed. |
| Prepare LCA, as SYSTEM through `powershell.exe`, with the tokens filled in | `KubeCon CTF lab is ready. Readiness gate passed.` in 17 minutes 55 seconds, 17 of them in `deploy.ps1` (all ten challenges). All 12 readiness checks passed, including **Lab folder** and **No solutions on the VM**. The clone: 1 commit, one branch, shallow, no changes. |
| Readiness gate LCA, as SYSTEM | Passed in 12 seconds, all 13 checks, including **Cloud credentials removed**. Afterward, no event log entry or file had the service principal's application ID or secret, and no `SOLUTION.md`, `FEASIBILITY.md`, or `challenge-end-state` was anywhere on `C:`. |
| The lab instructions' commands, as an attendee stand-in (a service principal with only the portal user's roles) | `verify.ps1 -Challenges c1 -Quick`: NOT PASSED. The reset command for C1: 35 seconds; for A4: 76 seconds. `verify.ps1 -Challenges c1,a4 -Quick`: NOT PASSED. The resource group's region and tags didn't change. |
| Access for a lab user who isn't an administrator | The lab folder, including the `.lab` folder that the LCA creates as SYSTEM, inherits **Authenticated Users: Modify**, and git trusts the folder for every user. (On an Azure VM, the admin account is the built-in Administrator, so the stand-in itself ran elevated.) |
| The end state from this repository, over the same environment: PowerShell, then bash | 4 and 5 minutes. Then the lab repository's `verify.ps1`: all ten challenges PASSED, 60 of 60 checks. The bash `verify.sh -Quick`: C2 at 8 of 9 right after the bash run had applied its route again, then 9 of 9 on a second run; the other nine PASSED. |
| Image setup script again, after the launch, with a `C:\lab-resources` folder from the earlier design | ALL ITEMS READY; `C:\lab-resources` and the launch's `.lab` folder removed |
| `-Finalize -NoShutdown -Force` | Image finalized: the LCA's state and scheduled task, the kubeconfig, `.lab`, and `C:\LabSetup` removed; the clone kept its one commit, with no changes. (`-Force` because a plain Azure VM has no Skillable integration service.) |

### Earlier design (2026-11-03)

Tested outside Skillable, in Azure (westus3), as close to a Skillable launch as possible: a clean Windows 11 Pro
26H2 VM (D4s_v5, automatic sign-in), a resource group with a test service principal that was Owner of that resource
group only (no Microsoft Graph permissions), and a user with Contributor on it as the cloud portal user. At the
time, the lab repository had the solutions, so the prepare LCA built an attendee folder, `C:\lab-resources`, from a
protected clone, and deleted the clone. The tools, the deployment, and the credential handling haven't changed
since.

| Step | Result |
| --- | --- |
| Image setup script, typed in as the lab user (elevated), via the bootstrap's payload | 12 items READY: first pass 12 minutes, restart for WSL, second pass about 6 minutes (Ubuntu on WSL 2 with the Linux tools). Every verification row passed, except the Skillable integration service, which a plain Azure VM doesn't have. A rerun on a finished image takes 2.5 minutes. |
| Prepare LCA, as SYSTEM through `powershell.exe`, with the tokens filled in | The worker deployed all ten challenges in 18.5 minutes (cluster 11.5 minutes), gave the portal user its three roles without Microsoft Graph, wrote the lab user's kubeconfig, and set up the lab user's Azure CLI. About 20 minutes in all without Inspektor Gadget. Later runs: 5.5 minutes with the cluster in place, and 8.7 minutes for a full redeploy over an existing begin state. |
| Readiness gate LCA, as SYSTEM | Passed in 13 to 18 seconds. Before it ran, the Windows PowerShell Operational log had one event with the service principal's application ID **and its secret** (the prepare LCA's text); afterward, the worker's Azure CLI profile was gone and no event had the application ID. |
| The attendee's check and reset of C1 and A4, as an attendee stand-in (a service principal with only the attendee's roles) | **NOT PASSED** before; both resets done (A4's retried two Azure RBAC webhook timeouts); **NOT PASSED** after |

Fixes from those tests: Copilot Chat is built into VS Code 1.144 (the image checks for it instead of installing
it); the Linux Azure CLI in WSL (WSL's appended Windows PATH hid it); Inspektor Gadget became opt-in (its
DaemonSet can't run on AKS Automatic's hosted system nodes, so the extension stayed in Creating and held the LCA
for 17 minutes); the deployment scripts read the signed-in identity's object ID from its token, and check role
assignments without Microsoft Graph; a race in C4's model deployment; and retries for Azure RBAC webhook timeouts.

Not tested outside Skillable: the pool's secure-token handoff, Skillable's own script runner, the lab client's
console (VS Code and Edge opening at sign-in), the attendee's `az login` with a Temporary Access Pass, and the
manual begin-state bootstrap (it needs an interactive browser sign-in).
