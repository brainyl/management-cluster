global:
  # Preserve the class networking behavior across chart 10.x.
  networkPolicy:
    create: false
  image:
    tag: v3.5.6
  domain: argocd.local

server:
  replicas: 1
  service:
    type: ${server_service_type}
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 250m
      memory: 256Mi

configs:
  params:
    server.insecure: true
  cm:
    admin.enabled: "true"
    users.anonymous.enabled: "true"

  rbac:
    policy.default: role:admin

controller:
  replicas: 1
  resources:
    limits:
      cpu: 2000m
      memory: 2Gi
    requests:
      cpu: 1000m
      memory: 1Gi

repoServer:
  replicas: 1
  resources:
    limits:
      cpu: 1000m
      memory: 1Gi
    requests:
      cpu: 500m
      memory: 512Mi

applicationSet:
  enabled: false

notifications:
  enabled: false
