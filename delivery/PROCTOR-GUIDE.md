# Proctor guide

> **Confidential.** For the lab's instructors and proctors. Don't share it with attendees, and don't open it on a lab
> VM, where attendees can see the screen.

One cheat sheet per challenge, in the order of the [recommended line-up](../FEASIBILITY.md#recommended-line-up-four-rounds-200-level-audience):
what attendees see, the fault, the path to the fix, when to nudge, the wrong turns you'll see, and what to say in the
debrief. Each challenge's SOLUTION.md has the full walkthrough, with the expected output of every command.

## Before the first round

- **Where attendees work:** VS Code opens the lab repository, `C:\LabFiles\kubecon26-pre-day-lab`. Every challenge
  runs in its own namespace on the attendee's own AKS Automatic cluster, `aks-kubecon-ctf`, and all of them were
  deployed at launch: rounds are independent, and an attendee who didn't finish a round can still start the next.
- **What attendees see:** each challenge has an instructions page in Skillable, with the same text as its README in
  the lab repository, and **Hints** in collapsed sections. Encourage attendees to work for a few minutes before they
  open hints. The **When to nudge** rows below assume a 25-minute round.
- **Check:** each challenge page ends with its check, such as
  `C:\LabFiles\kubecon26-pre-day-lab\scoring\verify.ps1 -Challenges c1`. It shows PASS or FAIL for each criterion,
  then **PASSED** (a captured flag) or **NOT PASSED**. It takes a minute or two, because some checks watch the
  application for 60 seconds. `-Quick` is faster and less strict, and never reaches the leaderboard.
- **Reset:** the **Check your work, or start over** page has the reset command, which deploys one challenge's begin
  state again in 2 to 5 minutes. It doesn't ask for confirmation. For C2 it also deletes the attendee's gateway, for
  C3 the node pool, for A4 it resets the federated credential, and for A6 it re-creates the disk.
- **Commands here are bash**, as in the SOLUTION files. On the lab VM, use Git Bash (the dropdown next to **+** in
  VS Code's terminal panel). Most `kubectl` commands also work unchanged in PowerShell; JSON patches need different
  quoting there.

## Problems that can happen in any round

| What you see | Why | What to do |
| --- | --- | --- |
| `kubectl` asks to sign in, or returns `Forbidden` | The attendee isn't signed in to the Azure CLI, or signed in with another account. AKS Automatic uses Entra ID and Azure RBAC, with no local accounts. | `az login` with the lab account. Then the **Help** section in **Get started** > Task 4: `az aks get-credentials` and `kubelogin convert-kubeconfig -l azurecli`. |
| A `kubectl` command fails with a timeout, such as `TLS handshake timeout` or a webhook timeout | Transient. Seen in testing, mostly soon after the cluster was created, or when the Azure RBAC webhook is slow. | Run it again. |
| `kubectl run` is denied, or `kubectl debug` with the default profile is denied | AKS Automatic's deployment safeguards and baseline pod security | Use `kubectl exec` into the challenge's own pods. `kubectl debug <pod> --profile=baseline` works, and **Tools and tips** has a `kubectl run` that sets resource requests. |
| Every `kubectl apply` prints "anti-affinity and topology spread constraints added" | The safeguards' mutating policy | Expected: ignore it. |
| Orders hang hours after C1 was fixed (`POST /api/orders` returns HTTP 504), or a manual order fails in C2 or C4, while `/health` is green | The store's `order-service` doesn't reconnect when RabbitMQ is rescheduled (node upgrade, NAP consolidation) | `kubectl rollout restart deployment/order-service -n <namespace>`. It isn't the attendee's fault: if C1 passed before, it counts. |
| A challenge is in a state you can't explain | The attendee experimented with it | Reset it, and start the challenge again. |
| A check fails right after a correct fix, and passes when it runs again | Gateways, DNS, rollouts, and new nodes take a minute or two to settle. Seen once in testing: C2 at 8 of 9 checks right after its route was applied again, then 9 of 9. | Wait a minute, and run the check again before you debug. |
| An environment doesn't work at all | The launch had a problem | Move the attendee to a spare environment. Don't debug the platform during a round. |

---

## Round 1 · C1 · The store won't start

[SOLUTION](../challenge-end-state/challenges/c1-the-store-wont-start/SOLUTION.md) · namespace `c1-store` · suggested
time 10 to 15 minutes

| | |
| --- | --- |
| **Attendees see** | The store UI loads, but orders fail. `order-service` is in `CrashLoopBackOff`; everything else is Running. |
| **The fault** | ConfigMap `order-service-configs` has `FASTIFY_ADDRESS: "0.0.0.0:3000"`, a host and port in a host-only setting. Change ticket CHG-1109 ("bind order-service explicitly to port 3000") was implemented in the wrong field. The log shows `getaddrinfo ENOTFOUND 0.0.0.0:3000`. |
| **Path** | `kubectl get pods` → `kubectl logs --previous` (the error is above some `npm notice` lines) → `kubectl describe deployment` (**Environment Variables from**) → the ConfigMap |
| **When to nudge** | 5 minutes: "Which pod isn't ready? What did its *previous* container say?" (hint 2). 10 minutes: "Where does that environment variable come from, and when is it read?" (hint 3). |

**The fix**

```bash
kubectl patch configmap order-service-configs -n c1-store --type merge \
  -p '{"data":{"FASTIFY_ADDRESS":"0.0.0.0","FASTIFY_PORT":"3000"}}'
kubectl rollout restart deployment/order-service -n c1-store
```

Removing `FASTIFY_ADDRESS` from the ConfigMap is also accepted.

**Wrong turns**

- Fixed the ConfigMap, but didn't restart: environment variables are read when a container starts.
- `kubectl set env deployment/order-service FASTIFY_ADDRESS=0.0.0.0`: works until the manifest is deployed again.
  The check fails it: fix the authoritative source.
- `kubectl rollout undo`, or deleting the pod: the pod template isn't the problem, so the crash continues.

**Debrief:** `--previous` for crash loops; read the whole log; configuration comes from somewhere (a ConfigMap,
through `envFrom`) and is read at start; fix the source, not the running copy. Many attendees won't know Fastify:
the clue is in the error, a host name that has a port in it.

---

## Round 2 · C2 · Move the storefront to Gateway API

[SOLUTION](../challenge-end-state/challenges/c2-ingress-nginx-to-gateway-api/SOLUTION.md) · namespace
`c2-storefront` · suggested time 25 to 30 minutes, the longest core round

| | |
| --- | --- |
| **Attendees see** | A working storefront behind an Ingress on the application routing add-on's managed NGINX, and a public name that doesn't resolve yet (NXDOMAIN). The task: migrate to Gateway API with the add-on's `approuting-istio` class, side by side, then cut over DNS, and decommission the Ingress. A guided migration, not a fault to find. |
| **Path** | `ingress2gateway` drafts a Gateway and an HTTPRoute → adapt the draft (with Copilot) → apply it, and validate on the gateway's IP address with `curl --resolve` → publish the DNS label on the gateway → delete the Ingress |
| **When to nudge** | 5 minutes: if `ingress2gateway` says "No resources found", hint 1 (the ingress class flag). 12 minutes: if the Gateway isn't programmed, hint 2. 20 minutes: hint 4, for the cutover. |

**The fix**

```bash
ingress2gateway print --providers=ingress-nginx --namespace c2-storefront \
  --ingress-nginx-ingress-class=webapprouting.kubernetes.azure.com > gateway-draft.yaml
# Adapt it: gatewayClassName approuting-istio; the Gateway's name store-gateway (a DNS label, no dots);
# the HTTPRoute's parentRefs -> store-gateway. Then:
kubectl apply -f adapted.yaml
kubectl wait --for=condition=Programmed gateway/store-gateway -n c2-storefront --timeout=5m
LABEL=$(kubectl get namespace c2-storefront -o jsonpath='{.metadata.annotations.kubecon\.lab/storefront-dns-label}')
kubectl patch gateway store-gateway -n c2-storefront --type merge \
  -p "{\"spec\":{\"infrastructure\":{\"annotations\":{\"service.beta.kubernetes.io/azure-dns-label-name\":\"$LABEL\"}}}}"
kubectl delete ingress storefront -n c2-storefront
```

**Wrong turns**

- Applied the draft unchanged: its `gatewayClassName` is the IngressClass's name, which isn't a GatewayClass, so the
  Gateway stays `PROGRAMMED Unknown` ("Waiting for controller").
- Fixed the class, but kept the Gateway's dotted name: `AddressNotUsable`, because the controller names its Service
  `<gateway>-approuting-istio`, and a Service name can't have dots.
- `nslookup` still says NXDOMAIN after the cutover: the resolver cached the earlier "doesn't exist" answer, for up
  to 5 minutes. `nslookup <host> 8.8.8.8` answers within about 20 seconds.
- `type: LoadBalancer` on `store-front`, or the DNS label on NGINX's Service: bypasses the gateway, and the check
  fails it.
- Deleted the Ingress first: a big-bang outage. It passes once the gateway works, but it's worth a word.
- Left the Ingress in place: the decommissioning check fails.
- The draft's `timeouts.request: 20m0s` (from NGINX's 120-second read timeout): either value passes. What matters is
  that the attendee looked at it.

**Debrief:** The upstream Ingress-NGINX project is retired, and Microsoft-supported security patches for the
add-on's NGINX end in November 2026. Gateway API separates the platform's part (GatewayClass, Gateway) from the
application's (HTTPRoute). Migrate side by side, validate before you change DNS, then decommission. AI drafts, you
verify: `ingress2gateway` and an assistant can both get the draft's two problems wrong.

---

## Round 3 · A2 · Fast yesterday, slow today

[SOLUTION](../challenge-end-state/challenges/a2-fast-yesterday-slow-today/SOLUTION.md) · namespace `a2-checkout` ·
suggested time 20 to 25 minutes

| | |
| --- | --- |
| **Attendees see** | The load test misses its objective: p95 about 2.6 seconds, against 300 ms. `kubectl top` shows a few tens of millicores, so the service looks idle. |
| **The fault** | `checkout-api`'s CPU limit is 100m, the safeguards' minimum: under four concurrent requests, it's throttled in most CPU periods. |
| **Path** | The load test (`kubectl exec -n a2-checkout deploy/loadgen -- python3 /app/loadtest.py`) → `kubectl top` (low) → Managed Prometheus: the **Kubernetes / Compute Resources / Pod** dashboard's **CPU Throttling** panel (or `/stats` and `cpu.stat`) → the limit, against the LimitRange's envelope |
| **When to nudge** | 5 minutes: "Does a few tens of millicores explain a multi-second checkout?" 10 minutes: the throttling panel (hint 2). 15 minutes: compare the limit with the envelope (hint 3). |

**The fix**

```bash
kubectl set resources deployment/checkout-api -n a2-checkout --requests=cpu=500m --limits=cpu=1
# Optional: kubectl scale deployment/checkout-api -n a2-checkout --replicas=2
```

**Wrong turns**

- Removed the limit: outside the envelope; the check requires limits.
- `--limits=cpu=2` or more: the LimitRange rejects it (`maximum cpu usage per Container is 1`).
- Scaled to 4 or more replicas, or an HPA up to 10: outside the envelope (at most 2 replicas).
- Raised only the request: the limit still throttles.
- Two replicas with 500m limits: borderline, because the Service doesn't spread four requests evenly.
- The dashboard shows nothing: Managed Prometheus data takes 1 to 3 minutes. Use `kubectl top` and `/stats` while
  it catches up.

**Debrief:** requests reserve, limits cap. A CPU limit throttles in every scheduling period, so the average looks
fine while latency suffers: average against worst case. Managed Prometheus and its dashboards showed the
throttling; `kubectl top` didn't.

**Advanced bonus for fast finishers: C3** (below).

---

## Round 4 · C4 · The AI assistant is up, but not working

[SOLUTION](../challenge-end-state/challenges/c4-ai-assistant-up-but-not-working/SOLUTION.md) · namespace
`c4-assistant` · suggested time 10 to 20 minutes · fallback: A4

| | |
| --- | --- |
| **Attendees see** | All pods are Ready, but **Generate description** in the store admin fails (HTTP 500). |
| **The fault** | ConfigMap `ai-service-configs` has `AZURE_OPENAI_DEPLOYMENT_NAME: store-assistant-gpt41`, a deployment that the platform replaced at a model upgrade (change ticket CHG-1142). The Foundry account's deployment is `store-assistant`. The service authenticates fine, with workload identity, and gets HTTP 404 `DeploymentNotFound`. |
| **Path** | A real request (the UI button, or `wget` from `store-admin`, in hint 1) → `kubectl logs deploy/ai-service` → `printenv \| grep AZURE_OPENAI` → `az cognitiveservices account deployment list` (or the Foundry portal) → the ConfigMap and its change ticket |
| **When to nudge** | 5 minutes: "The pods are Ready: what does `/health` test?" (hint 1). 10 minutes: the logs (hint 2). 15 minutes: compare with the deployments that exist (hint 3). |

**The fix**

```bash
kubectl patch configmap ai-service-configs -n c4-assistant --type merge \
  -p '{"data":{"AZURE_OPENAI_DEPLOYMENT_NAME":"store-assistant"}}'
kubectl rollout restart deployment/ai-service -n c4-assistant
```

**Wrong turns**

- API keys: key authentication is off on the account.
- The model's name (`gpt-6-luna`) as the deployment name: it works, because Foundry also answers a bare model name,
  but it bypasses the provisioned deployment (quota, content filters). The check fails it.
- A new deployment called `store-assistant-gpt41`: changes the platform to match stale configuration.
- Restarted pods only: the configuration is unchanged.

**Debrief:** health checks that don't test dependencies; model upgrades often come with a new deployment name;
keyless access with workload identity; a deployment isn't a model.

**If C4 can't run** (the subscription has no access to the model): run A4 in its place.

---

## Advanced bonus · C3 · Capacity that never arrives

[SOLUTION](../challenge-end-state/challenges/c3-capacity-that-never-arrives/SOLUTION.md) · namespace `c3-processing`
· suggested time 20 to 30 minutes · for fast finishers, not the whole room

| | |
| --- | --- |
| **Attendees see** | Job `order-batch` stays Pending. NodePool `c3-processing` reports `READY=True`, but no node arrives. |
| **The fault** | The NodePool's approved VM sizes (`karpenter.azure.com/sku-name`) are all Arm64 sizes, such as `Standard_D4ps_v6` (the `p`), and its `kubernetes.io/arch` requirement is `amd64`: no size satisfies both. The pool's event is `NoCompatibleInstanceTypes`. |
| **Path** | `kubectl describe pod` (all its events) → the pool that can host the pod (label and taint) → `kubectl describe nodepool c3-processing`, its requirements and events → the requirements compared with each other |
| **When to nudge** | 10 minutes: "Don't trust Karpenter's *typo of* suggestion. Which pool could host this pod?" (hints 1 and 2). 15 minutes: "What does the `p` in `D4ps_v6` mean?" (hint 3). |

**The fix** (requirement index 5 is `sku-name`)

```bash
kubectl patch nodepool c3-processing --type json -p '[{"op":"replace","path":"/spec/template/spec/requirements/5/values",
  "value":["Standard_D2s_v5","Standard_D4s_v5","Standard_D2s_v6","Standard_D4s_v6","Standard_D2s_v7","Standard_D4s_v7"]}]'
# Or remove only that requirement:
# kubectl patch nodepool c3-processing --type json -p '[{"op":"remove","path":"/spec/template/spec/requirements/5"}]'
```

A node arrives about a minute after the fix, and the Job finishes about two minutes after the fix. The check can
wait several minutes for the node.

**Wrong turns:** the pool switched to `arm64` (the image is amd64-only); the Job's `nodeSelector` or toleration
removed (breaks isolation); the pool's requirements, taint, or limits deleted; the NodePool deleted.

**Debrief:** node autoprovisioning (Karpenter) on AKS Automatic; a NodePool can be Ready and still unable to launch
anything; its requirements must be satisfiable together; Azure VM size names encode the architecture.

---

## Reserves

Use A5 first, for any round, then A3 and A6. A1 suits an advanced group.

### A5 · Running is not ready

[SOLUTION](../challenge-end-state/challenges/a5-running-is-not-ready/SOLUTION.md) · namespace `a5-releases` ·
suggested time 15 to 20 minutes

| | |
| --- | --- |
| **Attendees see** | `kubectl exec -n a5-releases deploy/rollout-tester -- python3 /app/rollout_test.py` reports failed customer requests during a rollout (about 144 in testing). |
| **The fault** | `web`'s readiness probe calls `/healthz` (the process is up) instead of `/ready` (warmed up, able to serve), and the rollout strategy can remove old pods before new ones are ready. |
| **When to nudge** | 5 minutes: Running against Ready (hint 1). 10 minutes: the endpoint slices during a rollout (hint 2). 15 minutes: the probe's path and the strategy (hint 3). |

```bash
kubectl patch deployment web -n a5-releases --type json -p '[
  {"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/ready"},
  {"op":"replace","path":"/spec/strategy/rollingUpdate/maxUnavailable","value":0}]'
```

**Wrong turns:** `initialDelaySeconds: 60` (a guess, not a signal); `/ready` as the liveness probe (restarts pods
while they warm up); only `maxUnavailable: 0`, or only `minReadySeconds` (new pods still get traffic too early).

**Debrief:** readiness gates traffic, liveness restarts; a probe must test what it claims to; a rollout without
downtime needs surge and no unavailability.

### A4 · Identity without secrets

[SOLUTION](../challenge-end-state/challenges/a4-identity-without-secrets/SOLUTION.md) · namespace `a4-config` ·
suggested time 15 to 20 minutes · C4's fallback

| | |
| --- | --- |
| **Attendees see** | `config-reader` can't read its secret from Key Vault: `FAILED at stage 'token-exchange': invalid_client: AADSTS700213: No matching federated identity record found for presented assertion subject 'system:serviceaccount:a4-config:config-reader'`. |
| **The fault** | The federated credential `config-reader` on the managed identity `id-ctf-config-reader` still has the subject of the app's old namespace, `system:serviceaccount:config-legacy:config-reader`. |
| **When to nudge** | 5 minutes: which stage fails (hint 1)? 10 minutes: the pod's namespace and service account (hint 2). 15 minutes: the federated credential's subject (hint 3). |

```bash
az identity federated-credential update -g <resource group> --identity-name id-ctf-config-reader -n config-reader \
  --subject system:serviceaccount:a4-config:config-reader
```

The portal works too: **Managed Identities** > `id-ctf-config-reader` > **Federated credentials**. The app retries
every 20 seconds, so it needs no restart.

**Wrong turns:** a client secret, or credentials in a Kubernetes Secret (the check looks for Secrets); a credential
for `report-generator` too, or a wildcard (the negative test fails); Key Vault Administrator or Owner (doesn't fix
the token exchange); moving the app back to `config-legacy`.

**Debrief:** workload identity federation matches the issuer, subject, and audience exactly; the subject is
`system:serviceaccount:<namespace>:<service account>`; fix the binding, not the platform, and keep least privilege.
Attendees need Managed Identity Contributor on the identity, which the prepare LCA assigns.

### A3 · Ready for maintenance?

[SOLUTION](../challenge-end-state/challenges/a3-ready-for-maintenance/SOLUTION.md) · namespace `a3-maintenance` ·
suggested time 10 to 15 minutes, an easy round

| | |
| --- | --- |
| **Attendees see** | `kubectl logs -n a3-maintenance job/pre-maintenance-check`: `Eviction BLOCKED (HTTP 429)`, so a node drain (an upgrade, NAP consolidation) would stall. |
| **The fault** | `inventory-api` has one replica, and its PodDisruptionBudget has `minAvailable: 1`: `ALLOWED DISRUPTIONS 0`. |

```bash
kubectl scale deployment/inventory-api -n a3-maintenance --replicas=2
kubectl create job -n a3-maintenance --from=cronjob/maintenance-check check-2
```

**Wrong turns:** deleting the PDB, or `minAvailable: 0` (the eviction succeeds, and requests fail); `kubectl delete
pod --force` (bypasses the Eviction API); `kubectl drain` (affects every workload on the node, and still blocks).

**Debrief:** a disruption budget needs redundancy to work with; blocked drains hold up AKS upgrades and NAP
consolidation.

### A6 · The data survived, the application didn't

[SOLUTION](../challenge-end-state/challenges/a6-data-survived-app-didnt/SOLUTION.md) · namespace `a6-records` ·
suggested time 10 to 15 minutes, plus the disk attach

| | |
| --- | --- |
| **Attendees see** | `records-api` is Pending: `persistentvolumeclaim "records-data-v2" not found`. |
| **The fault** | The Deployment refers to the claim `records-data-v2`; the data is in `records-data`. |

```bash
kubectl patch deployment records-api -n a6-records --type strategic -p \
  '{"spec":{"template":{"spec":{"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"records-data"}}]}}}}'
```

The disk attach takes 30 to 90 seconds. A brief `Multi-Attach error` is normal while the disk detaches from the seed
Job's node.

**Wrong turns:** creating `records-data-v2` (an empty disk: readiness fails); deleting and re-creating
`records-data` (`reclaimPolicy: Delete` destroys the data); running the seed Job again (re-creating data isn't
restoring it).

**Debrief:** change the reference, not the data; check the reclaim policy before you delete a claim; verify the data
(the seed Job's log has its checksum).

### A1 · Where did DNS go?

[SOLUTION](../challenge-end-state/challenges/a1-where-did-dns-go/SOLUTION.md) · namespace `a1-inventory` ·
suggested time 20 to 30 minutes · advanced

| | |
| --- | --- |
| **Attendees see** | `inventory-sync` logs `could not resolve catalog-api`, while all pods are Running and Ready. |
| **The fault** | Change ticket CHG-1150 locked down the namespace's egress (`default-deny-egress`) and allowed `inventory-sync` only the catalog API, on TCP 8080: it forgot DNS. The textbook fix, port 53 to the CoreDNS pods (`k8s-app=kube-dns`), doesn't work on AKS Automatic: pods resolve through LocalDNS on their node (`169.254.10.11`), which Cilium treats as the node itself (the `host` entity), and a Kubernetes NetworkPolicy can't select the node. |
| **When to nudge** | Release **hint 4 at about 10 minutes**: that the textbook fix fails here is the lesson, not a trap to leave people in. |

```bash
kubectl edit networkpolicy inventory-sync-egress -n a1-inventory
# Allow port 53, UDP and TCP, without restricting the destination. Least privilege: keep the policy, and add a
# CiliumNetworkPolicy with toEntities: [host] on port 53 (in the SOLUTION).
```

**Wrong turns:** deleting `default-deny-egress`; `egress: [{}]`, or all UDP (allows DNS tunneling); editing CoreDNS
(a cluster-wide change); hard-coding the Service's IP address.

**Debrief:** DNS is port 53 over UDP and TCP; with default-deny egress, DNS has to be allowed explicitly; AKS
Automatic's LocalDNS and Cilium change where DNS traffic goes, so check where the pod actually sends its queries
(`/etc/resolv.conf`).
