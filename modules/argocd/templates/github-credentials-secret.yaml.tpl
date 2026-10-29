# Crossplane Secret for GitHub credentials in AWS Secrets Manager (created once)
apiVersion: secretsmanager.aws.upbound.io/v1beta1
kind: Secret
metadata:
  name: github-org-credentials
  namespace: ${crossplane_namespace}
  labels:
    secret: github-org-credentials
spec:
  forProvider:
    name: github-org-credentials
    region: ${aws_region}
    description: "GitHub organization credentials for ArgoCD"
  providerConfigRef:
    name: ${provider_config_name}
---
# SecretVersion to set the actual secret value
apiVersion: v1
kind: Secret
metadata:
  name: github-credentials-source
  namespace: ${crossplane_namespace}
type: Opaque
stringData:
  credentials: |
    {
      "username": "git",
      "password": "${github_token}"
    }
---
apiVersion: secretsmanager.aws.upbound.io/v1beta1
kind: SecretVersion
metadata:
  name: github-org-credentials-version
  namespace: ${crossplane_namespace}
spec:
  forProvider:
    region: ${aws_region}
    secretIdSelector:
      matchLabels:
        secret: github-org-credentials
    secretStringSecretRef:
      name: github-credentials-source
      namespace: ${crossplane_namespace}
      key: credentials
  providerConfigRef:
    name: ${provider_config_name}
---
# External Secrets uses Pod Identity and assumes the configured Secrets Manager role.
apiVersion: external-secrets.io/v1
kind: ClusterSecretStore
metadata:
  name: aws-secretsmanager
spec:
  provider:
    aws:
      service: SecretsManager
      region: ${aws_region}
      role: ${eso_workload_role_arn}
