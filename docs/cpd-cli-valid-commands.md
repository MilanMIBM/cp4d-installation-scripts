# cpd-cli manage - Valid Commands (v5.3.1)

> Source: `cpd-cli manage --help` against `icr.io/cpopen/cpd/olm-utils-v4:5.3.1`
> Excludes: `setup-instance` and `setup-instance-topology` (deprecated since 5.3.0 - use `install-components` instead)

---

## Registry & Authentication

### `add-cred-to-global-pull-secret`
Update the global image pull secret for a private container registry.
```
cpd-cli manage add-cred-to-global-pull-secret \
  --registry=<PRIVATE_REGISTRY_LOCATION> \
  --registry_pull_user=<PRIVATE_REGISTRY_PULL_USER> \
  --registry_pull_password=<PRIVATE_REGISTRY_PULL_PASSWORD> \
  [--preview=true|false]
```

### `add-icr-cred-to-global-pull-secret`
Update the global image pull secret for the IBM Entitled Registry.
```
cpd-cli manage add-icr-cred-to-global-pull-secret \
  --entitled_registry_key=<IBM_ENTITLEMENT_KEY> \
  [--preview=true|false]
```

### `login-entitled-registry`
Log in to the IBM Entitled Registry before mirroring images.
```
cpd-cli manage login-entitled-registry <IBM_ENTITLEMENT_KEY>
```

### `login-private-registry`
Log in to a private container registry before mirroring images.
```
cpd-cli manage login-private-registry \
  <PRIVATE_REGISTRY_LOCATION> \
  [<PRIVATE_REGISTRY_PUSH_USER>] \
  [<PRIVATE_REGISTRY_PUSH_PASSWORD>]
```

### `login-to-ocp`
Log in to OpenShift Container Platform (same args as `oc login`).
```
cpd-cli manage login-to-ocp <openshift login arguments>
# e.g.
cpd-cli manage login-to-ocp --server=https://apiserver:6443 -u kubeadmin -p <password>
cpd-cli manage login-to-ocp --server=https://apiserver:6443 --token=sha256~<token>
```

---

## CASE Packages & Patches

### `case-download`
Download CASE packages to the client workstation.
```
cpd-cli manage case-download \
  --release=<version> \
  --components=<comma-separated list> \
  [--from_oci=true|false] \
  [--oci_location=<registry URL>] \
  [--cluster_resources=true|false] \
  [--operator_ns=<project name>] \
  [--scheduler_ns=<project name>] \
  [--swhcc_operator_ns=<project name>] \
  [--patch_id=<patch ID>]
```

### `patch-download`
Download patch metadata from GitHub to the client workstation.
```
cpd-cli manage patch-download \
  --release=<version> \
  [--patch_id=<patch ID>]
```

### `list-patch`
Scan cluster for installed components and list available patches.
```
cpd-cli manage list-patch \
  [--release=<version>] \
  [--instance_ns=<project name>] \
  [--patch_id=<patch ID>]
```

### `apply-patch`
Apply the latest patch to all components on an IBM Software Hub instance.
```
cpd-cli manage apply-patch \
  --release=<version> \
  --operator_ns=<project name> \
  --instance_ns=<project name> \
  [--scheduler_ns=<project name>] \
  [--tethered_instance_ns=<comma-separated list>] \
  [--image_pull_prefix=<registry URL>] \
  [--image_pull_secret=<secret name>] \
  [--param-file=<file name>] \
  [--patch_id=<patch ID>]
```

---

## Cluster Setup & Configuration

### `apply-cluster-components`
Install or upgrade cluster-wide components (e.g. `ibm-licensing-operator`).
```
cpd-cli manage apply-cluster-components \
  --release=<version> \
  --license_acceptance=true|false \
  [--licensing_ns=<project name>] \
  [--case_download=true|false] \
  [--from_oci=true|false] \
  [--oci_location=<registry URL>] \
  [--patch_id=<patch ID>] \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

### `apply-scheduler`
Install or upgrade the scheduling service.
```
cpd-cli manage apply-scheduler \
  --release=<version> \
  --license_acceptance=true|false \
  --scheduler_ns=<project name> \
  [--case_download=true|false] \
  [--from_oci=true|false] \
  [--oci_location=<registry URL>] \
  [--catsrc=true|false] \
  [--sub=true|false] \
  [--preview=true|false] \
  [--patch_id=<patch ID>] \
  [--remote_cluster] \
  [--image_pull_prefix=<pull prefix>] \
  [--image_pull_secret=<pull secret>] \
  [--use_olm=true|false] \
  [--param-file=<file name>]
```

### `authorize-instance-topology`
Create projects, set up NamespaceScope operator, apply required roles. Run before `install-components`.
```
cpd-cli manage authorize-instance-topology \
  --cpd_operator_ns=<project name> \
  --cpd_instance_ns=<project name> \
  [--additional_ns=<comma-separated list>] \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

### `apply-db2-kubelet`
Apply required kubelet configuration for Db2U kernel parameters.
```
cpd-cli manage apply-db2-kubelet \
  [--preview=true|false] \
  [--force=true|false]
```

