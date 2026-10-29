# Validate the management cluster

Select the intended AWS profile, region and root Kubernetes context before running these checks.

## Foundation checkpoint

```bash
ROOT_CLUSTER=$(terraform output -raw cluster_name)
aws eks describe-cluster --name "$ROOT_CLUSTER" --region "$AWS_REGION" \
  --query 'cluster.{Name:name,Status:status,Version:version}'
kubectl config current-context
kubectl get --raw='/readyz?verbose'
kubectl auth can-i get pods --all-namespaces
kubectl get nodes
kubectl -n kube-system get pods -o wide
```

Expect EKS `ACTIVE`, Kubernetes **1.37**, a ready API, and authorized access. Auto Mode capacity is demand-driven; an empty node/Pod list is valid before controller workloads are installed.

## Controllers and GitOps checkpoint

```bash
./scripts/verify.sh
```

This checks controller deployments, requested Crossplane provider revisions, Secret-store/repository synchronization, and root repository rendering. `OutOfSync` is acceptable while root automatic sync is deliberately disabled. Keep it disabled at the root-only teaching checkpoint.

Bootstrap and access: [README](../README.md). Cleanup and AWS audit: [root teardown](teardown.md).

Verified 2026-10-25 in account `420924156696`, `us-west-2`: root automatic sync activated through a reviewed Terraform update to the root Application only. Root Application Synced/Healthy; subsequent Terraform plan reported no changes. This activation follows the paused foundation checkpoint; it is not repeated for component release promotions.

Verified 2026-10-25: root `allowEmpty: true` permits disabling its last child Application in Git. Automatic cascading deletion completed; original root controllers/providers remained healthy and EKS remained ACTIVE. Terraform reported no drift. No manual sync, resource deletion or finalizer removal was needed.

Verified 2026-10-25: the `infra-management-api` and `infra-management-config` repository ExternalSecrets are SecretSynced and Argo reports Successful connections. The API uses its renamed source at the selected `v0.1.0` release. Root/API Applications remain Synced/Healthy, child inventory is disabled, and the follow-up Terraform plan reports no drift.

## Episode 05 root reconciliation — 2026-10-25

Root Argo automatically reconciled inventory activation and staged deletion in `us-west-2`. Root/API remained healthy, and owned infra resources were verified deleted; the inventory is disabled. No manual sync or finalizer override. Full layer evidence: private engineering playbook, Episode 05.

## Root reconciliation after Episode 05 restore — 2026-10-26 UTC

Root/API and inventory Applications are Synced/Healthy. Git promotions selected API `v0.1.3` and inventory `v0.1.4`; the requested infra cluster is Ready. No Terraform apply or manual Argo sync was required. Full layer/access evidence is in the private engineering playbook.

## Root teardown verified — 2026-10-26 UTC

After downstream cleanup, reviewed/applied root automatic-sync disable, then ran the repo's teardown `prepare`, `plan`, `apply`, `verify` stages. Terraform state is empty; AWS verifies root EKS, networking, four Auto Mode nodes/eight captured disks, identities, logs and cloud credential absent. Node/disks are audited by exact IDs to include hidden managed instances. Root KMS deletion is scheduled for 2026-11-25 03:01 UTC. Shared account roles and local inputs/state are retained; root automatic sync is disabled for the next staged rebuild. No manual cloud repair or finalizer override.

## Root rebuilt — 2026-10-26

Repo bootstrap foundation/controllers/gitops stages completed in `420924156696`, `us-west-2`, EKS 1.37. Root verification passed, including healthy providers and repository credential synchronization. Renamed repository configuration is committed; automatic reconciliation was enabled through a reviewed Terraform update to the root Application only. No manual controller, credential or AWS repair.
