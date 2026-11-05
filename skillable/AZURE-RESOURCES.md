# What the Skillable access control policy must allow

Skillable's events team builds each lab profile's access control policy (ACP) from a resource scrape: the resources
of a launched lab, as Resource Explorer in the Azure portal shows them. The ACP denies everything else. A scrape
doesn't show role assignments, other child and extension resources, VM sizes, or what AKS creates in its own resource
groups (LAB723 at Ignite listed them separately for the same reason). This page lists everything that the KubeCon
CTF lab creates, from a deployment of the begin state in westus3 on 2026-11-03 and 2026-11-04.

**First Skillable launch (2026-11-04):** the prepare LCA stopped at its first role assignment, in deploy.ps1's
**Kubernetes data-plane access (Azure RBAC)** step: Azure Kubernetes Service RBAC Cluster Admin on the lab's resource
group, for the cloud subscription's service principal. Before 2026-11-04, the PowerShell deploy script, which the LCA
runs, retried for 2.5 minutes and then reported only `Could not assign '<role>' on <scope>`, without Azure's reason.
Since then, the deploy scripts stop at once on a policy denial, and name the cause:

| The error ends with | Cause | Ask Skillable to |
| --- | --- | --- |
| `(RequestDisallowedByPolicy). Azure Policy denied the role assignment (policy assignment '<name>')` | The ACP, or another policy on the subscription, denies role assignments | Allow `Microsoft.Authorization/roleAssignments` for the roles in [Role assignments](#role-assignments) |
| `(AuthorizationFailed). The signed-in identity may not create role assignments there` | The cloud subscription's service principal isn't Owner (or User Access Administrator, or Role Based Access Control Administrator) of the lab's subscription, or a condition limits which roles it can assign. In a manual run, the cloud portal user isn't Owner of the resource group. | Make the service principal Owner of the lab's subscription, as for LAB723. For a manual run, see [Build the begin state by hand](LCA-RUNBOOK.md#build-the-begin-state-by-hand). |

LAB723's prepare LCA assigned Azure Kubernetes Service RBAC Cluster Admin in its Skillable launches (on the cluster,
for the service principal and the portal user), so Skillable supports it when the ACP allows role assignments.

## Role assignments

Every Azure role assignment in a launch. If the ACP allows role assignments by role definition, allow all of them:
otherwise the prepare LCA stops at the next one.

| Role | Role definition ID | Assigned to | Scope | Created by | Why |
| --- | --- | --- | --- | --- | --- |
| Azure Kubernetes Service RBAC Cluster Admin | `b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b` | The cloud subscription's service principal | The lab's resource group | The prepare LCA (deploy.ps1), before it creates the cluster | AKS Automatic turns off local accounts, so `kubectl` works only with this Azure role. Owner isn't enough. |
| Contributor | `b24988ac-6180-42a0-ab88-20f7382dd24c` | The cluster's managed identity | The node resource group, `MC_<resource group>_aks-kubecon-ctf_<region>` | AKS, when it creates the cluster | AKS manages the nodes' resources with it. Without it, cluster creation fails. |
| Cognitive Services OpenAI User | `5e0bd9bd-7b93-4f28-af87-19fc36ad61bd` | `id-ctf-ai-service`, a user-assigned managed identity | The Foundry account, `aoai-ctf-<id>` | The prepare LCA (C4) | The store assistant calls the model with workload identity, no keys |
| Key Vault Secrets User | `4633458b-17de-408a-b874-0445c86b69e6` | `id-ctf-config-reader`, a user-assigned managed identity | The secret `lab-config` in `kv-ctf-<id>` | The prepare LCA (A4) | The app reads the secret with workload identity |
| Azure Kubernetes Service RBAC Cluster Admin | `b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b` | The cloud portal user (`User1`) | The lab's resource group | The prepare LCA's worker | The attendee's `kubectl` |
| Monitoring Data Reader | `b0d8363b-8ddd-447d-831f-62ca05bff136` | The cloud portal user | The lab's resource group | The prepare LCA's worker | A2's dashboards with Grafana read Managed Prometheus |
| Managed Identity Contributor | `e40ec5ca-96e0-45a2-b4ff-59039f2c2b59` | The cloud portal user | `id-ctf-config-reader` | The prepare LCA's worker | A4's fix updates the identity's federated credential |

All are `Microsoft.Authorization/roleAssignments` resources. The managed identities and the cluster's identity are
service principals. Attendees create no role assignments: resetting a challenge reuses these (tested as an attendee
stand-in on 2026-11-04).

## Resource types

### The lab's resource group (`ResourceGroup1`)

The prepare LCA creates them with the Azure CLI, from `begin-challenge/azure-cli-powershell/deploy.ps1` in the lab
repository.