### `apply-pid-limit`
Create a KubeletConfig to change the number of process IDs a pod can use.
```
cpd-cli manage apply-pid-limit \
  [--preview=true|false] \
  [--pid_limit=<number of process IDs>]
```

### `apply-icsp`
Create the image content source policy for a private container registry.
```
cpd-cli manage apply-icsp \
  --registry=<PRIVATE_REGISTRY_LOCATION> \
  [--preview=true|false]
```

### `apply-scc`
Create a custom security context constraint (SCC) for the `informix` component.
```
cpd-cli manage apply-scc \
  --cpd_instance_ns=<project name> \
  --components=<component names> \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

---

## Install & Upgrade Components

### `install-components`
Install or upgrade components on an IBM Software Hub instance. **Replaces deprecated `setup-instance` and `setup-instance-topology`.**
```
cpd-cli manage install-components \
  --license_acceptance=true|false \
  --components=<comma-separated list> \
  --release=<version> \
  --operator_ns=<project name> \
  --instance_ns=<project name> \
  [--tethered_instance_ns=<comma-separated list>] \
  [--block_storage_class=<RWO storage class>] \
  [--file_storage_class=<RWX storage class>] \
  [--storage_vendor=portworx] \
  [--image_pull_prefix=<registry URL>] \
  [--image_pull_secret=<secret name>] \
  [--upgrade=true|false] \
  [--skip_components=<comma-separated list>] \
  [--catsrc=true|false] \
  [--sub=true|false] \
  [--param-file=<file name>] \
  [--run_storage_tests=true|false] \
  [--patch_id=<patch ID>] \
  [--preview=true|false]
```

### `uninstall-components`
Uninstall components from an instance (removes helm releases, K8s resources, OLM artifacts, CRs).
```
cpd-cli manage uninstall-components \
  --instance_ns=<project name> \
  --components=<comma-separated list> \
  [--delete_all_components=true|false] \
  [--include_dependency=true|false] \
  [--preview=true|false]
```

### `setup-control-center`
Install or upgrade IBM Software Hub Control Center.
```
cpd-cli manage setup-control-center \
  --release=<version> \
  --license_acceptance=true|false \
  --operator_ns=<project name> \
  --operand_ns=<project name> \
  --block_storage_class=<RWO storage class name> \
  [--case_download=true|false] \
  [--from_oci=true|false] \
  [--oci_location=<registry URL>] \
  [--catsrc=true|false] \
  [--sub=true|false] \
  [--skip_components=<comma-separated list>] \
  [--param-file=<file name>] \
  [--image_pull_secret=<secret name>] \
  [--image_pull_prefix=<registry URL>] \
  [--preview=true|false] \
  [--use_olm=true|false] \
  [--upgrade=true|false] \
  [--patch=true|false] \
  [-v|-vv|-vvv]
```

---

## Custom Resources & Status

### `get-cr-status`
Get status of installed components (CR status, version, timestamps).
```
cpd-cli manage get-cr-status \
  [--cpd_instance_ns=<project name>] \
  [--tethered_instance_ns=<comma-separated list>] \
  [--cluster_component_ns=<project name>] \
  [--components=<comma-separated list>] \
  [--include_dependency=true|false] \
  [--filter=cr_kind,cr_name,namespace,expected_version,reconciled_version,operator_info,progress,progress_message,error_history,cr_status] \
  [--param-file=<file name>]
```

### `update-cr`
Update the spec of a custom resource for a component.
```
cpd-cli manage update-cr \
  --component=<component name> \
  --patch=<patch JSON to apply to spec> \
  [--cpd_instance_ns=<project name>] \
  [--cluster_component_ns=<project name>] \
  [--tethered_instance_ns=<project name>] \
  [-v|-vv|-vvv]
```

### `delete-cr`
Delete custom resources for specified components (uninstall step).
```
cpd-cli manage delete-cr \
  --cpd_instance_ns=<project name> \
  --components=<comma-separated list> \
  [--include_dependency=true|false] \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

### `delete-cluster-scoped-resources`
Generate uninstall list for cluster-scoped resources (cluster roles, webhooks, CRDs).
```
cpd-cli manage delete-cluster-scoped-resources \
  [--operator_ns=<project name>] \
  [--components=<comma-separated list>] \
  [--delete_all_components=true|false] \
  [--include_dependency=true|false] \
  [--cleanup_all_instances=true|false]
```

### `delete-olm-artifacts`
Remove OLM artifacts (catalog sources, CSVs, subscriptions) for specified components.
```
cpd-cli manage delete-olm-artifacts \
  --cpd_operator_ns=<project name> \
  [--components=<comma-separated list>] \
  [--delete_all_components=true] \
  [--delete_shared_catsrc=true] \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

### `get-olm-artifacts`
Get the list of catalog sources and operator subscriptions on the cluster.
```
cpd-cli manage get-olm-artifacts \
  [--subscription_ns=<project name>]
```

---

## Listing & Discovery

### `list-components`
Get the list of components supported by `cpd-cli manage`. Output saved to `components.csv`.
```
cpd-cli manage list-components \
  --release=<version>
