# Crossplane Helm chart values
replicas: 1

resources:
  limits:
    cpu: 500m
    memory: 1Gi
  requests:
    cpu: 100m
    memory: 256Mi

metrics:
  enabled: true

# Installed XRD schema changes require a controller refresh.
customAnnotations:
  platform.company.com/schema-revision: "${schema_revision}"