| Type | Name | SKU, kind, or settings |
| --- | --- | --- |
| `Microsoft.ContainerService/managedClusters` | `aks-kubecon-ctf` | SKU `Automatic`, with the managed (hosted) system node pool, the application routing add-on (managed NGINX), Gateway API with `approuting-istio`, Managed Prometheus, and Container Insights. Kubernetes 1.36. |
| `Microsoft.Monitor/accounts` | `amw-ctf-<id>` | Azure Monitor workspace, for Managed Prometheus |
| `Microsoft.OperationalInsights/workspaces` | `law-ctf-<id>` | `PerGB2018`, for Container Insights |
| `Microsoft.Insights/dataCollectionEndpoints` | `MSProm-<region>-aks-kubecon-ctf` | |
| `Microsoft.Insights/dataCollectionRules` | `MSProm-<region>-aks-kubecon-ctf`, `MSCI-<region>-aks-kubecon-ctf` | |
| `Microsoft.AlertsManagement/prometheusRuleGroups` | Six recording rule groups for `aks-kubecon-ctf` | |
| `Microsoft.CognitiveServices/accounts` | `aoai-ctf-<id>` | Kind `AIServices`, SKU `S0`, key authentication off (C4). In the resource group's region when it offers the C4 model, otherwise in westus3 (see [Regions](#regions)) |
| `Microsoft.KeyVault/vaults` | `kv-ctf-<id>` | SKU `standard`, Azure RBAC, 7-day soft delete (A4) |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | `id-ctf-ai-service` (C4), `id-ctf-config-reader` (A4) | |

### The node resource group (`MC_<resource group>_aks-kubecon-ctf_<region>`)

AKS creates and manages it, and AKS Automatic keeps it read-only for everyone else. The counts change with the nodes
and with the challenges' load balancers.

