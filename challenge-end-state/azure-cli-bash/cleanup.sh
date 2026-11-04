#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables set here are consumed by the shared library
# -----------------------------------------------------------------------------
# KubeCon AKS capture-the-flag lab - delete an END-state environment.
#   ./cleanup.sh                 # asks for confirmation
#   ./cleanup.sh -g my-rg -y
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
DEFAULT_RESOURCE_GROUP="rg-kubecon-ctf-end-bash"

# shellcheck source=/dev/null
. "$REPO_ROOT/shared/azure-cli-bash/lib.sh"

ctf_cleanup "$@"