```

### `list-deployed-components`
List components installed in a specific IBM Software Hub instance.
```
cpd-cli manage list-deployed-components \
  --cpd_instance_ns=<project name> \
  [--scheduler_ns=<project name>] \
  [--all=true|false]
```

### `list-prereqs`
List prerequisite components for specified components.
```
cpd-cli manage list-prereqs \
  --release=<version> \
  --components=<comma-separated list>
```

### `list-dependents`
List components that depend on the specified components.
```
cpd-cli manage list-dependents \
  --release=<version> \
  --components=<comma-separated list>
```

### `get-cpd-instance-details`
Get the web client URL and default `cpadmin` credentials.
```
cpd-cli manage get-cpd-instance-details \
  --cpd_instance_ns=<project name> \
  [--get_admin_initial_credentials=true|false]
```

### `get-k8s-details`
Get detailed information about K8s objects associated with IBM Software Hub.
```
cpd-cli manage get-k8s-details \
  [--addonID=<addonID-label>] \
  [--app=<app-label>] \
  [--module=<module-label>] \
  [--kind=deployment|statefulset|configmap|pvc|job|cronjob|service|secret] \
  [--object_name=<resource name>] \
  [--cpd_instance_ns=<project name>] \
  [--dependency=<dependency>] \
  [--scope=<scope>] \
  [--show_scope=true|false] \
  [--output=json]
```

### `get-license`
Get the URL to view the specified software license.
```
cpd-cli manage get-license \
  --release=<version> \
  [--license_types=<EE|SE|...>]
```

### `collect-state`
Capture operational K8s state for IBM Support troubleshooting. Output saved to `collect-state.tar.gz`.
```
cpd-cli manage collect-state \
  [--cpd_instance_ns=<project name>]
```

### `versioninfo`
Get version info about the `olm-utils-play` image, `oc`, `ibm-pak`, and `skopeo`.
```
cpd-cli manage versioninfo
```

---

## Scaling & HPA

### `apply-scale-config`
Change scaling configuration for one or more components.
```
cpd-cli manage apply-scale-config \
  --cpd_instance_ns=<project name> \
  [--tethered_ns=<project name>] \
  [--config='{"component":"level_N",...}'] \
  [--components=<comma-separated list>] \
  [--scale=level_1|level_2|level_3|level_4|level_5] \
  [--wait=true|false] \
  [--param-file=<file path>]
```

### `get-scale-config`
Get current scaling configuration for components.
```
cpd-cli manage get-scale-config \
  --cpd_instance_ns=<project name> \
  [--tethered_ns=<project name>] \
  [--components=<comma-separated list>] \
  [--param-file=<file name>]
```

### `apply-hpa-config`
Enable or disable horizontal pod autoscaling for components.
```
cpd-cli manage apply-hpa-config \
  --cpd_instance_ns=<project name> \
  --components=<comma-separated list> \
  --enable_hpa=true|false \
  [--wait=true|false] \
  [--param-file=<file path>]
```

### `get-hpa-config`
Get current HPA configuration for components.
```
cpd-cli manage get-hpa-config \
  --cpd_instance_ns=<project name> \
  [--components=<comma-separated list>] \
  [--param-file=<file name>]
```

### `apply-cluster-component-scale-config`
Change scaling configuration for a shared cluster component (e.g. `scheduler`).
```
cpd-cli manage apply-cluster-component-scale-config \
  --cluster_component_ns=<project name> \
  --component=<component name> \
  --release=<version> \
  --scale=level_1|level_2|level_3|level_4|level_5 \
  [--wait=true|false]
```

### `get-cluster-component-scale-config`
Get current scaling configuration for a shared cluster component.
```
cpd-cli manage get-cluster-component-scale-config \
  --cluster_component_ns=<project name> \
  --component=<component name> \
  --release=<version>
```

### `apply-cluster-component-hpa-config`
Enable or disable HPA for a shared cluster component.
```
cpd-cli manage apply-cluster-component-hpa-config \
  --cluster_component_ns=<project name> \
  --component=<component name> \
  --release=<version> \
  --enable_hpa=true|false \
  [--wait=true|false]
```

### `get-cluster-component-hpa-config`
Get HPA configuration for a shared cluster component.
```
cpd-cli manage get-cluster-component-hpa-config \
  --cluster_component_ns=<project name> \
  --component=<component name> \
  --release=<version>
```

---

## Image Management

### `mirror-images`
Mirror images for specified components to a private container registry.
```
cpd-cli manage mirror-images \
  --components=<comma-separated list> \
  --release=<version> \
  --target_registry=<registry URL> \
  [--source_registry=127.0.0.1:12443] \
  [--arch=amd64|ppc64le|s390x] \
  [--case_download=true|false] \
  [--from_oci=true|false] \
  [--oci_location=<registry URL>] \
  [--retry_count=3] \
  [--retry_delay=30] \
  [--param-file=<file name>] \
  [--groups=<comma-separated list>] \
  [--patch_id=<patch ID>] \
  [--registry=<registry URL>] \
  [--registry_user=<user>] \
  [--registry_password=<password>] \
  [-v|-vv|-vvv]
