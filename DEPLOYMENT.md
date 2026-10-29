# Deployment

Use the staged [bootstrap command](README.md#bootstrap). A single full Terraform plan cannot reliably bootstrap custom resources before their CRDs exist; the command handles that ordering and finishes with a full reconciliation.

This management cluster uses Kubernetes **1.37** and hosts management components only.

Keep Terraform state and private variable files outside Git. See [validation notes](docs/validation.md) for the current AWS destination, verified results, and documented manual steps.