| Type | Notes |
| --- | --- |
| `Microsoft.Compute/virtualMachines` | Node autoprovisioning (NAP) creates individual VMs (no scale sets). See [VM sizes](#vm-sizes). |
| `Microsoft.Compute/virtualMachines/extensions` | `AKSLinuxExtension`, `computeAksLinuxBilling`, and `cse-agent-karpenter` on each node |
| `Microsoft.Compute/disks` | The nodes' OS disks, and A6's Azure Disk volume |
| `Microsoft.Network/networkInterfaces` | One for each node |
| `Microsoft.Network/virtualNetworks`, `Microsoft.Network/networkSecurityGroups` | |
| `Microsoft.Network/natGateways` | Outbound type `managedNATGatewayV2` |
| `Microsoft.Network/publicIPAddresses` | SKU `StandardV2` for the NAT gateway, and `Standard` for load balancer frontends: the managed NGINX's, and the gateway that attendees create in C2 |
| `Microsoft.Network/loadBalancers` | `kubernetes`, and `kube-apiserver` |
| `Microsoft.ManagedIdentity/userAssignedIdentities` | `aks-kubecon-ctf-agentpool`, `webapprouting-aks-kubecon-ctf`, `azurepolicy-aks-kubecon-ctf`, and `azurekeyvaultsecretsprovider-aks-kubecon-ctf` |

### The Azure Monitor workspace's resource group (`MA_amw-ctf-<id>_<region>_managed`)

Azure Monitor creates it: a `Microsoft.Insights/dataCollectionEndpoints` and a `Microsoft.Insights/dataCollectionRules`.

### Child and extension resources

- `Microsoft.Authorization/roleAssignments`: the seven in [Role assignments](#role-assignments)
- `Microsoft.Insights/dataCollectionRuleAssociations`: on the cluster, for Managed Prometheus and Container Insights
- `Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials`: `ai-service` (C4) and
  `config-reader` (A4)
- `Microsoft.CognitiveServices/accounts/deployments`: `store-assistant`, model `gpt-6-luna` version `2026-09-22`,
  `GlobalStandard`, 50 (thousand tokens per minute)
- `Microsoft.KeyVault/vaults/secrets`: `lab-config`, which the prepare LCA writes through Azure Resource Manager (A4)
- `Microsoft.ContainerService/deploymentSafeguards`: the cluster's deployment safeguards, which AKS Automatic manages
- Optional: `Microsoft.KubernetesConfiguration/extensions` (Inspektor Gadget, when the prepare LCA's
  `InspektorGadget` setting is on), and `Microsoft.ContainerService/managedClusters/maintenanceConfigurations` (only
  if you set planned maintenance windows; AKS Automatic created none)

## VM sizes

NAP chooses each node's size from the D family: `Standard_D4als_v6` in the tests, for both the workload node and
the system surge node. Allow D-family sizes of any vCPU count, not only that one: NAP's choice varies by launch.
C3's fix approves `Standard_D2s_v5`, `Standard_D4s_v5`, `Standard_D2s_v6`, `Standard_D4s_v6`, `Standard_D2s_v7`, and
`Standard_D4s_v7` for its node pool. (Its begin state approves Arm64 sizes, which NAP never creates, because the pool
requires amd64: that's the challenge.) The AKS-managed system nodes (`aks-hostedpool-*`) didn't appear in the lab's
subscription.

## Subscription operations

The prepare LCA registers these resource providers when they aren't registered: `Microsoft.ContainerService`,
`Microsoft.Compute`, `Microsoft.Network`, `Microsoft.ManagedIdentity`, `Microsoft.PolicyInsights`,
`Microsoft.CognitiveServices`, `Microsoft.KeyVault`, `Microsoft.Monitor`, `Microsoft.Insights`,
`Microsoft.OperationalInsights`, `Microsoft.AlertsManagement`, `Microsoft.Dashboard`, `Microsoft.Storage`, and
`Microsoft.KubernetesConfiguration`. No preview features.

## Regions

Tested in westus3, where everything is in one region. The event's region needs AKS Automatic. C4's model,
`gpt-6-luna` as `GlobalStandard` with 50,000 tokens per minute of quota for each lab, can be in another region: when
the resource group's region doesn't offer it, `deploy.ps1` creates the Foundry account in the first of westus3,
eastus2, and swedencentral that does. Some regions offer no OpenAI models at all: westcentralus, where a Skillable
launch landed without an **Override Data Center** on 2026-11-05, is one (its deployment failed with
`SpecialFeatureOrQuotaIdRequired`). So either set the resource group's **Override Data Center** to a region that
offers the model, such as West US 3, or make sure the ACP allows `Microsoft.CognitiveServices/accounts` in westus3.
The lab profile's Override Data Center is West US 3 since 2026-11-05.

## Message for Skillable

Replace the values in angle brackets.

```text
Subject: KubeCon CTF lab: the access control policy must allow role assignments

Hi <name>,

The KubeCon AKS capture-the-flag lab's prepare life cycle action stops at its first Azure role assignment: it can't
give the cloud subscription's service principal Azure Kubernetes Service RBAC Cluster Admin on the lab's resource
group. AKS Automatic turns off local accounts, so kubectl works only with that role; Owner isn't enough. LAB723 at
Ignite assigns the same role in its Skillable launches.

Please allow role assignments (Microsoft.Authorization/roleAssignments) in the lab profile's access control policy,
for these roles. If the policy allows them by role definition, these are all of them:

- Azure Kubernetes Service RBAC Cluster Admin (b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b): for the cloud subscription's
  service principal and the cloud portal user, on the lab's resource group
- Contributor (b24988ac-6180-42a0-ab88-20f7382dd24c): for the AKS cluster's managed identity, on the node resource
  group MC_<resource group>_aks-kubecon-ctf_<region>. AKS creates this one itself when it creates the cluster.
- Cognitive Services OpenAI User (5e0bd9bd-7b93-4f28-af87-19fc36ad61bd): for a user-assigned managed identity, on
  the lab's Microsoft Foundry account
- Key Vault Secrets User (4633458b-17de-408a-b874-0445c86b69e6): for a user-assigned managed identity, on one Key
  Vault secret
- Monitoring Data Reader (b0d8363b-8ddd-447d-831f-62ca05bff136): for the cloud portal user, on the lab's resource
  group
- Managed Identity Contributor (e40ec5ca-96e0-45a2-b4ff-59039f2c2b59): for the cloud portal user, on one
  user-assigned managed identity

Other things a resource scrape doesn't show, which the lab also needs:

- Child and extension resources: data collection rule associations, federated identity credentials, a Foundry model
  deployment (gpt-6-luna, GlobalStandard), a Key Vault secret, and the cluster's deployment safeguards.
- The node resource group, which AKS creates: individual VMs and their extensions, network interfaces, and disks, a
  virtual network, a network security group, a NAT gateway, load balancers, public IP addresses (SKUs Standard and
  StandardV2), and managed identities. Also MA_<workspace>_<region>_managed, which the Azure Monitor workspace
  creates, with a data collection endpoint and rule.
- VM sizes: node autoprovisioning chooses D-family sizes (Standard_D4als_v6 in our tests); please allow D-family
  sizes of any vCPU count.
- Resource provider registrations by the service principal: Microsoft.ContainerService, Compute, Network,
  ManagedIdentity, PolicyInsights, CognitiveServices, KeyVault, Monitor, Insights, OperationalInsights,
  AlertsManagement, Dashboard, Storage, and KubernetesConfiguration.
- Region: <event region>. The Microsoft Foundry account and its model deployment go to westus3 when the event region
  doesn't offer the model (westcentralus offers no OpenAI models).

If the error is AuthorizationFailed instead of RequestDisallowedByPolicy, the service principal can't create role
assignments at all: please make it Owner of the lab's subscription, as for LAB723.

Thanks,
Brian
```