```

### `list-images`
Get the list of images associated with specified components. Output saved to `list_images.csv`.
```
cpd-cli manage list-images \
  --release=<version> \
  --components=<comma-separated list> \
  [--case_download=true|false] \
  [--inspect_source_registry=true|false] \
  [--target_registry=<registry URL>] \
  [--patch_id=<patch ID>]
```

### `delete-images`
Mark images no longer needed for deletion from a registry.
```
cpd-cli manage delete-images \
  --release_to_delete=<version> \
  --release_to_keep=<comma-separated versions> \
  --components=<comma-separated list> \
  --target_registry=<registry URL> \
  [--preview=true|false]
```

### `copy-image`
Copy an image from one registry location to another.
```
cpd-cli manage copy-image \
  --from=<source-image-location-and-name> \
  --to=<target-image-location-and-name>
```

### `pull-image`
Pull an image from a registry and load it into the local container runtime.
```
cpd-cli manage pull-image \
  --from=<source-image-location-and-name> \
  [--tag=<target-image-name>]
```

### `save-image`
Save an image as a compressed TAR file in the work directory.
```
cpd-cli manage save-image \
  --from=<source-image-location-and-name>
```

### `load-image`
Load a saved image into the local container runtime.
```
cpd-cli manage load-image \
  --source-image=<source-image-location-and-name> \
  [--tag=<target-image-name>]
```

---

## Licensing & Entitlements

### `apply-entitlement`
Give the License Service information about purchased licenses.
```
cpd-cli manage apply-entitlement \
  --cpd_instance_ns=<project name> \
  --entitlement=<license-type> \
  [--production=true|false] \
  [--vpc_node_labels=<comma-separated node labels>] \
  [--vpc_node_list=<comma-separated node names>] \
  [--non_vpc_node_labels=<comma-separated node labels>] \
  [--non_vpc_node_list=<comma-separated node names>] \
  [--gpu_node_labels=<comma-separated node labels>] \
  [--gpu_node_list=<comma-separated node names>] \
  [--restart_pods=true|false] \
  [--enforce_pinning=true|false] \
  [--preview=true|false]
```
Valid `--entitlement` values include: `cpd-enterprise`, `cpd-standard`, `watsonx-ai`, `watsonx-data`, `watsonx-data-premium`, `watsonx-dataintelligence`, `watsonx-orchestrate`, `watson-assistant`, `datastage`, `datastage-plus`, `ikc-standard`, `ikc-premium`, `watsonx-gov-mm`, `watsonx-gov-rc`, and many more - see `--help` for full list.

### `remove-entitlement`
Tell the License Service to stop tracking a specific license.
```
cpd-cli manage remove-entitlement \
  --cpd_instance_ns=<project name> \
  --entitlement=<license-type> \
  [--production=true|false] \
  [--restart_pods=true|false] \
  [--preview=true|false]
```

### `list-entitlements`
List entitlements present in an instance namespace.
```
cpd-cli manage list-entitlements \
  --cpd_instance_ns=<project name> \
  [--entitlement=<license-type>]
```

---

## Lifecycle: Restart & Shutdown

### `restart`
Restart components in the specified order (restarts dependencies first if needed).
```
cpd-cli manage restart \
  --components=<comma-separated list> \
  --cpd_instance_ns=<project name> \
  [--tethered_instance_ns=<project name>] \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

### `shutdown`
Shut down components in the specified order.
```
cpd-cli manage shutdown \
  --components=<comma-separated list> \
  --cpd_instance_ns=<project name> \
  [--tethered_instance_ns=<project name>] \
  [--include_dependency=true|false] \
  [--force=true|false] \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

### `restart-container`
Restart the `olm-utils-play` container to ensure the latest image is in use.
```
cpd-cli manage restart-container
```

---

## Tethered Namespaces & Topology

### `setup-tethered-ns`
Tether a project to the IBM Software Hub control plane project.
```
cpd-cli manage setup-tethered-ns \
  --cpd_instance_ns=<project name> \
  --tethered_instance_ns=<project name> \
  [--remove=true|false] \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

---

## Proxy Configuration

### `create-proxy-config`
Create proxy configuration resources for IBM Software Hub.
```
cpd-cli manage create-proxy-config \
  --cpd_instance_ns=<project name> \
  [--proxy_host=<proxy host>] \
  [--proxy_port=<proxy port>] \
  [--proxy_user=<proxy user>] \
  [--proxy_password=<proxy password>] \
  [--no_proxy=<no-proxy list>] \
  [-v|-vv|-vvv]
```

### `enable-proxy`
Apply an HTTP proxy configuration to an IBM Software Hub instance.
```
cpd-cli manage enable-proxy \
  --cpd_instance_ns=<project name> \
  [-v|-vv|-vvv]
```

### `disable-proxy`
Disable the HTTP proxy configuration for an IBM Software Hub instance.
```
cpd-cli manage disable-proxy \
  --cpd_instance_ns=<project name> \
  [-v|-vv|-vvv]
```

