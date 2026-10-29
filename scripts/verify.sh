#!/usr/bin/env bash
# Read-only checks for the root management layer.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
export PATH="$PWD/.local/bin:$PATH"
export KUBECONFIG="${KUBECONFIG:-$PWD/.local/kubeconfig}"

crossplane_namespace="$(terraform output -raw crossplane_namespace)"
argocd_namespace="$(terraform output -raw argocd_namespace)"
# Wait for the requested provider revisions before inspecting their deployments.
# Old revisions can briefly retain Healthy=True immediately after an update.
python3 - <<'PYTHON'
import json, subprocess, time
for attempt in range(121):
    providers = json.loads(subprocess.check_output([
        'kubectl', 'get', 'providers.pkg.crossplane.io', '-o', 'json']))['items']
    pending = []
    for provider in providers:
        status = provider.get('status', {})
        conditions = {c['type']: c for c in status.get('conditions', [])}
        generation = provider['metadata']['generation']
        ready = status.get('currentIdentifier') == provider['spec']['package']
        ready = ready and all(
            conditions.get(kind, {}).get('status') == 'True'
            and conditions[kind].get('observedGeneration') == generation
            for kind in ('Installed', 'Healthy'))
        if not ready:
            pending.append(provider['metadata']['name'])
    if providers and not pending:
        break
    if attempt == 120:
        raise SystemExit('Provider revisions not ready: ' + ', '.join(pending))
    time.sleep(5)
PYTHON
for namespace in "$crossplane_namespace" "$argocd_namespace" external-secrets-system; do
  while IFS= read -r deployment; do
    kubectl -n "$namespace" rollout status "$deployment" --timeout=600s
  done < <(kubectl -n "$namespace" get deployments -o name)
done
kubectl wait providers.pkg.crossplane.io --all --for=condition=Installed --timeout=600s
kubectl wait providers.pkg.crossplane.io --all --for=condition=Healthy --timeout=600s
kubectl wait clustersecretstore/aws-secretsmanager --for=condition=Ready --timeout=300s
kubectl -n "$argocd_namespace" wait externalsecret --all --for=condition=Ready --timeout=300s

# ArgoCD must have fetched/rendered the configured root without comparison errors.
export ARGOCD_NAMESPACE="$argocd_namespace"
python3 - <<'PY'
import json, os, subprocess, time
namespace = os.environ['ARGOCD_NAMESPACE']
for attempt in range(61):
    data = json.loads(subprocess.check_output([
        'kubectl', '-n', namespace, 'get', 'applications', '-o', 'json']))
    applications = data['items']
    if not applications:
        raise SystemExit('No root Application exists; enable create_root_application before root validation.')
    pending = []
    for app in applications:
        status = app.get('status', {})
        errors = [c for c in status.get('conditions', []) if c['type'].endswith('Error')]
        sync = status.get('sync', {}).get('status')
        if errors or sync not in ('Synced', 'OutOfSync') or not status.get('reconciledAt'):
            pending.append(app['metadata']['name'])
    if not pending:
        for app in applications:
            print(app['metadata']['name'] + ': repository rendered, ' + app['status']['sync']['status'])
        break
    if attempt == 60:
        raise SystemExit('ArgoCD repository/render checks failed: ' + ', '.join(pending))
    time.sleep(5)
PY
kubectl get nodes
kubectl get providers.pkg.crossplane.io
kubectl -n "$argocd_namespace" get externalsecrets,applications,ingress
echo 'Root controller, credential, and Git repository checks passed.'
