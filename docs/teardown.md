# Root-only teardown

Use this helper for the EKS foundation or completed root checkpoint. It refuses additional Argo CD Applications, composite/cloud resources and persistent workloads. Disable root automatic sync through Terraform before cleanup: set `root_automated_sync = false` in ignored inputs, then review/apply using the [root plan/apply commands](../README.md#enable-automatic-gitops-reconciliation). This pauses new reconciliation; it does not remove existing children.

From this checkout, authenticate to the intended account and set the same region used by Terraform:

```bash
export AWS_PROFILE=infra-ops
export AWS_REGION=us-west-2
export EXPECTED_AWS_ACCOUNT_ID=YOUR_MANAGEMENT_ACCOUNT_ID
python3 scripts/teardown.py prepare
python3 scripts/teardown.py plan
```

Review the deletion addresses, then apply the saved plan and audit AWS:

```bash
python3 scripts/teardown.py apply
python3 scripts/teardown.py verify
```

`prepare` inventories the root, checks its scope, and removes ingress and root-managed cloud credentials while their controllers remain alive. Foundation-only state automatically limits the destroy plan to EKS/VPC, so Terraform does not require uninstalled controller CRDs. It never removes cloud finalizers. `plan` and `apply` reject state changes since preparation; rerun preparation and plan after another Terraform operation.

State, inventories, plans and logs remain private under `.local/root-teardown/`. Verification requires empty Terraform state and checks EKS, networking, compute/disks, identities and the owned credential secret. Preparation captures Auto Mode node IDs from Kubernetes and queries EC2 directly, because ordinary EC2 lists can hide managed instances. The AWS audit retries residual-resource visibility for up to 15 minutes; scope and command errors stop immediately. A root KMS key may remain pending its AWS deletion waiting period.

Preserve empty Terraform state and inputs. Rebuild with `bootstrap.sh foundation`; add `controllers` and `gitops` when returning to that checkpoint. Account-role StackSets are outside this helper's scope. If additional resources exist, complete their owning lifecycle procedure before removing the root.
