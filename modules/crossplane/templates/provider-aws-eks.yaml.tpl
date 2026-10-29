apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-eks
spec:
  package: xpkg.upbound.io/upbound/provider-aws-eks:${provider_version}
  packagePullPolicy: IfNotPresent
  runtimeConfigRef:
    name: ${runtime_config_name}
