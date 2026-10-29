apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ${app_name}
  namespace: ${namespace}
  labels:
    app.kubernetes.io/name: ${app_name}
    app.kubernetes.io/component: root-application
    app.kubernetes.io/managed-by: terraform
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  
  source:
    repoURL: ${repo_url}
    targetRevision: ${target_revision}
    path: ${chart_path}
    helm:
      releaseName: ${app_name}
      # Values can be overridden here if needed
      # values: |
      #   key: value
  
  destination:
    server: https://kubernetes.default.svc
    namespace: ${destination_namespace}
  
  syncPolicy:
%{ if automated_sync ~}
    automated:
      prune: true       # Remove resources deleted from Git
      selfHeal: true    # Revert manual changes
      allowEmpty: true  # Allow Git to disable the last included Application
%{ endif ~}
    
    syncOptions:
      - CreateNamespace=true  # Auto-create destination namespace
      - PrunePropagationPolicy=foreground  # Delete dependents first
      - PruneLast=true  # Prune after all other resources are synced
    
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  
  # Ignore differences in certain fields (optional)
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore replica count changes (for HPA)
