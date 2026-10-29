# Root operator actions

| Action | Why | Repeat when |
| --- | --- | --- |
| `aws sso login --profile infra-ops` | Authenticate Terraform and Kubernetes access | SSO session expires |
| Configure ignored `terraform.tfvars` | Select the account's region, cluster settings and Git repository inputs | First setup or an intentional configuration change |
| Issue a GitHub token and set `github_token` | Allow Argo CD to read configured private repositories | First setup, expiry or revocation |
| Run the bootstrap stage and review its actions | Provision the root and install its controllers in dependency order | Initial deployment or a root configuration change |

See [bootstrap](../README.md#bootstrap) and [credential renewal](../GITHUB-SECRET-SETUP.md). The script automates provisioning and readiness checks; it cannot issue credentials or renew an interactive SSO session.

For local Argo CD access, run `kubectl -n argocd port-forward svc/argocd-server 8080:80` with the root kubeconfig selected. Repeat when the tunnel closes. This creates no cloud resources.

When root automatic sync is enabled, pruning includes `allowEmpty: true`: Git may intentionally disable its last child Application. Argo removes that Application and its owned resources through its deletion finalizer. Root EKS and Terraform-owned controllers remain until the separate root teardown.
