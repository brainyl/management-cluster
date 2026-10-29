#!/usr/bin/env bash
# Bootstrap in dependency order: EKS, controllers/CRDs, then GitOps resources.
set -euo pipefail
umask 077
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
export PATH="$PWD/.local/bin:$PATH"

stage="${1:-all}"
case "$stage" in all|foundation|controllers|gitops) ;; *) echo "Usage: $0 [all|foundation|controllers|gitops]" >&2; exit 2 ;; esac
: "${AWS_PROFILE:?Set AWS_PROFILE to the intended AWS profile}"
: "${EXPECTED_AWS_ACCOUNT_ID:?Set EXPECTED_AWS_ACCOUNT_ID to the intended account}"
for command in aws terraform kubectl python3; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command" >&2; exit 1; }
done
mkdir -p .local
export KUBECONFIG="$PWD/.local/kubeconfig"
actual_account="$(aws sts get-caller-identity --query Account --output text)"
if [[ "$actual_account" != "$EXPECTED_AWS_ACCOUNT_ID" ]]; then
  echo "Account mismatch: expected $EXPECTED_AWS_ACCOUNT_ID, authenticated as $actual_account" >&2
  exit 1
fi

run_logged() {
  local label="$1"
  shift
  echo "$label (private log: .local/$label.log)"
  if ! "$@" > ".local/$label.log" 2>&1; then
    echo "$label failed; inspect .local/$label.log locally (may contain secrets)." >&2
    exit 1
  fi
}

apply_stage() {
  local name="$1"
  shift
  run_logged "$name-plan" terraform plan -input=false -no-color "$@" -out=".local/$name.tfplan"
  # Print only addresses/actions, never resource values or credentials.
  terraform show -json ".local/$name.tfplan" | python3 -c '
import json,sys
for resource in json.load(sys.stdin).get("resource_changes", []):
    actions = resource["change"]["actions"]
    if actions != ["no-op"]:
        print("  " + resource["address"] + ": " + ", ".join(actions))
'
  run_logged "$name-apply" terraform apply -input=false -no-color ".local/$name.tfplan"
}

run_logged init terraform init -input=false -lockfile=readonly
if [[ "$stage" == all || "$stage" == foundation ]]; then
  apply_stage foundation -target=module.vpc -target=module.eks
fi

if [[ "$stage" != foundation ]]; then
  cluster_name="$(terraform output -raw cluster_name)"
  cluster_region="$(terraform output -raw configure_kubectl | python3 -c 'import shlex,sys; args=shlex.split(sys.stdin.read()); print(args[args.index("--region")+1])')"
  run_logged kubeconfig aws eks update-kubeconfig --name "$cluster_name" --region "$cluster_region" --kubeconfig "$KUBECONFIG"
  if [[ "$stage" == all || "$stage" == controllers ]]; then
    # This target includes Crossplane/ESO and their identities through dependencies.
    # It excludes the root Application, whose CRD does not exist on a fresh cluster.
    apply_stage controllers -target=module.argocd.helm_release.argocd
  fi
  if [[ "$stage" == all || "$stage" == gitops ]]; then
    # Full reconciliation after controller CRDs exist; honors root_automated_sync.
    apply_stage gitops
    run_logged verification "$SCRIPT_DIR/verify.sh"
  fi
fi

echo "Bootstrap stage '$stage' completed. Kubeconfig: $KUBECONFIG"
