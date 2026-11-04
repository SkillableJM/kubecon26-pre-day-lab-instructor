# Feasibility assessment – KubeCon AKS capture-the-flag lab

Evaluation of the ten candidate challenges from *AKS Capture the Flag Lab Approach and Azure Requirements – v2*
(C1–C4 proposed core, A1–A6 alternates). The question for each one: can it be **built reliably** on AKS Automatic,
and can a participant with **200-level** Kubernetes/Azure knowledge **finish it within the round** with minimal
friction? This page summarises the assessments; each challenge's detailed assessment is at the end, in
[Per-challenge assessments](#per-challenge-assessments).

> **Status (2026-10-14):** code complete for all ten challenges in three deployment approaches (Azure CLI bash,
> Azure CLI PowerShell, Terraform), and **piloted on Azure**: the BEGIN state was deployed with PowerShell (re-run
> with bash) and the END state with Terraform, both on AKS Automatic 1.35 in westus3. Every challenge fails as
> designed in the begin state and passes in the end state; the pilot found and fixed several platform behaviours
> (see *Platform findings* and *Pilot gates* below), including a redesign of C4's fault and of A1's expected fix.
>
> **Update (2026-11-03):** after team feedback, **C2** became an Ingress-NGINX → Gateway API migration (application
> routing add-on, `ingress2gateway`, AI-assisted) and **A2** now uses the Managed Prometheus dashboards; both were
> re-validated on Azure (AKS Automatic 1.36) – see *Changes after the team review* below.

## Summary

| ID | Challenge | Built reliably on AKS Automatic? | 200-level fit | Expected time (design) | Main risk | Validated | Opinion |
|---|---|---|---|---|---|---|---|
| **C1** | The store won't start | **High** – deterministic crash, no Azure deps | Good | 10–15 (15–20) | Low | Local ✔ · Azure ✔ | **Keep – round 1** |
| **C2** | Move the storefront to Gateway API | **High** – managed NGINX and Gateway API side by side; `ingress2gateway` + 3 adaptations; DNS cutover in ~20 s | Good (guided migration; new Gateway API vocabulary) | 25–30 (20–25) | NGINX support window ends Nov 2026; participants need `ingress2gateway` and an AI assistant; DNS negative caching | Azure ✔ | **Keep – round 2** |
| **C3** | Capacity that never arrives | **Medium–high** – deterministic; NAP launched the fixed pool's node ~1 min after the fix | Stretch (Karpenter + VM naming) | 20–30 (20–25) | Karpenter's pod event is misleading; knowledge gap; SKU restrictions | Azure ✔ | **Advanced bonus; A2 in its core slot** |
| **C4** | The AI assistant is up, but not working | **High** – single fault, Entra auth (fault redesigned in the pilot) | Good | 10–20 (20–25) | Model quota/availability per subscription | Azure ✔ | **Keep – round 4**; fallback A4 |
| **A1** | Where did DNS go? | **Medium–high** – deterministic, but the textbook fix fails on AKS Automatic | Medium-low (medium with hint 4) | 20–30 (20–25) | LocalDNS + Cilium `host` entity defeat the classic rules | Local ✔ · Azure ✔ | Advanced alternate only |
| **A2** | Fast yesterday, slow today | **High** – p95 2.6 s (begin) vs 0.19 s (end) with background traffic; throttling visible in Managed Prometheus | Good | 20–25 (20–25) | Metric delay 1–3 min; dashboard access needs read on the Azure Monitor workspace data | Local ✔ · Azure ✔ | **Strong alternate – first substitute for C3** |
| **A3** | Ready for maintenance? | **High** – PDBs untouched by safeguards | Good (slightly easy) | 10–15 (20–25) | Low | Local ✔ · Azure ✔ | Reserve / easy round |
| **A4** | Identity without secrets | **High** – clear AADSTS700213 evidence | Medium | 15–20 (20–25) | Student needs Azure rights on the identity | Azure ✔ | **Swap-in for C4** |
| **A5** | Running is not ready | **High** – 144 failed requests (begin) vs 0 (end) | Very good | 15–20 (15–20) | Low | Local ✔ · Azure ✔ | **Strong alternate** (great for 200-level) |
| **A6** | The data survived, the application didn't | **High** | Good (slightly easy) | 10–15 + attach (20–25) | Low | Local ✔ · Azure ✔ | Reserve |

Times are investigation minutes (excluding briefing, debrief and reset); the design target from the document is in
parentheses.

## Recommended line-up (four rounds, 200-level audience)

1. **C1 – The store won't start** (warm-up: logs, ConfigMaps, rollouts)
2. **C2 – Move the storefront to Gateway API** (Ingress-NGINX → Gateway API with `ingress2gateway` and AI – topical
   after the Ingress-NGINX retirement, and a showcase for the application routing add-on)
3. **A2 – Fast yesterday, slow today** in place of C3 (measurable, deterministic, Managed Prometheus dashboards);
   keep **C3** as an *advanced bonus*
   for fast finishers (its pilot is technically clean, but Karpenter vocabulary and its misleading pod event make it
   a stretch for 200-level)
4. **C4 – The AI assistant is up, but not working** (AI dependency); fallback **A4** if per-subscription model access
   is a problem

Reserves: **A5** (best substitute for any round), A3, A6. A1 works on AKS Automatic, but the familiar NetworkPolicy
fix doesn't (LocalDNS + Cilium) – use it for an advanced group or release its hint 4 early.

### Timing plan (3 hours)

| Block | Minutes |
|---|---|
| Welcome, environment access, `kubectl` context check | 15 |
| Round 1 – brief 5 · work 20 · debrief 8 | 33 |
| Round 2 – brief 5 · work 25 · debrief 8 | 38 |
| Break | 10 |
| Round 3 – brief 5 · work 25 · debrief 8 | 38 |
| Round 4 – brief 5 · work 25 · debrief 8 | 38 |
| Wrap-up, scores, prizes | 8 |
| **Total** | **180** |

All challenges are pre-deployed side by side in separate namespaces of one cluster per attendee, so rounds are
independent: no rebuild between rounds, and participants can move on even if they didn't finish (review comments
C3/C4). Each challenge resets on its own (re-run the begin-state deploy for that ID).