### `get-proxy-config`
Get proxy configuration details and associated RSI patches.
```
cpd-cli manage get-proxy-config \
  --cpd_instance_ns=<project name> \
  [-v|-vv|-vvv]
```

### `delete-proxy`
Delete RSI patches for HTTP proxy configuration.
```
cpd-cli manage delete-proxy \
  --cpd_instance_ns=<project name> \
  [-v|-vv|-vvv]
```

---

## RSI (Resource Spec Injection) Patches

### `create-rsi-patch`
Create or update an RSI patch (env vars, labels, annotations, pod spec).
```
cpd-cli manage create-rsi-patch \
  --cpd_instance_ns=<project name> \
  --patch_name=<patch name> \
  [--patch_type=rsi_pod_env_var|rsi_pod_label|rsi_pod_annotation|rsi_pod_spec] \
  [--description=<description>] \
  [--patch_spec=<JSON file path>] \
  [--select_all_pods=true|false] \
  [--spec_format=json|json-merge|set-env] \
  [--include_labels=<key:value,...>] \
  [--exclude_labels=<key:value,...>] \
  [--state=active|inactive] \
  [--skip_apply=true|false] \
  [-v|-vv|-vvv]
```

### `apply-rsi-patches`
Apply all active RSI patches in a project.
```
cpd-cli manage apply-rsi-patches \
  --cpd_instance_ns=<project name> \
  [-v|-vv|-vvv]
```

### `get-rsi-patch-info`
Get info or status about RSI patches in a project.
```
cpd-cli manage get-rsi-patch-info \
  --cpd_instance_ns=<project name> \
  [--patch_name=<patch name>] \
  [--all]
```

### `get-rsi-patch-logs`
Extract and display logs from the RSI webhook pod.
```
cpd-cli manage get-rsi-patch-logs \
  --cpd_instance_ns=<project name> \
  [--patch_name=<patch name>] \
  [-v|-vv|-vvv]
```

### `delete-rsi-patch`
Delete one or all RSI patches in a project.
```
cpd-cli manage delete-rsi-patch \
  --cpd_instance_ns=<project name> \
  [--patch_name=<patch name>] \
  [--all]
```

---

## CA Certificates & Admission Controller

### `install-cpd-config-ac`
Install the IBM Software Hub configuration admission controller (`cpd-config-ac`).
```
cpd-cli manage install-cpd-config-ac \
  --cpd_instance_ns=<project name> \
  [--cpd_config_ac_image=<image location>] \
  [--image_pull_secret=<secret name>] \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

### `enable-cpd-config-ac`
Enable the `cpd-config-ac` webhook. Run after `install-cpd-config-ac`.
```
cpd-cli manage enable-cpd-config-ac \
  --cpd_instance_ns=<project name> \
  [-v|-vv|-vvv]
```

### `uninstall-cpd-config-ac`
Uninstall the admission controller and remove the mutating webhook.
```
cpd-cli manage uninstall-cpd-config-ac \
  --cpd_instance_ns=<project name> \
  [-v|-vv|-vvv]
```

### `gen-platform-ca-certs`
Update the `cpd-platform-ca-certs` secret and inject it into IBM Software Hub pods.
```
cpd-cli manage gen-platform-ca-certs \
  --cpd_instance_ns=<project name> \
  [--apply=true|false] \
  [-v|-vv|-vvv]
```

### `delete-platform-ca-certs`
Remove the `cpd-platform-ca-certs` secret from pods and delete it.
```
cpd-cli manage delete-platform-ca-certs \
  --cpd_instance_ns=<project name> \
  [-v|-vv|-vvv]
```

### `list-platform-ca-certs-pods`
List pods injected with `cpd-platform-ca-certs` and pods where injection failed.
```
cpd-cli manage list-platform-ca-certs-pods \
  --cpd_instance_ns=<project name>
```

---

## Monitoring & Service Monitors

### `apply-privileged-monitoring-service`
Deploy the privileged monitoring service for IBM Software Hub.
```
cpd-cli manage apply-privileged-monitoring-service \
  --privileged_service_ns=<project name> \
  --cpd_operator_ns=<project name> \
  --cpd_instance_ns=<project name> \
  [--cluster_components_ns=<comma-separated list>] \
  [--enable_hpa=true|false] \
  [--preview=true|false]
```

### `delete-privileged-monitoring-service`
Delete the privileged monitoring service.
```
cpd-cli manage delete-privileged-monitoring-service \
  --privileged_service_ns=<project name> \
  --cpd_operator_ns=<project name> \
  --cpd_instance_ns=<project name> \
  [--cluster_components_ns=<comma-separated list>]
```

### `apply-service-monitor`
Deploy service monitors for an IBM Software Hub instance.
```
cpd-cli manage apply-service-monitor \
  --cpd_instance_ns=<project name> \
  [--image_prefix=<image location>] \
  [--image_name=<image name>] \
  [--preview=true|false]
```

### `delete-service-monitor`
Remove service monitors installed by `apply-service-monitor`.
```
cpd-cli manage delete-service-monitor \
  --cpd_instance_ns=<project name>
