# Participant permissions

What each challenge needs. In Skillable, the cloud portal user has Contributor on the resource group, and the
prepare life cycle action adds AKS RBAC Cluster Admin and Monitoring Data Reader on the resource group, and Managed
Identity Contributor on A4's identity ([the LCA runbook](../skillable/LCA-RUNBOOK.md#identities-and-roles)):

| Challenge | Kubernetes | Azure |
|---|---|---|
| All | RBAC Cluster Admin (or Admin on the challenge namespaces + read on nodes/NodePools) | Reader on the resource group |
| C2 | create Gateways/HTTPRoutes and delete Ingresses in `c2-storefront`; read IngressClasses, GatewayClasses and `nginxingresscontrollers` (cluster-scoped) | – (the cutover is a Kubernetes annotation; Azure creates the DNS name). The optional production step `az aks approuting update --nginx None` would need write access to the cluster – not part of the lab |
| C3 | edit `nodepools.karpenter.sh` (cluster-scoped) | – |
| C4 | – | read Foundry deployments (`az cognitiveservices account deployment list`) |
| A2 | – | open **Dashboards with Grafana** on the cluster: read access to the Azure Monitor workspace's data. Owner worked in testing (no extra role); with a narrower role add **Monitoring Data Reader** on the workspace (`amw-ctf-<id>` in the lab resource group). `kubectl top` and `/stats` work without it |
| A4 | – | update federated credentials on `id-ctf-config-reader` (Managed Identity Contributor on the identity, or resource-group Contributor) |
| Leaderboard (optional) | – | none: lab VMs only need outbound HTTPS to the leaderboard's storage account (`<account>.blob.core.windows.net`) and `curl` for `verify.sh`; the token comes from the event's registration link, https://aka.ms/aksctfsecrets, when an attendee joins (the lab instructions, **Get started**, Task 6). The **instructor** needs Storage Blob Data Reader on that account to show the board ([leaderboard/README.md](../leaderboard/README.md)) |

Attendees who deploy the challenges in their own subscription, as its Owner, have all of these.