## Platform findings that affect every challenge

| Finding | Impact | How the code handles it |
|---|---|---|
| **Deployment safeguards are enforced and can't be lowered on Automatic**: probes required (deny), CPU/memory floors 100m/100Mi (mutate), anti-affinity for replicas > 1 (mutate), `:latest` denied. PDBs are **not** checked. | Faults must not be "auto-fixed" or blocked by policy (review comment C5). | Every container sets probes and explicit resources; A2's fault sits exactly at the 100m floor; multi-replica workloads pre-set topology spread. No challenge relies on something safeguards rewrite. |
| **Safeguards vs. ad-hoc debugging (verified):** a bare `kubectl run` pod is **denied** (no resource requests; missing probes only warn); `kubectl debug --profile=general` is **denied** by AKS's baseline policy (`SYS_PTRACE`). `kubectl debug <pod> --profile=baseline` (or `restricted`) and `kubectl run ... --overrides` with resource requests work. Every apply prints "anti-affinity and topology spread constraints added" warnings. | Participants reaching for a debug pod hit a wall. | Walkthroughs use `kubectl exec` into existing pods; tips in [begin-challenge/README.md](https://github.com/bbenz/kubecon26-pre-day-lab/blob/main/begin-challenge/README.md#troubleshooting-tips-for-aks-automatic) (lab repository). |
| **Managed system node pools + node auto-provisioning** are always on. | No node pools to size; workload nodes appear on demand. | Nothing to configure; C3 uses a dedicated NodePool. Observed footprint per environment: 2–3 NAP nodes (`Standard_D4als_v6`) plus the system-surge node. |
| **Local accounts disabled, Azure RBAC for Kubernetes** – `kubectl` needs *Azure Kubernetes Service RBAC Cluster Admin* (Owner is not enough). | Students and scoring scripts need the data-plane role. | All approaches grant it on the resource group *before* creating the cluster (worked first time; no propagation wait). |
| **LocalDNS on by default** (pods resolve via `169.254.10.11`, `serveStale: Immediate` for 1 h). Cilium treats it as the `host` entity. | A1's classic fixes don't apply; after a Service is re-created (challenge reset) the first lookup on a node can return its **old** IP – nginx front ends kept proxying to a dead address (HTTP 504). | A1 redesigned (see its assessment below); `warm-dns-cache` init container in store-front/store-admin. |
| **Gateway API is on by default only for Automatic ≥ 1.36**; clusters created earlier (1.35 was the default in October) don't have it. | C2 needs the managed CRDs and the `approuting-istio` class. | Enabled explicitly in all approaches (`--enable-gateway-api --enable-app-routing-istio` / azapi `ingressProfile`). |
| **Application routing NGINX:** enabling it is allowed, but Microsoft-supported security patches end in **November 2026** (the event month). The gateway names its Deployment/Service `<gateway>-approuting-istio`, so a Gateway named after the IngressClass (as `ingress2gateway` does) is never programmed. | C2's migration source could stop being deployable; the tool's draft needs adapting. | All approaches enable NGINX explicitly (`--enable-app-routing` / `az aks approuting enable` / azapi `webAppRouting`); re-check before the event. The adaptation is part of the challenge (hint 2). |
| **Foundry (`AIServices`) accounts answer requests addressed to a bare model name**, even for models that aren't deployed. | C4's original fault (model name instead of deployment name) didn't reproduce. | C4 now starts with a retired deployment name; scoring requires the provisioned deployment. |
| **Regional SKU restrictions differ per subscription** (the test subscription can't use v5/v6 x64 sizes in eastus2). | NAP picks from what's allowed; C3's fix must name allowed sizes. | Default region westus3; C3 end state spans v5/v6/v7. Check Skillable subscriptions the same way (`az vm list-skus`). |
| **`az aks create --sku automatic` (CLI)**: sends `~/.ssh/id_rsa.pub` when present (rejected for hosted system pools) and turns on Container Insights and Managed Prometheus itself – by default with workspaces in `DefaultResourceGroup-<region>`, outside the lab RG. The Terraform (azapi) cluster gets no monitoring unless the data collection resources are declared. | First CLI deployment failed; extra RG to clean up; monitoring differed by approach. | `--no-ssh-key` added. Since 2026-11-03 the CLI deployments pass lab-RG workspaces (`amw-ctf-<id>`, `law-ctf-<id>`) and Terraform declares Managed Prometheus (workspace, DCE/DCR/DCRA, recording rules) – A2 uses it in every approach. |
| **Viewing Managed Prometheus data** (portal dashboards, Prometheus explorer) needs read access to the Azure Monitor workspace's data. A subscription Owner (via group, no extra role) could query it; the documented role for narrower access is *Monitoring Data Reader* on the workspace. | A Skillable lab user with a restricted role may see no data. | Documented in A2 and the prerequisites; `kubectl top` and `/stats` remain as fallbacks. |
| **Images**: store v2.2.0 from GHCR, fixtures on MCR Azure Linux images; RabbitMQ 4.x only on Docker Hub. | Anonymous Docker Hub pulls (3 per environment). | Acceptable for testing; for Skillable consider importing to ACR. |
| **Store demo `order-service` doesn't reconnect to RabbitMQ** when RabbitMQ is rescheduled after it (node auto-upgrade, NAP consolidation). Orders then hang – the storefront returns HTTP 504 on `POST /api/orders` – while `/health` stays green. Seen on the long-running end environment (2026-11-03) after the 30 Oct auto-upgrade, and NAP consolidation moved pods again during testing. | C1's order check (and any manual order in C2/C4) can fail hours after a correct fix, through no fault of the participant. | Workaround: `kubectl rollout restart deployment/order-service -n <namespace>`. **Open:** consider `karpenter.sh/do-not-disrupt: "true"` on the RabbitMQ and order-service pods for the event, or a check that restarts order-service when its broker moves. |
| **`aks-preview` extension** (installed on the test workstation) overrides `az aks` with preview behaviour. | Possible preview-only errors. | Scripts bypass extensions for `az aks create/update`. |

## Pilot gates – results of the first Azure deployment (2026-10-14, westus3, AKS Automatic 1.35.8)

- [x] **AKS Automatic creation** (hosted system pool, Gateway API, App Routing Istio): Terraform/azapi 9m44s; CLI
  ~10 min plus ~1.5–5 min of client-side monitoring setup. CLI needed `--no-ssh-key` (fixed). Whole environment
  (cluster + Azure services + ten challenges): ~15–20 min per approach.
- [x] **Safeguards**: every challenge workload accepted. Bare `kubectl run` pods are denied (no resource requests);
  `kubectl debug` works with `--profile=baseline`/`restricted` – documented as participant tips.
- [x] **C2** (the original "broken route" version, replaced on 2026-11-03): gateway IP + DNS label work; the Istio
  controller reports the bad route as `Accepted`/`ResolvedRefs=True`; gateway answers HTTP 500 (`server: istio-envoy`);
  access log shows `cluster_not_found` / `NC`.
- [x] **C3**: begin – NodePool `READY=True`, event `NoCompatibleInstanceTypes`; pod events from the scheduler and a
  misleading Karpenter hint (`label "kubecon.lab/pool" does not have known values (typo of "karpenter.sh/nodepool"?)`).
  End – node launched and batch finished ~2 min after the fix. The finished pod disappears with its node after
  `consolidateAfter` (10 min); scoring handles it.
- [x] **C4**: end-to-end call with `gpt-6-luna` and API version `2024-12-01-preview` works; no role propagation wait.
  **Original fault invalid** (model names resolve) → redesigned to a retired deployment name.
- [x] **A1**: the seeded policy blocks DNS; the original end-state rule did **not** restore it (LocalDNS = Cilium
  `host` entity) → end state changed to a port-only DNS rule; `CiliumNetworkPolicy` `toEntities: [host]` documented as
  the least-privilege option. Both verified.
- [x] **A2**: begin p95 ≈ 1.7 s, end p95 ≈ 175–185 ms on `Standard_D4als_v6` – the 300 ms objective needs no change.
- [x] **A4**: `invalid_client: AADSTS700213 ... subject 'system:serviceaccount:a4-config:config-reader'`; end state reads
  the secret; negative test holds.
- [x] **A6**: seed Job including disk provisioning ~1.5 min; records-api Ready 21 s after the fix.
- [x] **Footprint**: 2–3 NAP nodes (`Standard_D4als_v6`) + 1 system-surge node per environment (managed system pool
  not counted), plus a transient C3 node.
- [ ] Skillable: repeat the region/SKU/model-quota checks for the Skillable subscriptions. The lab now stays inside
  one resource group with every approach (CLI monitoring workspaces moved into the lab RG on 2026-11-03).

## Changes after the team review (2026-11-03)

Pilot feedback: the challenges were good Kubernetes troubleshooting but showed little of AKS itself. Suggested and
implemented:

| Change | What was built | Azure validation (westus3, AKS Automatic 1.36.4) |
|---|---|---|
| **C2 → Ingress-NGINX to Gateway API migration** with the application routing add-on, `ingress2gateway` (Kubernetes SIG Network) and an AI assistant | Begin: the storefront behind an Ingress on the add-on's managed NGINX; the public name reserved but unpublished. End: Gateway `store-gateway` (`approuting-istio`) + HTTPRoute, DNS label on the gateway, Ingress removed. New scoring discovers participant-named objects and checks DNS cutover and decommissioning. | Full participant walkthrough on the begin environment: translation (live cluster and `--input-file`), both draft pitfalls reproduced (unchanged draft: "Waiting for controller"; dotted name: `AddressNotUsable`), gateway programmed in 16 s, public DNS pointing at the gateway 18 s after the cutover (a resolver that had cached the earlier NXDOMAIN needed ~5 min), 6/9 → 8/9 → 9/9 checks along the way, bash and PowerShell scorers identical. Begin state re-deployed with bash and PowerShell (NOT PASSED); end-state PowerShell script applied in place (prunes the Ingress) → 9/9; Terraform end state (in-place cluster update) → 9/9. |
| **Application routing add-on (managed NGINX)** enabled in all approaches | `--enable-app-routing` on create; `az aks approuting enable` for existing clusters; azapi `webAppRouting.nginx`. | Enabled on the existing begin cluster (≈ 4 min). **Fresh create** in a temporary resource group with every new flag (PowerShell script) succeeded: NGINX, `approuting-istio`, Managed Prometheus and Container Insights all reporting to workspaces in the lab RG, nothing new in `DefaultResourceGroup-westus3`; C2/A2 begin state as expected; the bash cleanup removed it. |
| **A2 → Managed Prometheus dashboards** instead of only `kubectl top` | Steady background traffic (~1 checkout/s) from `loadgen`; README/SOLUTION lead with *Dashboards with Grafana*; Terraform now declares Managed Prometheus; CLI keeps the workspace in the lab RG. | Begin: `kubectl top` 27m vs 62% of CPU periods throttled in Prometheus (82% on the fresh cluster); load test p95 2.3–2.6 s (FAIL). End: p95 158–187 ms (PASS) and 0% throttled between tests (Terraform environment). PromQL confirmed the throttling/usage series and the recording rules the dashboard panels use in all three workspaces (CLI default, CLI lab-RG, Terraform). The portal dashboard layout itself still needs a visual check by a reviewer. |

Not changed (noted for a follow-up): C1 feedback – participants without Fastify knowledge may not connect
`FASTIFY_ADDRESS` with the port, and `last-applied-configuration` shows only the current (broken) value, not a
"last known good" one.

**Leaderboard (added 2026-11-03).** An optional projected leaderboard: `scoring/verify.*` on a lab VM registered by a
Skillable life cycle action records each result in a locked-down storage account (create-only token, no anonymous
access, no account keys); the instructor's laptop reads it with an Entra sign-in. Attendees need no Azure role, only
outbound HTTPS to the storage account – confirm that egress in the Skillable pilot. See
[leaderboard/README.md](leaderboard/README.md).

## Method

* Requirements and review comments from the design document (pricing sections ignored as instructed).
* Platform facts researched from Microsoft Learn, the Azure CLI/REST specs, Karpenter and aks-store-demo sources;
  key behaviours reproduced locally (Docker, kind with an enforcing CNI).
* Each challenge implemented with begin/end manifests, three deployment approaches and automated scoring
  (`scoring/verify.*`) that encodes the success criteria from the document, including the "what doesn't count"
  bypasses.

## Per-challenge assessments

The evaluation notes from each challenge, moved here from the challenges' README files when the lab repository
became attendee-only.

### C1 · The store won't start

Design document: Proposed core, round 1 · Foundational; investigation time 15–20 minutes (design target). Solution:
[challenge-end-state/challenges/c1-the-store-wont-start/SOLUTION.md](challenge-end-state/challenges/c1-the-store-wont-start/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **High.** The fault is deterministic: `FASTIFY_ADDRESS: "0.0.0.0:3000"` (a host:port typed into a host-only setting) makes `order-service` exit with `getaddrinfo ENOTFOUND 0.0.0.0:3000` within seconds of connecting to RabbitMQ → `CrashLoopBackOff`. Verified with the real 2.2.0 image in Docker and on a local Kubernetes 1.37 cluster. No Azure dependency beyond the cluster; AKS Automatic deployment safeguards do not interfere (probes and resources are set explicitly). |
| **Validation status** | Fault + fix + scoring validated locally (kind) with all three deployment approaches and **on AKS Automatic 1.35 (westus3, 2026-10-14)**: begin state `CrashLoopBackOff` with the same `ENOTFOUND` error, synthetic order through the storefront fails; end state passes 6/6. A challenge reset re-creates Services, so the storefront's nginx gets a `warm-dns-cache` init container (LocalDNS can return a Service's old IP right after a reset). |
| **Fit for 200-level users** | Good. The path uses core skills (`get pods`, `describe`, `logs --previous`, ConfigMap, `rollout restart`). Two small traps keep it interesting: the log ends with unrelated `npm notice` lines, and a ConfigMap change needs a restart to take effect. |
| **Expected time** | 10–15 min typical, up to 20 min for slower participants → fits the 15–20 min window. |
| **Risks** | Low. Participants may "fix" with `kubectl set env` (scoring flags it as a temporary override). Removing the setting from the ConfigMap also works (fastify-cli then listens on all interfaces – verified on containerd) and is accepted. Docker Hub pull for RabbitMQ 4.x (not on the MCR mirror) – negligible per cluster. |
| **Opinion** | **Keep as round 1.** Ideal warm-up: realistic, quick to explain, and it exercises the troubleshooting loop every later round relies on. |

### C2 · Move the storefront to Gateway API

Design document: Proposed core, round 2 · Intermediate; investigation time 25–30 minutes (design target). Solution:
[challenge-end-state/challenges/c2-ingress-nginx-to-gateway-api/SOLUTION.md](challenge-end-state/challenges/c2-ingress-nginx-to-gateway-api/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **High.** Everything is managed by AKS: the application routing add-on's NGINX (still enabled by `--enable-app-routing` / `az aks approuting enable`) and its Istio-based Gateway API implementation (GatewayClass `approuting-istio`, GA) run side by side, each with its own public IP – exactly the side-by-side pattern of the AKS "Migrate from Ingress-NGINX to Gateway API" guide. `ingress2gateway` v1.2.0 (ingress-nginx provider) translates the Ingress and its annotation; three adaptations are needed: the ingress-class flag, GatewayClass `approuting-istio` and a DNS-label-safe Gateway name. The cutover is a single annotation (`spec.infrastructure.annotations`); Azure's DNS answers have a 10-second TTL. |
| **Validation status** | See [docs/testing.md](docs/testing.md) for the Azure walkthrough (translation, adaptation, side-by-side test, DNS cutover, decommissioning) and the end-state deployment. |
| **Fit for 200-level users** | Good. A guided, realistic workflow instead of a hidden fault; the tool's three gaps make the "AI drafts, you verify" lesson concrete without being obscure. Gateway API vocabulary is new to many – the hints name each object. Very topical for KubeCon (Ingress-NGINX retirement) and it shows off AKS features (application routing, managed Gateway API) rather than only kubectl. |
| **Expected time** | 25–30 min: tool install 2–3 min (pre-install it on lab VMs), translate and adapt ~10 min, gateway provisioning 1–3 min (a new NAP node can add 1–3 min), validation and cutover ~5 min. |
| **Risks** | (1) **NGINX support window:** Microsoft-supported patches for the add-on's NGINX end in November 2026 – the month of the event. Re-check before the event that `--enable-app-routing` still deploys NGINX on new clusters; fallback: keep the Ingress (it is just YAML) and translate it offline with `--input-file`, dropping the "today's path" test. (2) Participants need `ingress2gateway` and access to an AI assistant (GitHub Copilot Free needs a GitHub account; Copilot in Azure needs the lab tenant to allow it). (3) DNS: negative caching (up to 5 min) if the name is looked up before the cutover; browsers that try HTTPS first. (4) A reset deletes the participant's gateway and its IP. |
| **Opinion** | **Keep as core round 2 – stronger than the previous "broken route" version.** It answers the pilot feedback (show AKS features, not only Kubernetes troubleshooting), uses the free CNCF tooling plus AI in a realistic way, and every step is observable and verifiable. |

### C3 · Capacity that never arrives

Design document: Proposed core, round 3 (recommended as an advanced bonus) · Intermediate–advanced; investigation time 20–25 minutes, including 1–5 minutes of node provisioning after the fix (design target). Solution:
[challenge-end-state/challenges/c3-capacity-that-never-arrives/SOLUTION.md](challenge-end-state/challenges/c3-capacity-that-never-arrives/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **Medium–high – validated on Azure (2026-10-14).** Custom NAP NodePools (`karpenter.sh/v1`, `AKSNodeClass` `default`) work on AKS Automatic. The seeded fault is self-contradictory *inside* the pool (`kubernetes.io/arch In [amd64]` + an approved SKU list of Arm64 `Dps/Dpds v6` sizes): the NodePool reports `READY=True`, `NODES 0` and the event `NoCompatibleInstanceTypes: NodePool requirements filtered out all compatible available instance types`. Deterministic, never auto-fixed. After the fix NAP launched a `Standard_D4as_v6` node and the batch completed ~2 minutes after the change. |
| **Validation status** | Begin and end state validated on AKS Automatic 1.35 (westus3). Observed pod events: the scheduler's `0/6 nodes are available ...`, a cluster-autoscaler `NotTriggerScaleUp`, and a **misleading Karpenter message** (`label "kubecon.lab/pool" does not have known values (typo of "karpenter.sh/nodepool"?)`) that describes the *other* pools. Regional SKU restrictions matter: the test subscription cannot use v5/v6 x64 sizes in eastus2 (default region is westus3); the end-state SKU list spans v5/v6/v7. |
| **Fit for 200-level users** | **Stretch.** Requires NodePool/Karpenter concepts (requirements, taints vs tolerations, nodeSelector) and Azure VM naming knowledge (`p` = Arm64). The evidence is spread across scheduler events, Karpenter events and the NodePool object, and the Karpenter "typo" suggestion points the wrong way. Hints are essential. |
| **Expected time** | 20–30 min (investigation 15–25 + ~2 min provisioning and batch). Tight for a 20–25 min window. |
| **Risks** | A participant who types a SKU that is restricted in the subscription/region hits a *second* failure; reset needs 2–5 min outside the round; after 10 minutes the finished batch pod disappears with its consolidated node (the Job still shows `Complete`). |
| **Opinion** | **Advanced bonus round** (technically clean, but the riskiest core challenge for a 200-level audience); put **A2** (or A5) in its core slot. |

### C4 · The AI assistant is up, but not working

Design document: Proposed core, round 4 · Intermediate; investigation time 20–25 minutes (design target). Solution:
[challenge-end-state/challenges/c4-ai-assistant-up-but-not-working/SOLUTION.md](challenge-end-state/challenges/c4-ai-assistant-up-but-not-working/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **High – validated on Azure (2026-10-14).** `ai-service` (aks-store-demo 2.2.0) only checks environment variables in `/health`, so the pod stays healthy; with `AZURE_OPENAI_DEPLOYMENT_NAME` still set to the retired deployment `store-assistant-gpt41` (the platform replaced it with `store-assistant`, model `gpt-6-luna` 2026-09-22) every generation call fails with Azure OpenAI's `DeploymentNotFound` (404) and `ai-service` returns an error. Identity, network, model availability and quota stay healthy, so there is a single fault. `ai-service` sends only `temperature=1` (no `max_tokens`), which works with GPT-5/6 reasoning models; the default API version `2024-12-01-preview` works end to end. **Design change from the pilot:** the original fault (the *model* name instead of the deployment name) does not reproduce – Foundry (`AIServices`) accounts now answer requests addressed to a bare model name, even for models that aren't deployed (`gpt-6-sol`, `gpt-5-mini` returned 200). Only names that are neither a deployment nor a model return 404. |
| **Validation status** | Validated on AKS Automatic 1.35 (westus3) with PowerShell, bash and Terraform deployments: begin state fails with `DeploymentNotFound`, the documented fix passes, end state passes. Workload identity + `Cognitive Services OpenAI User` worked immediately after deployment (no propagation retries needed). |
| **Fit for 200-level users** | Good. The evidence is explicit (`DeploymentNotFound` in the logs) and "the app still points at a renamed/retired deployment" is one of the most common real-world Azure OpenAI incidents. Participants need **Reader** access to the Foundry account (or the portal) to list deployments. |
| **Expected time** | 10–20 min. |
| **Risks** | Per-subscription model availability and quota (the test subscription has 10M TPM gpt-6-luna GlobalStandard quota; Skillable subscriptions must be checked); the model must exist in the chosen `AOAI_LOCATION`. Model-name routing means a participant can "fix" it with `gpt-6-luna` – the scoring rejects that (it checks the provisioned deployment name). AI features attract audiences – a strong reason to keep it. |
| **Opinion** | **Keep as round 4.** If model access per subscription is a problem, swap in **A4** (identity) as the doc suggests – it reuses the same workload identity concepts without a model dependency. |

### A1 · Where did DNS go?

Design document: Preferred alternate · Intermediate; investigation time 20–25 minutes (design target). Solution:
[challenge-end-state/challenges/a1-where-did-dns-go/SOLUTION.md](challenge-end-state/challenges/a1-where-did-dns-go/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **Medium-high – validated on Azure (2026-10-14).** The fault is deterministic: default-deny egress + an allow rule for the catalog only → `Temporary failure in name resolution`. **AKS Automatic twist:** pods resolve through LocalDNS (node-local `169.254.10.11`), and Cilium treats that traffic as the `host` entity, so the *textbook* fixes – allow 53 to the `kube-dns` pods, or `ipBlock` 169.254.10.x – **do not work** (verified). Working fixes (both verified): a port-only NetworkPolicy rule (UDP/TCP 53, no destination – the end state) or a `CiliumNetworkPolicy` with `toEntities: [host]` (least privilege). `ledger-api` and the internet stay blocked with either. |
| **Validation status** | Fault, fix and scoring validated locally (bash, PowerShell, Terraform) and on AKS Automatic 1.35 in westus3: begin state fails as designed; both fixes pass. |
| **Fit for 200-level users** | **Medium-low without hint 4, medium with it.** "DNS vs connectivity" is a valuable skill, but on AKS Automatic the first fix most people know fails silently, and the reason (LocalDNS + Cilium `host` entity) is advanced. Hint 4 turns it into a solvable – and memorable – platform lesson. |
| **Expected time** | 20–30 min with hints 1–4 (25+ min if participants try `ipBlock`/kube-dns variations first). |
| **Risks** | Participants burning the round on the textbook rule; facilitators should release hint 4 at ~10 minutes. Inspektor Gadget: its AKS cluster extension (`microsoft.inspektorgadget`, preview) runs its privileged pods on the lab's nodes on AKS Automatic (tested 2026-11-03), but AKS denies them on the AKS-managed hosted system nodes, so the extension can stay in *Creating*, and a full node leaves its pod Pending – keep it optional (the Skillable prepare LCA's `InspektorGadget` setting is off by default). |
| **Opinion** | **Alternate for an advanced round, or with hint 4 released early.** Excellent debrief material (LocalDNS, Cilium entities, DNS as an exfiltration path), but A2 or A5 are smoother substitutes for a 200-level core round. |

### A2 · Fast yesterday, slow today

Design document: Preferred alternate · Intermediate; investigation time 20–25 minutes (design target). Solution:
[challenge-end-state/challenges/a2-fast-yesterday-slow-today/SOLUTION.md](challenge-end-state/challenges/a2-fast-yesterday-slow-today/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **High.** Self-contained fixture (Python on an MCR image, no image build). The 100m CPU limit sits exactly at AKS Automatic's deployment-safeguards floor, so it is **not** auto-raised. Calibrated locally: 100m → p95 ≈ 1.2–1.6 s, 99% of CFS periods throttled (FAIL); 1 CPU → p95 ≈ 107 ms (PASS). Valid fixes: 1 replica at ~1 CPU, or 2 replicas with up to 1 CPU each (2 × 500m is borderline – p95 ≈ 297 ms locally because the Service doesn't spread 4 concurrent requests evenly). A LimitRange enforces the per-container ceiling, so "unlimited" fixes are rejected by the API server. Managed Prometheus is on by default for AKS Automatic clusters created with the Azure CLI or portal; the Terraform deployment adds the same data collection rule and recording rules, and every deployment keeps the Azure Monitor workspace in the lab resource group. The background traffic (~1 checkout/s) keeps the throttling visible on the dashboards between load tests. |
| **Validation status** | Fault, fix and scoring validated locally with bash, PowerShell and Terraform, on AKS Automatic 1.35 (westus3, 2026-10-14), and again **with the background traffic and Managed Prometheus on AKS Automatic 1.36 (westus3, 2026-11-03)**: begin – background checkouts p95 ≈ 175 ms, `kubectl top` ≈ 27m (a quarter of the limit) while ≈ 50–60% of CPU periods are throttled; load test p95 ≈ 2.6 s (48 s run, FAIL; background p95 ≈ 2.6 s meanwhile). End – load test p95 ≈ 186 ms (PASS, 3.8 s run), background p50 ≈ 36 ms. The throttling ratio, CPU usage and the recording rules behind the dashboard panels were confirmed in the Azure Monitor workspace with PromQL. |
| **Fit for 200-level users** | Good. The load test gives an immediate, objective signal; the portal dashboards turn "kubectl top looks fine" into a visible throttling problem – and show off an AKS Automatic default (Managed Prometheus + Dashboards with Grafana) instead of only kubectl. |
| **Expected time** | 20–25 min (test runs: ~40–60 s broken, ~3 s fixed; dashboards lag 1–3 min; a request increase may trigger a 1–3 min NAP node). |
| **Risks** | Metric ingestion delay (1–3 min) – the hints say so and `/stats` is an instant fallback. Viewing the dashboards needs read access to the Azure Monitor workspace data (a Skillable role question). Performance variance across VM sizes (large margin around the objective). |
| **Opinion** | **Strong alternate – recommended as the first substitute for C3** for a 200-level audience: deterministic, measurable, quick to reset, very relevant to day-2 operations, and now a showcase for AKS Automatic's built-in monitoring. |

### A3 · Ready for maintenance?

Design document: Reserve · Intermediate–advanced (no real cluster upgrade); investigation time 20–25 minutes (design target). Solution:
[challenge-end-state/challenges/a3-ready-for-maintenance/SOLUTION.md](challenge-end-state/challenges/a3-ready-for-maintenance/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **High.** AKS Automatic's deployment safeguards do **not** inspect PodDisruptionBudgets, so a one-replica Deployment with `minAvailable: 1` (0 disruptions allowed) stays broken. The in-cluster `maintenance-check` Job uses its own narrowly scoped RBAC to request evictions – no node drains, no real upgrade, nothing that affects other rounds. The app drains gracefully (`preStop`), so the only failure is the one being taught. Safeguards add anti-affinity when replicas > 1; the manifest pre-sets a topology spread so this does not surprise participants. |
| **Validation status** | Fault, fix and scoring validated locally with bash, PowerShell and Terraform (begin: eviction `429`; end: eviction accepted, 0 failed requests) and **on AKS Automatic 1.35 (westus3, 2026-10-14)** with the same results (end: 31 requests, 0 failed during the eviction). |
| **Fit for 200-level users** | Good, slightly easy: the check output names the PDB, and `kubectl get pdb` shows `ALLOWED DISRUPTIONS 0`. The `kubectl create job --from=cronjob` pattern is new to some participants but given in the brief. |
| **Expected time** | 10–15 min – may finish early; use the stretch objective to fill the round. |
| **Risks** | Low. A second replica may need a new NAP node (1–3 min). |
| **Opinion** | **Good reserve / easy round.** Reliable and safe; less depth than the others, so pair it with the stretch discussion about AKS upgrades. |

### A4 · Identity without secrets

Design document: Additional candidate (swap-in for C4) · Intermediate–advanced; investigation time 20–25 minutes (design target). Solution:
[challenge-end-state/challenges/a4-identity-without-secrets/SOLUTION.md](challenge-end-state/challenges/a4-identity-without-secrets/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **Medium–high.** Workload identity and the OIDC issuer are preconfigured on AKS Automatic. The seeded fault is one Azure-side value: the federated credential subject still names the old namespace (`system:serviceaccount:config-legacy:config-reader`). Entra rejects the exchange with `AADSTS700213`/`AADSTS70021` ("No matching federated identity record found for presented assertion subject ...") and the app logs it verbatim. Federated-credential changes propagate in seconds, and the Key Vault role is already in place, so there is a single fault. The secret is written through ARM, so no data-plane role is needed for the deployer. |
| **Validation status** | Validated **on AKS Automatic 1.35 (westus3, 2026-10-14)**: begin – `FAILED at stage 'token-exchange': invalid_client: AADSTS700213: No matching federated identity record found for presented assertion subject 'system:serviceaccount:a4-config:config-reader'`; end (subject `system:serviceaccount:a4-config:config-reader`) – the secret is read with workload identity while `report-generator` stays unauthorized. Terraform plans show the begin vs. end subject. |
| **Fit for 200-level users** | Medium. Workload identity federation is an advanced concept, but the error message contains the presented subject, so comparing it with the credential is straightforward. Participants need Azure permissions to edit the identity (resource-group Contributor or Managed Identity Contributor) – plan this for Skillable. |
| **Expected time** | 15–20 min. |
| **Risks** | Azure-side permission model for students; occasional RBAC propagation delay on a fresh environment (the app retries every 20 s). |
| **Opinion** | **Good swap-in for C4** (same "Azure dependency" learning without model quota), or a strong alternate for security-focused audiences. |

### A5 · Running is not ready

Design document: Additional candidate (lower dependency) · Foundational–intermediate; investigation time 15–20 minutes (design target). Solution:
[challenge-end-state/challenges/a5-running-is-not-ready/SOLUTION.md](challenge-end-state/challenges/a5-running-is-not-ready/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **High.** Deterministic 20 s warm-up, a readiness probe on `/healthz` (passes immediately) and `maxUnavailable: 1` make every rollout fail customer requests. Locally: 172 of 342 requests failed (HTTP 503) during an 8 s rollout. After the fix (`/ready` + `maxUnavailable: 0`): 1,521 ok / 0 failed in a 70 s rollout. AKS Automatic safeguards only require probes to *exist*, so they don't fix the fault. The app drains gracefully on SIGTERM, so the only failure source is readiness. |
| **Validation status** | Fault, fix and scoring validated locally with bash, PowerShell and Terraform, and **on AKS Automatic 1.35 (westus3, 2026-10-14)**: begin – 144 of 308 customer requests failed (HTTP 503) during a 6 s rollout; end – 1,535 ok / 0 failed during a 69 s rollout. |
| **Fit for 200-level users** | Very good – one of the best "concept" rounds: the test gives an objective signal, and the fix is a small, well-explained change. |
| **Expected time** | 15–20 min (each test run ~10–90 s). |
| **Risks** | Low. If replicas land on a new NAP node the first rollout is slower (image pull), still well within the 240 s timeout. |
| **Opinion** | **Strong alternate; recommended for a less experienced audience** or as the substitute when an Azure dependency (C3/C4) fails its pilot. |

### A6 · The data survived, the application didn't

Design document: Additional candidate (timing risk) · Intermediate; investigation time 20–25 minutes (design target). Solution:
[challenge-end-state/challenges/a6-data-survived-app-didnt/SOLUTION.md](challenge-end-state/challenges/a6-data-survived-app-didnt/SOLUTION.md).

| Aspect | Assessment |
|---|---|
| **Technical feasibility** | **High (Kubernetes) / medium (timing on Azure).** The Deployment references a non-existent claim → pod `Pending` with `persistentvolumeclaim "records-data-v2" not found`. The original claim, disk and seeded data stay intact (the seed Job runs in a setup phase *before* the app is deployed, so there is no attach race). The readiness probe checks dataset presence and checksum, so the "new empty volume" bypass visibly fails. Deployment strategy `Recreate` avoids two pods fighting over the RWO disk. |
| **Validation status** | Fault, fix and scoring validated locally with bash, PowerShell and Terraform (local-path storage) and **on AKS Automatic 1.35 (westus3, 2026-10-14)** with Azure Disk (`managed-csi`): the seed Job including disk provisioning took ~1.5 min at deploy time; after the fix `records-api` was Ready 21 s after creation and served the 500 records with an unchanged checksum. |
| **Fit for 200-level users** | Good – the event names the missing claim directly; PVC/PV basics are core knowledge. The interesting part is resisting the "just create the missing PVC" reflex. |
| **Expected time** | 10–15 min + 1–3 min attach/scheduling → may finish early. |
| **Risks** | Zonal disk + node placement latency; transient `Multi-Attach` events if the app lands on a different node from the (completed) seed pod while Azure detaches the disk – resolves on its own within ~1 min. |
| **Opinion** | **Reserve.** Reliable and safe, but somewhat easy and the waiting time is mostly attach latency; use it if a storage topic is wanted. |