```

---

## IBM Events / Knative Eventing

### `deploy-events-operator`
Install or upgrade the IBM Events Operator (required for watsonx Assistant and Orchestrate).
```
cpd-cli manage deploy-events-operator \
  --release=<version> \
  --events_operator_ns=<project name> \
  --events_operand_ns=<project name> \
  [--docker_registry=<registry>] \
  [--image_pull_secret=<secret>] \
  [--cluster_resources=true|false] \
  [--dry_run] \
  [--preview]
```

### `remove-events-operator`
Safely remove the IBM Events Operator, checking for other installations first.
```
cpd-cli manage remove-events-operator \
  --events_operator_ns=<project name> \
  [--force] \
  [--preview]
```

### `deploy-knative-eventing`
Set up Red Hat OpenShift Serverless + Knative Eventing + IBM Events Operator.
```
cpd-cli manage deploy-knative-eventing \
  --release=<version> \
  [--block_storage_class=<RWO storage class>] \
  [--storage_vendor=portworx] \
  [--from_oci=true|false] \
  [--oci_location=<registry URL>] \
  [--events_operator_ns=<project name>] \
  [--patch_redhat_crd=true|false] \
  [--demo_mode=true|false] \
  [--upgrade=true|false] \
  [--docker_registry=<registry>] \
  [--image_pull_secret=<secret>] \
  [--preview]
```

### `remove-knative-eventing`
Remove Knative Eventing and associated resources.
```
cpd-cli manage remove-knative-eventing \
  [--events_operator_ns=<project name>] \
  [--delete_kafka_resources=true|false] \
  [--delete_openshift_serverless=true|false] \
  [--delete_knative_crds=true|false] \
  [--delete_provided_ibm_events_ns=true|false] \
  [--force_delete_events_operator] \
  [--preview]
```

---

## Physical Locations & Data Planes (Premium)

### `create-physical-location`
Install IBM Software Hub agents on a remote cluster.
```
cpd-cli manage create-physical-location \
  --physical_location_name=<unique ID> \
  --physical_location_host=<hostname> \
  --management_ns=<project name> \
  --workload_ns=<project name> \
  --cpd_hub_url=<cpd route> \
  --cpd_hub_api_key=<base64 encoded API key> \
  --block_storage_class=<RWO storage class> \
  --release=<version> \
  [--image_pull_secret=<secret name>] \
  [--image_prefix=<registry prefix>] \
  [--generate_digests=true|false] \
  [--upgrade=true|false]
```

### `register-physical-location`
Register a physical location with the primary IBM Software Hub instance.
```
cpd-cli manage register-physical-location \
  --physical_location_name=<unique ID> \
  --display_name=<display name> \
  --cpd_hub_url=<cpd route> \
  --cpd_hub_api_key=<base64 encoded API key> \
  [--description=<description>] \
  [--enabled=true|false] \
  [--priority=high|low] \
  [--region=<region>] \
  [--max_cpu=<vCPU>] \
  [--max_memory=<memory>] \
  [--max_gpu=<GPU>] \
  [--max_cpu_arm=<ARM vCPU>] \
  [--max_memory_arm=<ARM memory>] \
  [--max_gpu_arm=<ARM GPU>]
```

### `edit-physical-location`
Edit attributes of a registered physical location.
```
cpd-cli manage edit-physical-location \
  --physical_location_name=<unique ID> \
  --cpd_hub_url=<cpd route> \
  --cpd_hub_api_key=<base64 encoded API key> \
  [--display_name=<display name>] \
  [--description=<description>] \
  [--enabled=true|false] \
  [--region=<region>]
```

### `delete-physical-location`
Remove IBM Software Hub agents from a physical location.
```
cpd-cli manage delete-physical-location \
  --physical_location_name=<unique ID> \
  --management_ns=<project name> \
  --cpd_hub_url=<cpd route> \
  --cpd_hub_api_key=<base64 encoded API key>
```

### `get-physical-locations`
Get information about one or more physical locations.
```
cpd-cli manage get-physical-locations \
  --cpd_hub_url=<cpd route> \
  --cpd_hub_api_key=<base64 encoded API key> \
  [--name=<physical location name>] \
  [--all] \
  [--include_data_planes=true|false]
```

### `enable-default-data-plane`
Install IBM Software Hub agents on the same cluster for local custom applications.
```
cpd-cli manage enable-default-data-plane \
  --instance_ns=<project name> \
  --management_ns=<project name> \
  --workload_ns=<project name> \
  [--image_pull_secret=<secret name>] \
  [--image_prefix=<registry prefix>] \
  [--upgrade=true|false]
```

### `disable-default-data-plane`
Disable the default local data plane.
```
cpd-cli manage disable-default-data-plane \
  --instance_ns=<project name>
