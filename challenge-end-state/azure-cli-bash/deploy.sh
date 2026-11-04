#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables set here are consumed by the shared library
# -----------------------------------------------------------------------------
# KubeCon AKS capture-the-flag lab - deploy the END state with the Azure CLI.
#
# Creates (or reuses) an AKS Automatic cluster plus the Azure services the
# selected challenges need, then deploys each challenge in its solved state
# (the result of the expected repair).
#
#   ./deploy.sh                          # all challenges in westus3
#   ./deploy.sh -c c1,c3 -l centralus    # only C1 and C3, another region
#   ./deploy.sh -g rg-kubecon-ctf-begin-bash --no-reset   # solve a begin-state environment in place
#   ./deploy.sh --help
#
# What "solved" looks like: ../challenges/<id>-*/README.md
# Uses the shared bash library of the lab repository (kubecon26-pre-day-lab),
# cloned next to this repository by default (CTF_LAB_REPO overrides it).
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTRUCTORS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
# The lab repository's shared bash library: CTF_LAB_REPO, or a clone next to this repository.
REPO_ROOT="${CTF_LAB_REPO:-$INSTRUCTORS_ROOT/../kubecon26-pre-day-lab}"
if [ ! -f "$REPO_ROOT/shared/azure-cli-bash/lib.sh" ]; then
  echo "The lab repository isn't in $REPO_ROOT. Clone https://github.com/bbenz/kubecon26-pre-day-lab next to this repository, or set CTF_LAB_REPO." >&2
  exit 2
fi
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
LAB_STATE="end"
LAB_STATE_TITLE="END state (challenges solved)"
LAB_STATE_DIR="$INSTRUCTORS_ROOT/challenge-end-state"
DEFAULT_RESOURCE_GROUP="rg-kubecon-ctf-end-bash"
# Apply the solved configuration on top of whatever is there (use --reset for a clean re-create).
CTF_RESET_DEFAULT=false

# shellcheck source=/dev/null
. "$REPO_ROOT/shared/azure-cli-bash/lib.sh"

ctf_parse_args "$@"
ctf_preflight
ctf_compute_names

# Shared platform
ctf_ensure_resource_group
ctf_ensure_cluster_admin    # before the cluster exists, so RBAC has propagated when it is ready
ctf_ensure_cluster
ctf_get_credentials

# Azure services needed by individual challenges
ctf_ensure_app_routing   # C2: application routing add-on - managed NGINX + Gateway API (approuting-istio)
ctf_ensure_prometheus    # A2: Managed Prometheus for the Grafana dashboards
ctf_ensure_c4_azure      # C4: Foundry model deployment + ai-service workload identity
ctf_ensure_a4_azure      # A4: Key Vault + identity; federated subject from challenges/a4-*/azure.env

# Kubernetes objects for each challenge
for id in $CTF_CHALLENGES; do
  ctf_apply_challenge "$id"
done

ctf_print_summary
