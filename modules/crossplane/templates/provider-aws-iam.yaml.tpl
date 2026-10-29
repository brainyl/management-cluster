apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws-iam
spec:
  package: xpkg.upbound.io/upbound/provider-aws-iam:${provider_version}
  packagePullPolicy: IfNotPresent
  runtimeConfigRef:
    name: ${runtime_config_name}
