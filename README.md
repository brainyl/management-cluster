# Management cluster

Terraform bootstraps the root management cluster: EKS Auto Mode **1.37**, ArgoCD, Crossplane, External Secrets, and their AWS identities. This cluster hosts management components only.

## Why the bootstrap script exists

Root bootstrap and validation scripts live in this repository’s `scripts/` directory. Run them from this checkout; no playbook checkout or script copying is required.

ArgoCD must be running in the first cluster before it can deploy anything from Git. The script coordinates Terraform to create that cluster, install ArgoCD and its supporting controllers, then connect GitHub. ArgoCD takes over deployment of the next layers through GitOps; Terraform retains ownership of the root cluster and bootstrap components.

## Bootstrap

Prerequisites: AWS CLI, Terraform 1.x (`~> 1.5`), kubectl compatible with Kubernetes 1.37, Python 3, and access to the project repositories. Keep the committed Terraform provider lock file.

1. Authenticate to the intended AWS account and configure the module:

   ```bash
   aws sso login --profile infra-ops
   cp terraform.tfvars.example terraform.tfvars # only for a new checkout
   ```

   Set the AWS region, cluster name, repository URLs, and `github_token` in the ignored variable file. Use `cluster_version = "1.37"`, `create_root_application = true`, and `root_automated_sync = false` while validating the root layer.

2. Run the staged bootstrap:

   ```bash
   AWS_PROFILE=infra-ops EXPECTED_AWS_ACCOUNT_ID=420924156696 \
     ./scripts/bootstrap.sh
   ```

   The command checks the AWS account, initializes Terraform, and applies three stages:

   | Stage | Why |
   | --- | --- |
   | Foundation | Create the VPC/EKS before Kubernetes providers connect. |
   | Controllers | Install ArgoCD, Crossplane, External Secrets, and required CRDs. |
   | GitOps | Reconcile credentials, ingress, and the root Application after CRDs exist. |

   Plans, logs, and kubeconfig stay in ignored `.local/`. Logs may contain credentials. The command stops on failure; after fixing the cause, rerun it or select `foundation`, `controllers`, or `gitops` as its argument. It honors the configured root sync setting. Kubernetes bootstrap hooks replay when the cluster endpoint changes.

3. Validate the layer:

   ```bash
   export AWS_PROFILE=infra-ops
   export KUBECONFIG="$PWD/.local/kubeconfig"
   ./scripts/verify.sh
   ```

   Bootstrap runs these read-only readiness and repository checks automatically after the GitOps stage; the command above reruns them. Controllers and providers must be ready, ExternalSecrets must sync, and the root must render its repository without errors. A root Application left `OutOfSync` is expected while automatic sync is disabled. Keep `root_automated_sync = false` at this validation checkpoint.

## Run one stage at a time

From this checkout with private inputs prepared, set the intended account and run only the stages needed for your checkpoint:

```bash
export AWS_PROFILE=infra-ops
export EXPECTED_AWS_ACCOUNT_ID=420924156696 # Replace with your management account
export AWS_REGION=us-west-2
export PATH="$PWD/.local/bin:$PATH"
./scripts/bootstrap.sh foundation
```

The foundation creates EKS/networking only. Connect and inspect before installing controllers:

```bash
ROOT_CLUSTER=$(terraform output -raw cluster_name)
export KUBECONFIG="$PWD/.local/kubeconfig"
aws eks update-kubeconfig --name "$ROOT_CLUSTER" --region "$AWS_REGION" --alias "$ROOT_CLUSTER" --kubeconfig "$KUBECONFIG"
kubectl get --raw=/readyz
kubectl auth can-i get pods --all-namespaces
kubectl get nodes
kubectl -n kube-system get pods
```

Zero Auto Mode nodes is valid before Pods need compute. Omit `--kubeconfig` and unset `KUBECONFIG` if you prefer merging the context into your default kubeconfig. To complete the root later:

```bash
./scripts/bootstrap.sh controllers
./scripts/bootstrap.sh gitops
./scripts/verify.sh
```

> [!IMPORTANT]
> **Root providers are Terraform-owned.** The controller stage includes [EC2, EKS, IAM and Secrets Manager providers](modules/crossplane/main.tf) plus their runtime/credential configuration. EC2/EKS/IAM support cluster provisioning; Secrets Manager supports GitHub credential storage. Later root API charts must not install another owner for these providers.

Keep `root_automated_sync = false` until the root checkpoint passes. Both checkpoints use the repository's [root-only teardown](docs/teardown.md); retain state/inputs and repeat these stages to rebuild.

## Enable automatic GitOps reconciliation

After the root checkpoint passes, review the configuration in the repository selected by `control_plane_repo_url`. In ignored `terraform.tfvars`, check `create_root_application = true`, the repository URL, revision and chart path, then manually set:

```hcl
root_automated_sync = true
```

From this checkout with your AWS SSO session authenticated:

```bash
export AWS_PROFILE=infra-ops
export KUBECONFIG="$PWD/.local/kubeconfig"
export PATH="$PWD/.local/bin:$PATH"
terraform plan -out=.local/root-gitops.tfplan
```

Review the root Application update, then apply the saved plan:

```bash
terraform apply .local/root-gitops.tfplan
kubectl -n argocd get applications
```

Terraform owns the root Application; Argo CD now reconciles its configured repository automatically. Later configuration commits need no bootstrap rerun. For private sources, keep their URLs in `github_repos` and ensure the saved token can read them; repository credential changes also go through Terraform.

Automatic pruning includes `allowEmpty: true`: Git can disable the last child Application and remove its owned resources. Root EKS and bootstrap controllers remain until the separate root teardown.

## GitHub credential flow

Terraform supplies the token → Crossplane stores it in AWS Secrets Manager → External Secrets creates a credential Secret per repository → ArgoCD reads those Secrets. See [credential setup](GITHUB-SECRET-SETUP.md) for ownership, retained copies, and token renewal.

## ArgoCD version

The root uses Helm chart **10.10.5** with image **v3.5.6** explicitly pinned (the chart defaults to 3.5.5). Apply version changes through the root bootstrap. See [validation evidence](docs/validation.md).

## ArgoCD access

The class configuration enables the built-in admin account and anonymous admin access. With ingress enabled, obtain the address using `kubectl -n argocd get ingress`. Alternatively:

```bash
kubectl -n argocd port-forward svc/argocd-server 8080:80
# Open http://localhost:8080
```

## Root operations

- [Validation](docs/validation.md): root readiness and expected stopping point.
- [Operator actions](docs/operator-actions.md): authentication and credential renewal.
- [Cluster access](docs/cluster-access.md): Terraform-owned administrator access.
- [Teardown](docs/teardown.md): `scripts/teardown.py prepare`, `plan`, `apply`, and `verify` for root-only checkpoints.

Keep Terraform state and private inputs in this checkout. Never initialize replacement state to work around an unavailable cluster.
