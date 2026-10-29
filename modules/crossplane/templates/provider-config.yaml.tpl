apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: ${provider_config_name}
spec:
  credentials:
    source: PodIdentity
