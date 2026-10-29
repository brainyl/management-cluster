---
name: validate-control-plane
description: Validate and maintain the root management cluster without expanding beyond its scope.
---

# Validate the root management cluster

This repository owns Terraform for the root EKS cluster, its controllers, AWS identities, repository credentials, and root Argo CD Application. It hosts management components only.

## Workflow

1. Inspect the existing root implementation before changing it. Keep EKS **1.37** consistent across this module's defaults and examples.
2. Establish the intended AWS identity, account, region, Terraform state and Kubernetes context. Preserve state and private inputs; never initialize replacement state to bypass an unavailable endpoint.
3. Review planned actions before applying. Keep root automatic sync disabled at the root-only teaching checkpoint; enabling it can reconcile resources beyond this lesson.
4. Maintain and use root bootstrap and verification in this repository’s `scripts/` directory. Do not duplicate these scripts in the playbook. Keep Terraform state, logs and kubeconfigs in this module. Automate repeatable work and document unavoidable operator actions with their purpose and repeat conditions.
5. Verify controller/provider readiness, credential synchronization and Git repository rendering. Distinguish local checks from live verification.
6. Before deletion, keep controllers and provisioning identities until all resources they own are verified absent. Preserve cleanup evidence.

The class intentionally enables the built-in Argo CD admin account and anonymous admin access. Preserve that configuration unless explicitly asked to change it.

## Documentation boundary

Keep this repository's README and documentation limited to root setup, credentials, access, operation and validation. Do not add a project-wide repository inventory, complete architecture, application details or cross-layer deployment history.

Record concise root and full-project evidence in `/Users/brainyl/code/control-plane-architecture/platform-engineering-playbook/instructor/operations/validation.md`: purpose, material changes, dated verification, and unresolved issues. Do not append evidence to this module's `docs/validation.md`. Teaching orchestration also belongs in the private playbook. Never commit credentials, kubeconfigs, Terraform state, saved plans or private logs.
