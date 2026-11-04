# What each challenge's check looks at

> An answer key: it names the expected fixes. It used to be in the lab repository's scoring/README.md; the lab
> repository keeps the scoring scripts, whose output names each check once an attendee runs them.

scoring/verify.sh and scoring/verify.ps1 in the lab repository run the same checks.

| ID | Checks (from the design document's success criteria and "what doesn't count") |
|---|---|
| C1 | `FASTIFY_ADDRESS` in the ConfigMap is a bind host (or unset); no override on the Deployment; rollout ready; no restarts during 60 s; synthetic order via the storefront succeeds and reaches the RabbitMQ queue |
| C2 | a Gateway of class `approuting-istio` in `c2-storefront` (any name; the one carrying the storefront's DNS label is preferred) is `Programmed` with an address; its `infrastructure.annotations` publish the storefront's DNS label; an HTTPRoute (any name) attached to it for the storefront host is `Accepted`/`ResolvedRefs` and sends `PathPrefix /` to `store-front:80`; `http://<host>/` resolves to the gateway and returns the storefront (200, retried for ~1 min for DNS); other Host → 404 at the gateway; no Ingress left in the namespace; `store-front` stays `ClusterIP`; no LoadBalancer Services other than `*-approuting-istio`. Host name and label come from the namespace annotations `kubecon.lab/storefront-hostname` / `-dns-label` |
| C3 | NodePool keeps `amd64`, label/taint isolation and CPU limit; no Arm64 sizes in the allow-list; Job keeps its placement; Job completes on a node from `c3-processing` (if node auto-provisioning has already removed the empty node and the finished pod with it, the completed Job and its placement rules count) |
| C4 | Entra ID auth (no API keys); `ai-service` is configured for the provisioned model deployment (`store-assistant`, or `AOAI_DEPLOYMENT_NAME` if you deployed with another name); ai-service ready; store-admin → product-service → ai-service → model returns a description (retries for propagation) |
| A1 | from inside `inventory-sync`: DNS resolves, catalog call works, `ledger-api` and the internet stay blocked; `default-deny-egress` unchanged; no allow-all egress rule |
| A2 | limits set, CPU ≤ 1, replicas ≤ 2, no HPA > 2; workload/test unchanged; fixed load test p95 ≤ 300 ms, 0 errors |
| A3 | replicas ≥ 2; PDB still protects the app; an on-demand `maintenance-check` eviction is accepted with 0 failed requests; back at target replicas |
| A4 | `config-reader` reads the lab value via workload identity; `report-generator` still unauthorized; no Secrets in the namespace; workload identity label kept |
| A5 | readiness on `/ready`, liveness not on `/ready`, no long initial delay; rollout under traffic with 0 failed requests |
| A6 | Deployment uses `records-data`; PVC still bound; app ready; 500 records with the original checksum |