```

---

## Custom Applications (Premium)

### `create-dockerfile-application`
Create an application from a Git repository containing a Dockerfile.
```
cpd-cli manage create-dockerfile-application \
  --instance_ns=<project name> \
  --app_name=<application name> \
  --app_port=<port> \
  --repo_url=<git URL> \
  --cpu=<cpu request> \
  --cpu_limit=<cpu limit> \
  --memory=<memory request> \
  --memory_limit=<memory limit> \
  [--dataplane_name=<dataplane name>] \
  [--repo_token=<git token>] \
  [--repo_branch=<branch>] \
  [--tls_enabled=true|false] \
  [--repo_app_dir=<app directory>] \
  [--dockerfile=<Dockerfile name>] \
  [--image_ref=<image reference>] \
  [--command='["cmd"]'] \
  [--args='["arg1","arg2"]'] \
  [--app_envs='[{"name":"k","value":"v"}]'] \
  [--app_envs_json=<json file>] \
  [--app_env_from='{"envFrom":[...]}'] \
  [--app_run_id=<run ID>] \
  [--create_route=true|false]
```

### `create-kube-yaml-application`
Create an application from a compressed tar file of Kubernetes YAML files.
```
cpd-cli manage create-kube-yaml-application \
  --instance_ns=<project name> \
  --app_name=<application name> \
  --app_tar_file=<.tgz or .tar.gz file> \
  --cpu=<cpu request> \
  --cpu_limit=<cpu limit> \
  --memory=<memory request> \
  --memory_limit=<memory limit> \
  [--dataplane_name=<dataplane name>] \
  [--app_run_id=<run ID>]
```

### `create-oc-template-application`
Create an application from an OpenShift template tar file.
```
cpd-cli manage create-oc-template-application \
  --instance_ns=<project name> \
  --app_name=<application name> \
  --app_tar_file=<.tgz or .tar.gz file> \
  --cpu=<cpu request> \
  --cpu_limit=<cpu limit> \
  --memory=<memory request> \
  --memory_limit=<memory limit> \
  [--dataplane_name=<dataplane name>] \
  [--app_run_id=<run ID>]
```

### `delete-dockerfile-application`
Delete a Dockerfile-based application by name and run ID.
```
cpd-cli manage delete-dockerfile-application \
  --instance_ns=<project name> \
  --app_name=<application name> \
  --app_run_id=<run ID> \
  [--dataplane_name=<dataplane name>]
```

### `delete-kube-yaml-application`
Delete a kubeyaml application by name and run ID.
```
cpd-cli manage delete-kube-yaml-application \
  --instance_ns=<project name> \
  --app_name=<application name> \
  --app_run_id=<run ID> \
  --app_tar_file=<tar file> \
  [--dataplane_name=<dataplane name>]
```

### `delete-oc-template-application`
Delete a template application by name and run ID.
```
cpd-cli manage delete-oc-template-application \
  --instance_ns=<project name> \
  --app_name=<application name> \
  --app_run_id=<run ID> \
  --app_tar_file=<tar file> \
  [--dataplane_name=<dataplane name>]
```

### `list-custom-applications`
List applications on a data plane.
```
cpd-cli manage list-custom-applications \
  --instance_ns=<project name> \
  [--dataplane_name=<dataplane name>]
```

### `check-custom-application-status`
Get application details and status on a data plane.
```
cpd-cli manage check-custom-application-status \
  --instance_ns=<project name> \
  --app_name=<application name> \
  [--dataplane_name=<dataplane name>] \
  [--app_run_id=<run ID>]
```

### `update-custom-application-proxy-config`
Update proxy configuration for an application.
```
cpd-cli manage update-custom-application-proxy-config \
  --instance_ns=<project name> \
  --app_name=<application name> \
  --app_run_id=<run ID> \
  [--app_proxy_config_yaml=<yaml file>] \
  [--hub_proxy_config_yaml=<yaml file>] \
  [--dataplane_name=<dataplane name>]
```

---

## Premium Features

### `enable-premium-features`
Enable IBM Software Hub Premium features (Argo CD, AI assistant, physical locations, advanced workload management).
```
cpd-cli manage enable-premium-features \
  --license_acceptance=true|false \
  --features=<argo-cd,ai-assistant,physical-locations,adv-workload-mgr> \
  [--operator_ns=<project name>] \
  [--instance_ns=<project name>] \
  [--scheduler_ns=<project name>]
```

### `get-premium-feature-status`
Display the status of premium features (enabled or disabled).
```
cpd-cli manage get-premium-feature-status \
  --instance_ns=<project name> \
  [--features=<argo-cd,ai-assistant,physical-locations,adv-workload-mgr>] \
  [--operator_ns=<project name>] \
  [--scheduler_ns=<project name>]
```

### `create-argo-apps`
Generate Helm-based Argo CD application configurations for IBM Software Hub.
```
cpd-cli manage create-argo-apps \
  --license_acceptance=true|false \
  --release=<version> \
  --argo_ns=<project name> \
  --operator_ns=<project name> \
  --instance_ns=<project name> \
  --components=<comma-separated list> \
  --block_storage_class=<RWO storage class> \
  --file_storage_class=<RWX storage class> \
  --repo_url=<chart repository URL> \
  [--tethered_instance_ns=<comma-separated list>] \
  [--swhcc_operator_ns=<project name>] \
  [--swhcc_instance_ns=<project name>] \
  [--scheduler_ns=<project name>] \
  [--storage_vendor=portworx] \
  [--path=<path to chart>] \
  [--param_file=<file path>] \
  [--case_download=true|false] \
  [--from_oci=true|false] \
  [--oci_location=<registry URL>] \
  [--app-name-suffix=<suffix>] \
  [--project=<ArgoCD project name>]
