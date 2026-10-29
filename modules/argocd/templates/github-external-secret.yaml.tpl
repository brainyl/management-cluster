# ExternalSecret to sync GitHub credentials to ArgoCD format
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ${repo_secret_name}
  namespace: ${argocd_namespace}
spec:
  refreshPolicy: Periodic
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secretsmanager
    kind: ClusterSecretStore
  target:
    name: ${repo_secret_name}
    creationPolicy: Owner
    template:
      type: Opaque
      metadata:
        labels:
          argocd.argoproj.io/secret-type: repository
      data:
        type: git
        url: ${repo_url}
        username: "{{ .username }}"
        password: "{{ .password }}"
  dataFrom:
    - extract:
        key: github-org-credentials
