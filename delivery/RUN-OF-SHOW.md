# Run of show

> **Confidential.** For the lab's instructors and proctors.

The plan for delivering the lab: who does what, the 3-hour timeline, the checklists from a week before to after the
event, and what to do when something goes wrong. The challenge-by-challenge details are in the
[proctor guide](PROCTOR-GUIDE.md).

## Roles

| Role | Does |
| --- | --- |
| **Lead instructor** | Welcomes the room, briefs and debriefs each round on the projector, keeps time, and decides on swaps (C3 as a bonus, A4 for C4, a reserve). |
| **Proctors** | Walk the room during rounds. Nudge with questions before giving answers, following the proctor guide's timings, and tell the lead when many attendees are stuck at the same point. Move attendees whose environment doesn't work to a spare. |
| **Skillable contact** | Watches launches and preinstances, and handles platform problems and spares. |
| **Leaderboard operator** (optional) | Runs the board on the projector laptop, and moderates it (see the [leaderboard](../leaderboard/README.md#during-the-event)). Can be the lead instructor. |

Proctors read the proctor guide on their own devices, never on a lab VM.

## Timeline (3 hours)

The [recommended line-up](../FEASIBILITY.md#recommended-line-up-four-rounds-200-level-audience), with the
[timing plan](../FEASIBILITY.md#timing-plan-3-hours). Each round is a 5-minute brief, 20 to 25 minutes of work, and
an 8-minute debrief.

| Starts | Minutes | Block | Notes |
| --- | --- | --- | --- |
| 0:00 | 15 | Welcome, and access to the environments | The welcome talk below. Everyone completes the lab instructions' **Get started** page: portal sign-in, `az login`, `kubectl get nodes`. Proctors move anyone who can't to a spare now. |
| 0:15 | 33 | **Round 1: C1**, The store won't start | Brief 5, work 20, debrief 8. A warm-up: logs, ConfigMaps, rollouts. |
| 0:48 | 38 | **Round 2: C2**, Move the storefront to Gateway API | Brief 5, work 25, debrief 8. Mention Copilot and AKS-MCP in the brief. |
| 1:26 | 10 | Break | Fast finishers can try C3. |
| 1:36 | 38 | **Round 3: A2**, Fast yesterday, slow today | Brief 5, work 25, debrief 8. Show the Grafana dashboards in the brief. C3 for fast finishers. |
| 2:14 | 38 | **Round 4: C4**, The AI assistant is up, but not working | Brief 5, work 25, debrief 8. A4 if C4 can't run. |
| 2:52 | 8 | Wrap-up, scores, and prizes | The leaderboard's final standings; spot-check the winners' flags with a check run. Point attendees to the lab repository to try again at home. |

Every challenge is already deployed in its own namespace, so rounds are independent: attendees who didn't finish a
round start the next one with everyone else, and can come back to it later.

### A round

1. **Brief (5 minutes):** the scenario and what success looks like, in your own words, from the challenge's page.
   Show where the hints and the check command are. Don't hint at the fault.
2. **Work (20 to 25 minutes):** proctors circulate. Call the time at the halfway point and 5 minutes before the end.
   If most of the room is stuck at the same point, tell everyone to open the next hint.
3. **Debrief (8 minutes):** ask someone who captured the flag how they found the fault. Then show the fix on the
   projector (from the proctor guide or the SOLUTION), the wrong turns, and what AKS Automatic did in the challenge.
   Attendees who didn't finish can apply the fix later, or reset the challenge and try again.

## Welcome talk (0:00)

- The format: four rounds, each a broken (or unfinished) system on their own AKS Automatic cluster. A passing check
  captures the flag.
- The lab instructions: **Get started** now, **Tools and tips** for when they need it, **Check your work, or start
  over** for checking and resetting, then a page for each challenge.
- Hints are on each challenge page: try for a few minutes first. Proctors help with questions, not answers.
- Fix the cause, the way you would in production: the checks reject shortcuts such as deleting a policy, removing a
  limit, or switching to keys.
- GitHub Copilot is optional, and needs the attendee's own GitHub account (Copilot Free is enough). It has the
  AKS-MCP server for their cluster. AI drafts, you verify.
- Reset: one command per challenge, 2 to 5 minutes, no confirmation, only the challenge you're working on.
- If the event has a leaderboard: each check records the attendee's first name and last initial; `-NoReport` keeps a
  run off the board.

## Checklists

### A week or more before

- [ ] Confirm the line-up and the swaps in [FEASIBILITY.md](../FEASIBILITY.md).
- [ ] Re-check what the event month can change: the application routing add-on's NGINX can still be enabled (its
      security patches end in November 2026); Gateway API and `approuting-istio` on AKS Automatic; the model for C4
      (`gpt-6-luna`, `GlobalStandard`) and its quota in the Skillable subscriptions' region, or in westus3 if that
      region offers no OpenAI models, as westcentralus doesn't; and C3's VM sizes in that region (`az vm list-skus`).
- [ ] In the lab repository: `./skillable/build-lab-steps.ps1 -Check` passes, and the lab instructions are imported
      from the same commit. Tag the commit for the event (such as `v1.0.0`), and set the prepare LCA's `RepoRef` to
      the tag (a pool admin saves it: [the LCA runbook](../skillable/LCA-RUNBOOK.md)).
- [ ] The VM image is built from the current image script, and captured ([the VM image runbook](../skillable/VM-IMAGE-RUNBOOK.md)).
- [ ] A test launch's setup log passes ([Logs and results](../skillable/LCA-RUNBOOK.md#logs-and-results));
      `verify.ps1 -Challenges c1 -Quick -NoReport` shows **NOT PASSED**;
      a reset of C1 works as the attendee.
- [ ] Preinstances requested: running, with at least 45 minutes of lead time, for the expected attendance plus
      spares.
- [ ] Proctor dry run: each proctor solves C1, C2, A2, C4, and C3 in a test launch, with the proctor guide.
- [ ] The leaderboard, if used: [set it up, and rehearse it](../leaderboard/README.md#before-the-event).

### The day before

- [ ] A final test launch from the event's lab profile: the setup log, a check, a reset.
- [ ] The leaderboard's token issued for the event (`setup`), and its life cycle action pasted into the lab profile
      again.
- [ ] Optional, for debriefs: your own environment with the begin state, and another with the
      [end state](../challenge-end-state/README.md), to show broken and fixed side by side.
- [ ] The slides: the welcome, one brief and one debrief per round, and the wrap-up.

### On the day, before doors open

- [ ] The projector laptop: the slides, the leaderboard (`board.ps1 -Challenges c1,c2,a2,c4`), and a terminal on
      your debrief environment.
- [ ] Preinstances running, and spares available. Everyone knows how to move an attendee to a spare.
- [ ] Proctors have the proctor guide open on their own devices.

### After the event

- [ ] Announce the winners; then delete the leaderboard with `cleanup`.
- [ ] Check with Skillable that every lab instance and its resources are gone.
- [ ] Delete your debrief environments.
- [ ] Note what went wrong, and what attendees found hard, in this repository, for the next delivery.

## When things go wrong

| Situation | Do |
| --- | --- |
| An attendee's environment doesn't work | Move them to a spare. Don't debug the platform during a round. For later, the VM's setup log has the step that failed: in VS Code, the newest `.lab\skillable\begin-state-<time>.log` in the lab repository. |
| An attendee is stuck in a strange state | The challenge's reset, from **Check your work, or start over** (2 to 5 minutes). |
| C4 fails for the whole room (no model access) | Run A4 as round 4. |
| Most of the room is stuck at the same point | Tell everyone to open the next hint, or give the clue from the proctor guide's **When to nudge** row. |
| The room is fast | C3 as a bonus, then A5, A3, and A6. |
| A round runs long | Shorten its debrief. If you're more than 10 minutes behind, make round 4 an easier challenge (A3 or A6). |
| Orders hang in C1, C2, or C4 after a correct fix | `kubectl rollout restart deployment/order-service -n <namespace>` (the proctor guide's known problems). |
| The leaderboard records junk or an offensive name | Double-click the player to hide them, or delete their records ([moderation](../leaderboard/README.md#during-the-event)). To stop all submissions: `cleanup -RevokeOnly`. |
