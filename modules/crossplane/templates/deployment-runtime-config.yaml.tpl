apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: ${runtime_config_name}
spec:
  # Configure all providers to use the same service account
  serviceAccountTemplate:
    metadata:
      name: ${service_account_name}
  deploymentTemplate:
    spec:
      selector: {}
      template:
        spec:
          containers:
            - name: package-runtime
              resources:
                requests:
                  cpu: 250m
                  memory: 1Gi
