# KubeCon AKS capture-the-flag lab · instructors

> **Confidential.** This repository has the solutions to the lab's challenges. Keep it private, share it only with the
> lab's instructors and proctors, and never clone it on a lab VM.

Everything that instructors need, and attendees mustn't see, for the KubeCon North America 2026 Azure Day pre-day lab
(*Capture the Flag AKS Lab*): the solutions, the solved end state, the evaluation notes, the event-day guides, the
event leaderboard, and the runbooks for the Skillable deployment.

Everything that attendees get is in the **lab repository**, <https://github.com/bbenz/kubecon26-pre-day-lab>
(<https://aka.ms/kubecon26-pre-day-lab>): each challenge's instructions and manifests, the scripts that deploy the
challenges (bash, PowerShell, and Terraform), the scoring scripts, the Skillable scripts, and the Skillable lab
instructions. It's public, every lab VM has a copy, and attendees can take it home.

## Start here

| For | Read |
| --- | --- |
| The day of delivery | [delivery/RUN-OF-SHOW.md](delivery/RUN-OF-SHOW.md): timeline, roles, and checklists |
| Running a round | [delivery/PROCTOR-GUIDE.md](delivery/PROCTOR-GUIDE.md): for each challenge, the fault, the fix, when to release hints, common wrong turns, and debrief points |
| A challenge in detail | Its SOLUTION.md (table below): the full walkthrough with commands and expected output |
| Choosing the line-up | [FEASIBILITY.md](FEASIBILITY.md): assessments, the recommended four rounds, and the 3-hour timing plan |
| The projected leaderboard | [leaderboard/README.md](leaderboard/README.md) |
| Building the Skillable lab | [skillable/README.md](skillable/README.md), [the LCA runbook](skillable/LCA-RUNBOOK.md), [the VM image runbook](skillable/VM-IMAGE-RUNBOOK.md) |
| Testing the lab | [docs/testing.md](docs/testing.md) |

## The challenges

| ID | Challenge (attendee instructions) | Solution | End state | Assessment |
| --- | --- | --- | --- | --- |
| C1 | [The store won't start](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/c1-the-store-wont-start/README.md) | [SOLUTION](challenge-end-state/challenges/c1-the-store-wont-start/SOLUTION.md) | [README](challenge-end-state/challenges/c1-the-store-wont-start/README.md) | [C1](FEASIBILITY.md#c1--the-store-wont-start) |
| C2 | [Move the storefront to Gateway API](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/c2-ingress-nginx-to-gateway-api/README.md) | [SOLUTION](challenge-end-state/challenges/c2-ingress-nginx-to-gateway-api/SOLUTION.md) | [README](challenge-end-state/challenges/c2-ingress-nginx-to-gateway-api/README.md) | [C2](FEASIBILITY.md#c2--move-the-storefront-to-gateway-api) |
| C3 | [Capacity that never arrives](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/c3-capacity-that-never-arrives/README.md) | [SOLUTION](challenge-end-state/challenges/c3-capacity-that-never-arrives/SOLUTION.md) | [README](challenge-end-state/challenges/c3-capacity-that-never-arrives/README.md) | [C3](FEASIBILITY.md#c3--capacity-that-never-arrives) |
| C4 | [The AI assistant is up, but not working](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/c4-ai-assistant-up-but-not-working/README.md) | [SOLUTION](challenge-end-state/challenges/c4-ai-assistant-up-but-not-working/SOLUTION.md) | [README](challenge-end-state/challenges/c4-ai-assistant-up-but-not-working/README.md) | [C4](FEASIBILITY.md#c4--the-ai-assistant-is-up-but-not-working) |
| A1 | [Where did DNS go?](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/a1-where-did-dns-go/README.md) | [SOLUTION](challenge-end-state/challenges/a1-where-did-dns-go/SOLUTION.md) | [README](challenge-end-state/challenges/a1-where-did-dns-go/README.md) | [A1](FEASIBILITY.md#a1--where-did-dns-go) |
| A2 | [Fast yesterday, slow today](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/a2-fast-yesterday-slow-today/README.md) | [SOLUTION](challenge-end-state/challenges/a2-fast-yesterday-slow-today/SOLUTION.md) | [README](challenge-end-state/challenges/a2-fast-yesterday-slow-today/README.md) | [A2](FEASIBILITY.md#a2--fast-yesterday-slow-today) |
| A3 | [Ready for maintenance?](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/a3-ready-for-maintenance/README.md) | [SOLUTION](challenge-end-state/challenges/a3-ready-for-maintenance/SOLUTION.md) | [README](challenge-end-state/challenges/a3-ready-for-maintenance/README.md) | [A3](FEASIBILITY.md#a3--ready-for-maintenance) |
| A4 | [Identity without secrets](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/a4-identity-without-secrets/README.md) | [SOLUTION](challenge-end-state/challenges/a4-identity-without-secrets/SOLUTION.md) | [README](challenge-end-state/challenges/a4-identity-without-secrets/README.md) | [A4](FEASIBILITY.md#a4--identity-without-secrets) |
| A5 | [Running is not ready](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/a5-running-is-not-ready/README.md) | [SOLUTION](challenge-end-state/challenges/a5-running-is-not-ready/SOLUTION.md) | [README](challenge-end-state/challenges/a5-running-is-not-ready/README.md) | [A5](FEASIBILITY.md#a5--running-is-not-ready) |
| A6 | [The data survived, the application didn't](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/challenges/a6-data-survived-app-didnt/README.md) | [SOLUTION](challenge-end-state/challenges/a6-data-survived-app-didnt/SOLUTION.md) | [README](challenge-end-state/challenges/a6-data-survived-app-didnt/README.md) | [A6](FEASIBILITY.md#a6--the-data-survived-the-application-didnt) |

## Set up: clone both repositories side by side

The scripts here use the lab repository's shared libraries (the bash library, the PowerShell module, the Terraform
modules, and the scoring code), from a clone next to this one:

```bash
mkdir kubecon-ctf && cd kubecon-ctf
git clone https://github.com/bbenz/kubecon26-pre-day-lab
git clone https://github.com/bbenz/kubecon26-pre-day-lab-instructors
```

The bash and PowerShell scripts look for `../kubecon26-pre-day-lab` from this repository's root; set `CTF_LAB_REPO`
(or pass `-LabRepo` in PowerShell) for another location. The end-state Terraform module needs the folder name
`kubecon26-pre-day-lab` next to this repository.

Commands in the SOLUTION files run from the lab repository's root (`scoring/...`, `begin-challenge/...`), except paths
that start with `challenge-end-state/`, which are in this repository.

## Repository layout

```text
challenge-end-state/        the challenges solved: deploy scripts (bash, PowerShell, Terraform) and, per challenge,
  challenges/<id>-*/        SOLUTION.md (walkthrough), README.md (what changes), and the solved manifests/
delivery/                   RUN-OF-SHOW.md and PROCTOR-GUIDE.md, for the day of delivery
leaderboard/                the optional projected leaderboard: setup, board, cleanup, and its Skillable LCA
skillable/                  runbooks for the Skillable deployment (the scripts are in the lab repository)
docs/testing.md             how the lab was tested: static checks, kind, Azure
docs/participant-permissions.md   what each challenge needs an attendee to be allowed to do
docs/scoring-checks.md      what each challenge's check looks at (an answer key: keep it here)
tests/leaderboard/          demo players for a leaderboard rehearsal
FEASIBILITY.md              assessments, recommended line-up, timing plan, and each challenge's evaluation notes
```

## Deploy the end state

For a debrief demo, to compare broken and fixed side by side, or to validate the scoring: see
[challenge-end-state/README.md](challenge-end-state/README.md). From this repository's root:

```powershell
./challenge-end-state/azure-cli-powershell/deploy.ps1 -ResourceGroup rg-<alias>-ctf-end
# Solve an existing begin-state environment in place, for one challenge:
./challenge-end-state/azure-cli-powershell/deploy.ps1 -ResourceGroup rg-<alias>-ctf -ClusterName aks-<alias>-ctf -Challenges c1
```

Then, from the lab repository's root, `./scoring/verify.ps1 -Context <cluster>`: every challenge should pass.

## Keep the two repositories in step

- **Attendee-facing changes go to the lab repository:** a challenge's README, manifests, and checks, the deploy
  scripts, and the Skillable scripts. After you change a challenge's README, run `./skillable/build-lab-steps.ps1`
  there to update the Skillable lab instructions.
- **Instructor-only changes go here:** the challenge's SOLUTION.md, its end-state README and manifests, and its notes
  in FEASIBILITY.md and the proctor guide.
- **Before you commit in the lab repository**, run `./skillable/build-lab-steps.ps1 -Check`. It fails if the lab
  instructions are out of date, or if the lab repository has instructor-only content: a SOLUTION.md, FEASIBILITY.md,
  challenge-end-state, the leaderboard's setup, a feasibility section, or a link to any of them.
- **For the event**, tag the lab repository (such as `v1.0.0`), set the prepare LCA's `RepoRef` to the tag, and import
  the lab instructions generated from the same commit.

## Publish the lab repository without its old history

Until 2026-11-04, the lab repository also had this repository's content, and its history on GitHub still does:
anyone can open an earlier commit and read the solutions. The lab VMs are safe either way, because they get a shallow
clone (one commit, no history), and their readiness gate fails if it finds solution content in the clone's files or
history. To take the solutions out of the public history too, publish the lab repository again with a single,
clean commit:

1. Optional: keep the old history in this private repository, from your clone of the lab repository:
   `git push <this repository's URL> main:archive/lab-repository-history`.
2. In the lab repository, make a new history with one commit of the current files:

    ```bash
    git checkout --orphan clean-main
    git commit -m "KubeCon AKS capture-the-flag lab"
    git branch -M clean-main main
    ```

3. On GitHub, delete `bbenz/kubecon26-pre-day-lab` (**Settings** > **Danger Zone**), and create it again, public and
   empty, with the same name, so that <https://aka.ms/kubecon26-pre-day-lab> keeps working. A force push alone isn't
   enough: GitHub keeps old commits reachable for a while, by their IDs and in forks.
4. `git push -u origin main`, and tag the event's release on the new history.

Everyone who cloned or forked the lab repository before keeps the old history, with the solutions. Ask team members to
clone it again.

## Local files that aren't in git

`.lab/` (ignored by git): the leaderboard's settings and token (`.lab/leaderboard/`), the shared model's endpoint
and key (`.lab/skillable/model.json`), and archived Terraform state (`.lab/archive/`). Never commit them.