```

---

## NFS & Rook NFS Storage

### `setup-nfs-provisioner`
Install and configure the Kubernetes NFS-Client Provisioner.
```
cpd-cli manage setup-nfs-provisioner \
  --nfs_server=<NFS server address> \
  [--nfs_provisioner_name=<name>] \
  [--nfs_path=<exported path>] \
  [--nfs_provisioner_ns=<project name>] \
  [--nfs_storageclass_name=<storage class name>] \
  [--nfs_provisioner_image=<image>] \
  [--nfs_path_pattern=<subdirectory name>]
```

### `delete-nfs-provisioner`
Uninstall the Kubernetes NFS-Client Provisioner.
```
cpd-cli manage delete-nfs-provisioner \
  [--nfs_provisioner_name=<name>] \
  [--nfs_provisioner_ns=<project name>] \
  [--nfs_storageclass_name=<storage class name>]
```

### `mirror-nfs-provisioner`
Mirror NFS provisioner images to a private container registry.
```
cpd-cli manage mirror-nfs-provisioner \
  [--target_registry=<registry URL>] \
  [--source_registry=<source registry URL>]
```

### `setup-rook-nfs`
Install the rook-nfs provisioner and storage class.
```
cpd-cli manage setup-rook-nfs \
  --block_storage_class=<RWO storage class> \
  [--storage_size=<size in G>] \
  [--rook_nfs_shared_claim=<claim name>] \
  [--rook_nfs_ns=<project name>] \
  [--rook_nfs_operator_ns=<project name>] \
  [--rook_nfs_sc=<storage class name>] \
  [--rook_nfs_image=<image>]
```

### `delete-rook-nfs`
Delete the rook-nfs provisioner installation.
```
cpd-cli manage delete-rook-nfs \
  [--rook_nfs_ns=<project name>] \
  [--rook_nfs_operator_ns=<project name>] \
  [--rook_nfs_sc=<storage class name>]
```

### `mirror-rook-nfs`
Mirror rook-nfs images for restricted network environments.
```
cpd-cli manage mirror-rook-nfs \
  [--source_registry=<source registry>] \
  [--target_registry=<target registry>]
```

---

## Networking & Routing

### `setup-route`
Replace TLS certificate, customize hostname, or change route termination type.
```
cpd-cli manage setup-route \
  --cpd_instance_ns=<project name> \
  [--custom_hostname=<hostname>] \
  [--route_secret=<certificate secret name>] \
  [--route_type=reencrypt|passthrough] \
  [--preview=true|false]
```

---

## IAM & Identity

### `setup-iam-integration`
Set up the Identity Management service for connecting to an identity provider.
```
cpd-cli manage setup-iam-integration \
  --enable=true \
  --cpd_instance_ns=<project name> \
  [--preview=true|false] \
  [-v|-vv|-vvv]
```

---

## Watson / App Connect / MCG Setup

### `setup-appconnect`
Create App Connect resources required by IBM watsonx Orchestrate.
```
cpd-cli manage setup-appconnect \
  --release=<version> \
  --components=watsonx_orchestrate \
  --cpd_instance_ns=<project name> \
  [--appconnect_ns=<project name>] \
  [--preview=true|false] \
  [--upgrade=true|false]
```

### `setup-mcg`
Create secrets for Watson services to connect to Multicloud Object Gateway.
```
cpd-cli manage setup-mcg \
  --components=<watson_assistant|watson_discovery|watson_speech|watsonx_orchestrate> \
  --cpd_instance_ns=<project name> \
  --noobaa_account_secret=<secret name> \
  --noobaa_cert_secret=<secret name> \
  --noobaa_ns=<project name> \
  [--preview=true|false]
```

---

## RBAC & Security

### `show-minimum-rbac`
Generate minimum RBAC YAML files for components you plan to install.
```
cpd-cli manage show-minimum-rbac \
  --components=<comma-separated list> \
  --release=<version> \
  [--role_name=<prefix>] \
  [--cpd_operator_ns=<project name>] \
  [--param-file=<file path>] \
  [--use_ns_admin=true|false] \
  [--patch_id=<patch ID>] \
  [--use_olm=true|false]
```

---

## Configuration

### `set-config`
Update configuration data in a ConfigMap. Restarts associated pods.
```
cpd-cli manage set-config \
  --cpd_instance_ns=<project name> \
  --configmap_name=<ConfigMap name> \
  [--configmap_spec=<JSON file path>] \
  [--configmap_values=<key:value,...>] \
  [--deployments_to_restart=<comma-separated list>]
```

### `gateway-context-array`
Generate a file mapping route descriptions for RSYSLOG user activity logs.
```
cpd-cli manage gateway-context-array
```
