# Quick start

Follow [Bootstrap in the README](README.md#bootstrap). The automated entry point is:

```bash
AWS_PROFILE=infra-ops EXPECTED_AWS_ACCOUNT_ID=420924156696 \
  ./scripts/bootstrap.sh
```

Configure the ignored `terraform.tfvars` and authenticate first. The command stages EKS, controllers/CRDs, then GitOps resources. See [validation notes](docs/validation.md) for current deployment evidence and operator prerequisites.
