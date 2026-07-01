================================

---
name: Registry-getting-started
title: Getting started with Container Registry
description: IBM Cloud&reg; Container Registry provides a multi-tenant private image registry that you can use to store and share your container images with users in your IBM Cloud account.
last-updated: 2025-08-12
---

# Getting started with Container Registry
{: #getting-started}
{: toc-content-type="tutorial"}
{: toc-services="containers"}
{: toc-completion-time="45m"}

IBM Cloud&reg; Container Registry provides a multi-tenant private image [registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_registry) that you can use to store and share your [container images](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_container_image) with users in your IBM Cloud account.
{: shortdesc}

The IBM Cloud console includes a brief Quick Start. To find out more about how to use the IBM Cloud console, see [Managing image security with Vulnerability Advisor](https://cloud.ibm.com/docs/Registry?topic=Registry-va_index&interface=ui).

Do not put personal information in your container images, namespace names, description fields, or in any image configuration data (for example, image names or image labels).
{: important}

## Before you begin
{: #gs_registry_prereqs}

Install the IBM Cloud command-line interface (CLI) so that you can run the IBM Cloud `ibmcloud` commands, see [Getting started with the IBM Cloud CLI](https://cloud.ibm.com/docs/cli?topic=cli-getting-started).

The following instructions assume that you're in your own account with permission to do everything. If you find that you can't run the commands and you're a member of an account that is owned and administered by someone else, you might lack the correct permissions to configure and operate the Container Registry service. In which case, you must ask your administrator to give you the required IAM service access role permissions. For more information, see [Why can't I get started with Container Registry?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-get-started)
{: note}

## Install the Container Registry CLI
{: #gs_registry_cli_install}
{: step}

1. Install the `container-registry` CLI plug-in by running the following command:

    ```txt
    ibmcloud plugin install container-registry
    ```
    {: pre}

    For more information about installing plug-ins, see [Extending IBM Cloud CLI with plug-ins](https://cloud.ibm.com/docs/cli?topic=cli-plug-ins).

## Set up a namespace
{: #gs_registry_namespace_add}
{: step}
{: help}
{: support}

Create a [namespace](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_namespace). The namespace is created in the [resource group](https://cloud.ibm.com/docs/account?topic=account-rgs) that you specify so that you can configure access to resources within the namespace at the resource group level. If you don't specify a resource group, and you don't target a resource group, the default resource group is used. Namespaces that are assigned to a resource group show in the **Resource list** page of the IBM Cloud console.

1. Log in to IBM Cloud.

    ```txt
    ibmcloud login
    ```
    {: pre}

    If you have a federated ID, use `ibmcloud login --sso` to log in. Enter your username and use the provided URL in your CLI output to retrieve your one-time passcode. If you have a federated ID, the login fails without the `--sso` and succeeds with the `--sso` option.
    {: requirement}

    You don't need to log in to Container Registry until you want to push an image, see [Step 5: Push images to your namespace](https://cloud.ibm.com/docs/Registry?topic=Registry-getting-started#gs_registry_images_pushing).
    {: note}

2. Add a namespace to create your own image [repository](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_repository). Replace `MY_NAMESPACE` with your preferred namespace.

    The namespace must be unique across all IBM Cloud accounts in the same region. Namespaces must have 4 - 30 characters, and contain lowercase letters, numbers, hyphens (-), and underscores (_) only. Namespaces must start and end with a letter or number.
    {: requirement}

    ```txt
    ibmcloud cr namespace-add MY_NAMESPACE
    ```
    {: pre}

    You can put the namespace in a resource group of your choice by using one of the following options.

    - Before you create the namespace, run the [`ibmcloud target -g RESOURCE_GROUP`](https://cloud.ibm.com/docs/cli?topic=cli-ibmcloud_cli#ibmcloud_target) command, where `RESOURCE_GROUP` is the resource group.
    - Specify the resource group by using the `-g` option on the [`ibmcloud cr namespace-add`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_namespace_add) command.

    If you have a problem when you try to create a namespace, see [Why can't I add a namespace?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-add-namespace) for assistance.
    {: tip}

3. To help ensure that your namespace is created, run the `ibmcloud cr namespace-list` command.

    ```txt
    ibmcloud cr namespace-list -v
    ```
    {: pre}

## Pull images from a registry to your local computer
{: #gs_registry_images_pulling}
{: step}
{: help}
{: support}

1. Install Docker or a tool of your choice, such as Podman.
    - Install the [Docker Engine CLI](https://www.docker.com/products/container-runtime/#/download){: external}.

      [Windows]{: tag-windows} [macOS]{: tag-macos} For Windows&reg; 8, or macOS X Yosemite 10.10.x or earlier, install [Docker Desktop](https://docs.docker.com/desktop/){: external} instead.

      For more information about the version of Docker that is supported by IBM Cloud Container Registry, see [Support for Docker](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#docker).

    - Install [Podman](https://podman.io/){: external}.

2. Download (_pull_) the image to your local computer. Replace `SOURCE_IMAGE` with the repository of the image and `TAG` with the [tag](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_tag) of the image that you want to use, for example, `latest`. For example, depending on the tool that you are using, run one of the following commands.

    - If you are using Docker, run the following command.

      ```txt
      docker pull SOURCE_IMAGE:TAG
      ```
      {: pre}

      Example, where `SOURCE_IMAGE` is `hello-world` and `TAG` is `latest`:

      ```txt
      docker pull hello-world:latest
      ```
      {: pre}

      If you have a problem when you try to pull a Docker image, see [Why can't I push or pull a Docker image?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-push-pull-docker) for assistance. If you can't pull the most recent image by using the `latest` tag, see [Why can't I pull the newest image by using the `latest` tag?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-docker-latest) for assistance.
      {: tip}

    - If you are using Podman, run the following command.

      ```txt
      podman pull SOURCE_IMAGE:TAG
      ```
      {: pre}

      Example, where `SOURCE_IMAGE` is `hello-world` and `TAG` is `latest`:

      ```txt
      podman pull hello-world:latest
      ```
      {: pre}

## Tag the image
{: #gs_registry_images_tag}
{: step}
{: help}
{: support}

To tag the image, replace `SOURCE_IMAGE` with the repository and `TAG` with the tag of your local image that you pulled earlier. Replace `REGION` with the name of your [region](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#registry_regions). Replace `MY_NAMESPACE` with the namespace that you created in [Set up a namespace](#gs_registry_namespace_add). Define the repository and tag of the image that you want to use in your namespace by replacing `NEW_IMAGE_REPO` with the name of your image repository and `NEW_TAG` with the tag. For example, depending on the tool that you are using, run one of the following commands.

To find the name of your region, run the [`ibmcloud cr region`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_region) command.
{: tip}

- If you are using Docker, run the following command.

    ```txt
    docker tag SOURCE_IMAGE:TAG REGION.icr.io/MY_NAMESPACE/NEW_IMAGE_REPO:NEW_TAG
    ```
    {: pre}

    Example, where `SOURCE_IMAGE` is `hello-world`, `TAG` is `latest`, `REGION` is `uk`, `MY_NAMESPACE` is `namespace1`, `NEW_IMAGE_REPO` is `hw_repo`, and `NEW_TAG` is `1`:

    ```txt
    docker tag hello-world:latest uk.icr.io/namespace1/hw_repo:1
    ```
    {: pre}

- If you are using Podman, run the following command.

    ```txt
    podman tag SOURCE_IMAGE:TAG REGION.icr.io/MY_NAMESPACE/NEW_IMAGE_REPO:NEW_TAG
    ```
    {: pre}

    Example, where `SOURCE_IMAGE` is `hello-world`, `TAG` is `latest`, `REGION` is `uk`, `MY_NAMESPACE` is `namespace1`, `NEW_IMAGE_REPO` is `hw_repo`, and `NEW_TAG` is `1`:

    ```txt
    podman tag hello-world:latest uk.icr.io/namespace1/hw_repo:1
    ```
    {: pre}

## Push images to your namespace
{: #gs_registry_images_pushing}
{: step}
{: help}
{: support}

1. Log in to IBM Cloud Container Registry by using one of the following options.

    - To log in by using Docker, run the `ibmcloud cr login` command to log your local Docker daemon in to IBM Cloud Container Registry.

      ```txt
      ibmcloud cr login --client docker
      ```
      {: pre}

    - To log in by using Podman, run the `ibmcloud cr login` command to log in to IBM Cloud Container Registry.

      ```txt
      ibmcloud cr login --client podman
      ```
      {: pre}

    - To log in by using other clients, see [Accessing your namespaces interactively](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_access#registry_access_interactive).

    If you have a problem when you try to log in, see [Why can't I log in to Container Registry?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-login) for assistance.
    {: tip}

2. Upload (_push_) the image to your namespace. Replace `MY_NAMESPACE` with the namespace that you created in [Set up a namespace](#gs_registry_namespace_add). Replace `IMAGE_REPO` and `TAG` with the repository and the tag of the image that you chose when you tagged the image. For example, depending on the tool that you are using, run one of the following commands.

    - If you are using Docker, run the following command.

      ```txt
      docker push REGION.icr.io/MY_NAMESPACE/IMAGE_REPO:TAG
      ```
      {: pre}

      Example, where `REGION` is `uk`, `MY_NAMESPACE` is `namespace1`, `IMAGE_REPO` is `hw_repo`, and `TAG` is `1`:

      ```txt
      docker push uk.icr.io/namespace1/hw_repo:1
      ```
      {: pre}

      If you have a problem when you try to push a Docker image, see [Why can't I push or pull a Docker image?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-push-pull-docker) for assistance.
      {: tip}

    - If you are using Podman, run the following command.

      ```txt
      podman push REGION.icr.io/MY_NAMESPACE/IMAGE_REPO:TAG
      ```
      {: pre}

      Example, where `REGION` is `uk`, `MY_NAMESPACE` is `namespace1`, `IMAGE_REPO` is `hw_repo`, and `TAG` is `1`:

      ```txt
      podman push uk.icr.io/namespace1/hw_repo:1
      ```
      {: pre}

## Verify that the image was pushed
{: #gs_registry_images_verify}
{: step}
{: help}
{: support}

Verify that the image was pushed successfully by running the following command.

```txt
ibmcloud cr image-list
```
{: pre}

You set up a namespace in IBM Cloud Container Registry and pushed your first image to your namespace.

## Set up an audit trail for changes in Container Registry
{: #gs_registry_audit}
{: step}
{: help}
{: support}

Create an audit trail for changes in Container Registry by capturing activity events from each of your active Container Registry regions. Create these activity events in one, or more, instance of IBM Cloud Logs.

To set up an audit trail, complete the following steps:

1. Set up IBM Cloud Logs, see [Getting started with IBM Cloud Logs](https://cloud.ibm.com/docs/cloud-logs?topic=cloud-logs-getting-started).
2. Set up IBM Cloud Activity Tracker Event Routing, see [Getting started with IBM Cloud Activity Tracker Event Routing](https://cloud.ibm.com/docs/atracker?topic=atracker-getting-started).
3. Configure an IBM Cloud Logs target, see [Configuring an IBM Cloud Logs instance as a target](https://cloud.ibm.com/docs/atracker?topic=atracker-getting-started-target-cloud-logs).

For more information about logging, see [About IBM Cloud Logs](https://cloud.ibm.com/docs/cloud-logs?topic=cloud-logs-about-cl) and [Logging for Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_logs).

For more information about activity events, see [About IBM Cloud Activity Tracker Event Routing](https://cloud.ibm.com/docs/atracker?topic=atracker-about) and [Activity tracking events for Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-at_events).

## Monitor metrics for Container Registry
{: #gs_registry_monitor}
{: step}
{: help}
{: support}

You can create a Monitoring instance in the region that you want to monitor and enable platform metrics for it. Alternatively, you can enable platform metrics on an existing Monitoring instance in that region.

For more information about setting up metrics, see [Enabling metrics for Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_monitor#registry_enable_platform_metrics) and [Getting started with Monitoring](https://cloud.ibm.com/docs/monitoring?topic=monitoring-getting-started).

## Next steps in Container Registry
{: #gs_get_start_next}

- [Manage image security with Vulnerability Advisor.](https://cloud.ibm.com/docs/Registry?topic=Registry-va_index&interface=ui)
- [Review your service plans.](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#registry_plans)
- [Store and manage more images in your namespace.](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_images_)
- [Define access policies.](https://cloud.ibm.com/docs/Registry?topic=Registry-user#user)
- [Set up clusters and worker nodes.](https://cloud.ibm.com/docs/containers?topic=containers-clusters#clusters)

================================

---
name: Registry-registry_overview
title: About Container Registry
description: Use IBM Cloud&reg; Container Registry to store and access private container images in a highly available and scalable architecture.
last-updated: 2026-05-27
---

# About Container Registry
{: #registry_overview}

Use IBM Cloud&reg; Container Registry to store and access private container images in a highly available and scalable architecture.
{: shortdesc}

IBM Cloud Container Registry provides a multi-tenant, highly available, scalable, and encrypted private image registry that is hosted and managed by IBM. You can use Container Registry by setting up your own image [namespace](#x2031005){: term} and pushing container images to your namespace.

![Diagram showing how IBM Cloud Container Registry interacts with images.](images/about_container_registry_v2.svg "Diagram showing how Container Registry interacts with images. Container Registry contains both private and public namespaces and APIs to interact with the service. Your local image store interacts with both Container Registry and other registries, which in turn interact with your Kubernetes cluster. The IBM Cloud graphical user interface (GUI), which is called the IBM Cloud console, interacts with the Container Registry API to list images. The Container Registry CLI interacts with the API to list, inspect, and remove images, create namespaces, and perform other administrative functions."){: caption="How Container Registry interacts with images" caption-side="bottom"}{: external download="../images/about_container_registry_v2.svg"}

A Docker image is the basis for every container that you create. An image is created from a [Dockerfile](#x9860414){: term}, which is a file that contains instructions about how to build the image. A Dockerfile might reference build artifacts in its instructions that are stored separately, such as an app, the configuration of the app, and its dependencies. Images are typically stored in a registry that can either be accessible by the public (public registry) or set up with limited access for a group of users (private registry). By using Container Registry, only users with access to your IBM Cloud account can access your images.

When you push images to Container Registry, you benefit from the built-in Vulnerability Advisor features that scan for potential security issues and vulnerabilities. Vulnerability Advisor checks for vulnerable packages in specific Docker base images, and known vulnerabilities in app configuration settings. When vulnerabilities are found, information about the vulnerability is provided. You can use this information to resolve security issues so that containers are not deployed from vulnerable images.

Review the following table to find an overview of the benefits of using Container Registry.

| Benefit                                               | Description                                                                                                                                                                                                                                |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Highly available and scalable private registry.       | Set up your own image namespace in a multi-tenant, highly available, scalable, encrypted private registry that is hosted and managed by IBM.  \n  \n Store your private Docker images and share them with users in your IBM Cloud account. |
| Image security compliance with Vulnerability Advisor. | Benefit from automatic scanning of images in your namespace.  \n  \n Review recommendations that are specific to the operating system to fix potential vulnerabilities and protect your containers from being compromised.                 |
| Quota limits for storage and pull traffic.            | Benefit from free storage and pull traffic to your private images until you reach your free quota.  \n  \n Set custom quota limits for the amount of storage and pull traffic per month to avoid exceeding your preferred payment level.   |
{: caption="Container Registry benefits" caption-side="bottom"}
{: #table_registry_overview_benefits}

## Service plans
{: #registry_plans}

You can choose between the free or standard Container Registry service plans to store your Docker images and make these images available to users in your IBM Cloud account.

The IBM Cloud Container Registry service plan determines the amount of storage and pull traffic that you can use for your private images. The service plan is associated with your IBM Cloud account, and limits for storage and image pull traffic apply to all namespaces that you set up in your account.

Service plans are scoped to the specific registry instance (one of the regional registries or the global registry) that you're currently working with. Plan settings must all be managed separately for your account in each registry instance. For more information, see [Regions](#registry_regions).
{: important}

The following table shows available IBM Cloud Container Registry service plans and their characteristics. For more information about how billing works and what happens when you exceed service plan limits, see [Quota limits and billing](#registry_plan_billing).

| Characteristics               | Free                                                                                                                                                                                        | Standard                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Description.                  | Try out Container Registry to store and share your Docker images. This plan is the default service plan when you set up your first namespace in Container Registry.                         | Benefit from unlimited storage and pull traffic usage to manage the Docker images for all namespaces in your IBM Cloud account.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Amount of storage for images. | 500 MB                                                                                                                                                                                      | Unlimited                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Pull traffic.                 | 5 GB per month                                                                                                                                                                              | Unlimited                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| Billing.                      | If you exceed your storage or pull traffic limits, you cannot push or pull images to and from your namespace. For more information, see [Quota limits and billing](#registry_plan_billing). | **Storage**. You are charged by Gigabyte-Months of usage. The first 0.5 GB-Months are free. Then, you are charged as stated in the offering details page. For more information, see [Container Registry](https://cloud.ibm.com/containers/registry/catalog).  \n  \n **Pull traffic**. You are charged by Gigabyte usage per month. The first 5 GB are free. Then, you are charged as stated in the offering details page. For more information, see [Container Registry](https://cloud.ibm.com/containers/registry/catalog). If you exceed your storage or pull traffic limits, you can't push or pull images to and from your namespace. For more information about storage, pull traffic, and the cost estimator, see [Quota limits and billing](#registry_plan_billing). |
{: caption="Container Registry plans" caption-side="bottom"}
{: #table_registry_overview_plans}

## Quota limits and billing
{: #registry_plan_billing}

Find information and examples for how the billing process and quota limits work in Container Registry.

Every image is built from a number of layers that each represent an incremental change from the base image. When you push or pull an image, the amount of storage and pull traffic that is needed for each layer is added to your monthly usage. Identical layers are automatically shared between images in your IBM Cloud account and are reused when you create other images. The storage for each identical layer is charged only once, regardless of how many images in your account reference the layer. Layers that are only referenced by deleted images in the trash are not charged.

From 1 February 2022, both [tagged](#overview_elements_tag) and [untagged](#overview_elements_untagged) images are charged for.
{: important}

Quota limits and billing are scoped to the specific registry instance (one of the regional registries or the global registry) that you're currently working with. Quota settings must be managed separately for your account in each registry instance. For more information, see [Regions](#registry_regions).
{: important}

Pull traffic across public connections counts toward usage and quota. Pull traffic across private connections doesn't count.
{: important}

The following example is for pushing images:
:   You push an image to your namespace that is based on the Ubuntu image. The Ubuntu image contains several layers. Because you do not have these layers in your account yet, the amount of storage that these layers require is added to your monthly usage.

    Later, you create a second image that is based on the Ubuntu image. You change the Ubuntu base image, such as by adding more commands or files to your Dockerfile. Each change represents a new image layer. When you push the second image, Container Registry recognizes that all layers of the base Ubuntu image are already stored in your account. You're not charged for storing these layers a second time, even if you pushed your image to another namespace. Container Registry determines the proportions of all new layers and adds the amount of storage to your monthly usage.

### Billing for storage and pull traffic
{: #registry_billing_traffic}

Depending on the service plan that you choose, you are charged for the storage and pull traffic that you use per month in each region.

#### Storage charges
{: #registry_billing_traffic_storage}

Every IBM Cloud Container Registry service plan comes with a certain amount of storage that you can use to store your Docker images in the namespaces of your IBM Cloud account. If you're on the standard plan, you are charged by GB-Months of usage. The first 0.5 GB-Months each month are free. If you're on the free plan, you can store your images in Container Registry for free until you reach the quota limits for the free plan. A GB-Month is an average of 1 GB of storage for a month (730 hours).

The following example is for the standard plan:
:   You use 5 GB for exactly half the month and then you push several images to your namespace and use 10 GB for the rest of the month. Your monthly usage is calculated as shown in the following example:

    (5 GB x 0.5 (months)) + (10 GB x 0.5 (months)) = 2.5 + 5 = 7.5 GB-Months.

    In the standard plan, the first 0.5 GB-Months each month are free, so you get charged for 7 GB-Months (7.5 GB-Months - 0.5 GB-Months).

#### Pull traffic charges
{: #registry_billing_traffic_pull_traffic}

Every IBM Cloud Container Registry service plan includes a certain amount of free pull traffic to your private images that are stored in your namespace. Pull traffic is the bandwidth that you use when you pull a layer of an image from your namespace to your local computer. If you're on the standard plan, you're charged by GB of usage per month. The first 5 GB each month is free. If you're on the free plan, you can pull images from your namespace until you reach the quota limit for the free plan.

Pull traffic across public connections counts toward usage and quota. Pull traffic across private connections doesn't count.
{: important}

The following example is for the standard plan:
:   In the month, you pulled images that contain layers that total 14 GB. Your monthly usage is calculated as shown in the following example:

    In the standard plan, the first 5 GB per month is free, so you get charged for 9 GB (14 GB - 5 GB).

### Quota limits for storage and pull traffic
{: #registry_quota_limits}

Depending on the service plan that you choose, you can push and pull images to and from your namespace until you reach your plan-specific or custom quota limits for each region.

#### Storage quota limits
{: #registry_quota_limits_storage}

When you reach or exceed the quota limits for your plan, you can't push any images to the namespaces in your IBM Cloud account until you complete one of the following tasks.

- [Free up space by removing images](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_quota#registry_quota_freeup) from your namespaces.
- [Upgrade to the standard plan](#registry_plan_upgrade).
- If you set quota limits for storage in your free or standard plan, you can also [increase this quota limit](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_quota#registry_quota_set) to enable the pushing of new images again.

The following example is for the standard plan:
:   Your current quota limit for storage is set to 1 GB. All private images that are stored in the namespaces of your IBM Cloud account already use 900 MB of this storage. You have 100 MB storage available until you reach your quota limit. One user wants to push an image that is 2 GB on the local computer. Because the quota limit is not yet reached, Container Registry allows the user to push this image.

    After the push, Container Registry determines the actual proportions of the image in your namespace, which can vary from the proportions on your local computer, and checks whether the limit for storage is reached. In this example, the storage usage increases from 900 MB by 2 GB. With your current quota limit set to 1 GB, Container Registry prevents you from pushing more images to the namespace.

#### Pull traffic quota limits
{: #registry_quota_limits_pull_traffic}

When you reach or exceed the quota limits for your plan, you can't pull any images from the namespaces in your IBM Cloud account until you complete one of the following tasks.

- Wait for the next billing period to start.
- [Upgrade to the standard plan](#registry_plan_upgrade).
- [Increase your quota limits for pull traffic](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_quota#registry_quota_set).

Pull traffic across public connections counts toward usage and quota. Pull traffic across private connections doesn't count.
{: important}

The following example is for the standard plan:
:   In the month, your quota limit for pull traffic is set to 5 GB. You already pulled images from your namespaces and used 4.5 GB of this pull traffic. You have 0.5 GB pull traffic available until you reach your quota limit. One user wants to pull a 1 GB image from your namespace. Because the quota limit is not yet reached, Container Registry allows the user to pull this image.

    After the image is pulled, Container Registry determines the bandwidth that you used during the pull and checks whether the limit for pull traffic is reached. In this example, the pull traffic usage increased from 4.5 GB to 5.5 GB. With your current quota limit set to 5 GB, Container Registry prevents you from pulling images from your namespace.

### Cost of Container Registry
{: #registry_cost}

You can see the costs of IBM Cloud Container Registry in the pricing plans section of the offering details page. For more information, see [Container Registry](https://cloud.ibm.com/containers/registry/catalog).

## Upgrading your service plan
{: #registry_plan_upgrade}
{: help}
{: support}

You can upgrade your service plan to benefit from unlimited storage and pull traffic usage to manage the Docker images for all namespaces in your IBM Cloud account.

If you want to find out what service plan you have for the registry region that you're targeting, run the `ibmcloud cr plan` command.
{: tip}

To upgrade your service plan, complete the following steps.

1. Log in to IBM Cloud.

    ```txt
    ibmcloud login
    ```
    {: pre}

    If you have a federated ID, use `ibmcloud login --sso` to log in to the IBM Cloud CLI. Enter your username and use the provided URL in your CLI output to retrieve your one-time passcode. If you have a federated ID, the login fails without the `--sso` and succeeds with the `--sso` option.
    {: requirement}

2. Target the region for which you want to upgrade the plan.

    ```txt
    ibmcloud cr region-set
    ```
    {: pre}

    For more information, see [`ibmcloud cr region-set`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_region_set) and [Regions](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#registry_regions).

3. Upgrade to the standard plan.

    ```txt
    ibmcloud cr plan-upgrade standard
    ```
    {: pre}

    If you have an IBM Cloud Lite plan, you must upgrade to an IBM Cloud Pay-as-you-go or Subscription account before you run `ibmcloud cr plan-upgrade`.
    {: requirement}

    For more information, see [`ibmcloud cr plan-upgrade`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_plan_upgrade).

## Terms that are used in IBM Cloud Container Registry
{: #overview_elements}

Information about the terms that are used in IBM Cloud Container Registry.

For more information about Docker-specific terms, see the [Docker glossary](https://docs.docker.com/reference/glossary/){: external}.

### Container image
{: #overview_elements_container_image}

A file system and its execution parameters that are used within a container runtime to create a container. The file system consists of a series of layers, which are combined at run time, that are created as the container image is built by successive updates. The container image does not retain its state as the container runs.

Container images are stored in a repository that is stored in a namespace.

### Digest
{: #overview_elements_digest}

Digests are used as immutable references to various objects in the registry such as image manifests, layers, and configuration items.

In the context of the registry, an image digest is an immutable reference to an image that identifies an image by using the `sha256` hash of the [image manifest](#overview_elements_manifest). You can use an image digest to ensure that you always reference the same version of an image. Use the long format of the image digest to work with images, such as pulling, pushing, and deleting images.

To find the image digest, run the [`ibmcloud cr image-digests`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_digests) command. The [`ibmcloud cr image-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_list) command also returns the image digest, but, by default, it is in a truncated format. You can add an option to the `ibmcloud cr image-list` command to return the image digest in the long format.

When you're using the image digest to identify an image, always use the long format.
{: requirement}

In Container Registry, any reference to "digest" means "image digest".
{: note}

### Dockerfile
{: #overview_elements_dockerfile}

A Dockerfile is a text file that contains instructions to build a Docker image.

Typically, a container image is built upon a base image that contains a base operating system, such as Ubuntu. You can incrementally change the base image with your Dockerfile instructions to define the environment that the app needs to run. Every change to the base image describes a new layer of the image, and you can make multiple changes in a single Dockerfile line. The instructions in a Dockerfile might also reference build artifacts that are stored separately, such as an app, the configuration of the app, and its dependencies. For more information about Dockerfile, see [Dockerfile reference](https://docs.docker.com/reference/dockerfile/){: external}.

### Docker V2 container images
{: #overview_elements_dockerv2_images}

A container image that is compliant with the [Image Manifest Version 2, schema 2](https://distribution.github.io/distribution/spec/manifest-v2-2/){: external} specification.

The media type for Docker Image Manifest V2, schema 2 is `application/vnd.docker.distribution.manifest.v2+json` and the media type for the manifest list is `application/vnd.docker.distribution.manifest.list.v2+json`. A Docker V2 container image is a type of OCI container image. For more information about support for Docker, see [Docker](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#docker).

### Domain name
{: #overview_elements_domain_name}

The name of a host system. A domain name consists of a sequence of subnames that are separated by a delimiter character, for example, `www.ibm.com`.

The domain names that Container Registry uses are in the format `us.icr.io`. Earlier domain names that Container Registry used are in the format `registry.ng.bluemix.net`. Both formats of domain name refer to the same registry and content. The Container Registry service responds to earlier and canonical domain names equally. You can push or pull images by using either domain name interchangeably.

The domain name is only significant in the following situations:

- When Kubernetes is selecting a pull-secret, it chooses one that matches the domain name.
- When [`ibmcloud cr login`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_login) is helping you to log in, it uses domain names in the format `us.icr.io` only.
- When images are signed, the signature includes the domain name that was used at the time of signing.

For more information about the domain names that Container Registry uses, see [Regions](#registry_regions).

### Image manifest
{: #overview_elements_manifest}

An image manifest is a `.json` document that references the configuration object and image layers that are required to pull and run the image. The `sha256` hash of the image manifest is the [digest](#overview_elements_digest), which is used to identify the image. You can view the image manifest by running the [`ibmcloud cr manifest-inspect`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_manifest_inspect) command.

### OCI container images
{: #overview_elements_oci_images}

A container image that is compliant with the [OCI Image Format](https://github.com/opencontainers/image-spec){: external} specification.

The media type for OCI container images is `application/vnd.oci.image.manifest.v1+json`.

### Registry
{: #overview_elements_registry}

A public or private container image storage and distribution service.

Storage is provided for [OCI container images](#x9860419){: term} (also known as Docker container images). OCI container images can be accessed or "pulled" by OCI clients that use the appropriate registry domain name. Container images can be accessed by anyone (public images) or access can be limited to a group (private images). Container Registry provides a multi-tenant, highly available, private image registry that is hosted and managed by IBM. You can use the registry by adding a namespace that is private to your account and then push images to your namespace.

### Registry namespace
{: #overview_elements_namespace}

A folder that contains folders or repositories that store your container images in Container Registry. The registry namespace is associated with your IBM Cloud account. You can have multiple registry namespaces in an account.

When you set up your own namespace in Container Registry, the namespace is appended to the registry URL `<region>.icr.io/<my_namespace>`, where `<region>` is the region and `<my_namespace>` is your namespace. The namespace must be unique across all IBM Cloud accounts in the same region. Every user in your IBM Cloud account who has the correct IAM permissions, can view and work with images that are stored in your registry namespace.

You can have 100 namespaces in each region.
{: note}

Namespaces are created in a [resource group](https://cloud.ibm.com/docs/account?topic=account-rgs) that you specify so that you can configure access to resources within the namespace at the resource group level. If you don't specify a resource group, and a resource group isn't targeted, the default resource group is used. If you have an older namespace that is not in a resource group, you can assign it to a resource group and then set permissions for that namespace at the resource group level. For more information about resource groups, see [Assigning existing namespaces to resource groups](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#registry_namespace_assign).

Namespaces that are assigned to a resource group show in the **Resource list** page of the IBM Cloud console.

### Repository
{: #overview_elements_repository}

Stores a collection of related container images. A repository is stored in a namespace. The container images are distinguished by tag or digest only. The term repository is often used interchangeably with container image, but a repository potentially holds multiple tagged variants of a container image.

### Tag
{: #overview_elements_tag}

An identifier that is attached to container images within a repository. Tags can be reassigned or deleted from images.

You can use [tags](#x2040924){: term} to distinguish different versions of the same base image within a repository. When you run a Docker command and do not specify the tag of a repository image, then the image tagged `latest` is used by default.

### Untagged image
{: #overview_elements_untagged}

An image that has no tag is an untagged image. Images that are untagged can be referenced by using the digest reference format `<repository>@<digest>` as opposed to the tag reference format `<repository>:<tag>`. Untagged images are typically the result of an image that is pushed with a pre-existing `<repository>:<tag>` combination. In this case, the tag is overwritten and the original image becomes untagged.

You can view all your tagged and untagged images by running the [`ibmcloud cr image-digests`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_digests) command. If you want to view just your untagged images, you can run the `ibmcloud cr image-digests` command with Go language formatting, see [Example Go format command for `ibmcloud cr image-digests`](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_cli_list&interface=ui#registry_cli_list_imagedigests_go). If you want to remove your untagged images, you can run the [`ibmcloud cr image-prune-untagged`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#ic_cr_image_prune_untagged) command.
{: tip}

## Regions
{: #registry_regions}

The default instance of Container Registry is the global registry. The global registry doesn't include a region in its [domain name](#overview_elements_domain_name) (`icr.io`).

Use the global instance of the registry unless you have a specific requirement, for example, data sovereignty, to store your data in a particular region. In which case, you can use Container Registry in [local regions](#registry_regions_local).

Each region is backed up in a different region. For example, the images that are stored in the IBM Cloud Container Registry registry `Frankfurt(eu-de)` are replicated over the six data centers across `Frankfurt(eu-de)` and `London(eu-gb)` regions.

The following table shows you the backup locations. For more information about Container Registry backup locations, see [Does the service replicate the data?](https://cloud.ibm.com/docs/Registry?topic=Registry-bc-dr#bc-dr_replicate_data) for assistance.

{{registry_bc_dr.md#table_registry_bc_dr_backup_locations}}

All registry artifacts are scoped to the specific registry instance (one of the regional registries or the global registry) that you're currently working with. For example, namespaces, images, quota settings, and plan settings must all be managed separately for your account in each registry instance.

### Global registry
{: #registry_regions_global}

A global registry is available. The global registry doesn't include a region in its name (`icr.io`). In addition to hosting user namespaces and images, this registry also hosts public images that are provided by IBM.

The global instance of Container Registry is available by using the [domain names](#overview_elements_domain_name) that are shown in the following table.

| Registry | Domain name | Private domain name | Deprecated domain name |
| -------- | ----------- | ------------------- | ---------------------- |
| Global   | `icr.io`    | `private.icr.io`    | `registry.bluemix.net` |
{: caption="Domain name for the global registry" caption-side="bottom"}
{: #table_registry_overview_domain_name_global}

To learn about connecting to Container Registry by using the private domain names, see [Using private network connections](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_private#registry_private_images).

The existing `bluemix.net` domain names are deprecated, but you can continue to use them for the moment. An end of support date is not available yet.
{: deprecated}

#### Targeting the global registry
{: #registry_regions_global_target}

You can target the global registry by running the [`ibmcloud cr region-set`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_region_set) command.

1. To target the global registry (`icr.io`), run the following command.

    ```txt
    ibmcloud cr region-set global
    ```
    {: pre}

2. To log your local Docker daemon into the global registry, run the [`ibmcloud cr login`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_login) command.

    Container Registry supports other clients as well as Docker. To log in by using other clients, see [Accessing your namespaces interactively](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_access#registry_access_interactive).
    {: tip}

### Local regions
{: #registry_regions_local}

Regional instances of Container Registry are available by using the [domain names](#overview_elements_domain_name) that are shown in the following table.

| Local registry region | Former name of registry region | Location         | Domain name  | Private domain name  | Deprecated domain name        |
| --------------------- | ------------------------------ | ---------------- | ------------ | -------------------- | ----------------------------- |
| `au-syd`              | `ap-south`                     | Sydney           | `au.icr.io`  | `private.au.icr.io`  | `registry.au-syd.bluemix.net` |
| `br-sao`              | Not applicable                 | Sao Paolo        | `br.icr.io`  | `private.br.icr.io`  | Not applicable                |
| `ca-mon`              | Not applicable                 | Montreal         | `ca2.icr.io` | `private.ca2.icr.io` | Not applicable                |
| `ca-tor`              | Not applicable                 | Toronto          | `ca.icr.io`  | `private.ca.icr.io`  | Not applicable                |
| `eu-de`               | `eu-central`                   | Frankfurt        | `de.icr.io`  | `private.de.icr.io`  | `registry.eu-de.bluemix.net`  |
| `eu-es`               | Not applicable                 | Madrid           | `es.icr.io`  | `private.es.icr.io`  | Not applicable                |
| `eu-gb`               | `uk-south`                     | London           | `uk.icr.io`  | `private.uk.icr.io`  | `registry.eu-gb.bluemix.net`  |
| `in-che`              | Not applicable                 | Chennai - Airtel | `in.icr.io`  | `private.in.icr.io`  | Not applicable                |
| `in-mum`              | Not applicable                 | Mumbai - Airtel  | `in2.icr.io` | `private.in2.icr.io` | Not applicable                |
| `jp-osa`              | Not applicable                 | Osaka            | `jp2.icr.io` | `private.jp2.icr.io` | Not applicable                |
| `jp-tok`              | `ap-north`                     | Tokyo            | `jp.icr.io`  | `private.jp.icr.io`  | Not applicable                |
| `us-south`            | Not applicable                 | Dallas           | `us.icr.io`  | `private.us.icr.io`  | `registry.ng.bluemix.net`     |
{: caption="Domain names for local regions" caption-side="bottom"}
{: #table_registry_overview_domain_name_local}

To learn about connecting to Container Registry by using the private domain names, see [Using private network connections](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_private#registry_private_images).

The existing `bluemix.net` domain names are deprecated, but you can continue to use them for the moment. An end of support date is not available yet.
{: deprecated}

#### Targeting a local region
{: #registry_regions_local_target}
{: help}
{: support}

If you want to use a region other than your local region, you can target the region that you want to access by running the [`ibmcloud cr region-set`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_region_set) command. You can run the command with no options to get a list of available regions, or you can specify the region as an option.

1. To run the command with options, replace `REGION` with the name of the [region](#registry_regions_local).

    ```txt
    ibmcloud cr region-set REGION
    ```
    {: pre}

    For example, to target the `eu-de` region, run the following command.

    ```txt
    ibmcloud cr region-set eu-de
    ```
    {: pre}

2. To log your local Docker daemon into the registry so that you can push or pull images, run the [`ibmcloud cr login`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_login) command.

    Container Registry supports other clients as well as Docker. To log in by using other clients, see [Accessing your namespaces interactively](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_access#registry_access_interactive).
    {: tip}

## Supported clients
{: #support_clients}

### Support for Docker
{: #docker}

IBM Cloud Container Registry supports versions of Docker Engine that Docker supports.

Docker is required only if you want to push or pull images.

Docker V2 schema 2 images are supported. Manifest lists are also supported. For more information, see [Registry compatibility](https://distribution.github.io/distribution/about/compatibility/){: external}.

Docker V2 schema 1 images are discontinued and you can't push them to Container Registry anymore.
{: note}

### Support for other clients
{: #clients}

IBM Cloud Container Registry supports the supported versions of clients that are compliant with the OCI Distribution spec version 1, or later, such as Buildah, Podman, and Skopeo.

================================

---
name: Registry-registry_architecture
title: Container Registry architecture and workload
description: IBM Cloud&reg; Container Registry is a multi-tenant, highly available, scalable, and encrypted private image registry that is hosted and managed by IBM.
last-updated: 2025-10-10
---

# Container Registry architecture and workload
{: #registry_architecture}

IBM Cloud&reg; Container Registry is a multi-tenant, highly available, scalable, and encrypted private image [registry](#x2064940){: term} that is hosted and managed by IBM.
{: shortdesc}

Both the control plane (management of images and configuration) and data plane (pushing and pulling your images) are multi-tenant. All parts of the service are hosted in an IBM service account, which is not shared with users or other services.

In each regional instance of the [registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_registry), the service runs in three physically separate data centers to ensure availability. All data and the configuration for each instance of the registry is retained within the region in which it is hosted. The global instance is also hosted in physically separate data centers. The data centers might not be in the same region as each other. For more information about regions, see [Regions](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#registry_regions).

IBM Cloud Container Registry runs in IBM Cloud Kubernetes Service clusters, and uses IBM Cloud Object Storage to store images. Image data in IBM Cloud Object Storage is encrypted at rest.

![Diagram showing deployment.](images/container_registry_architecture_mul.svg "Diagram that shows deployment in your account, MZRs, public ingress, private ingress, customer data flows, and dependencies (public and private)."){: caption="Diagram showing deployment" caption-side="bottom"}{: external download="../images/container_registry_architecture_mul.svg"}

## Segmentation of data
{: #registry_architecture_segment}

Segmentation of data within IBM Cloud Container Registry is achieved by using private [namespaces](#x2031005){: term}, which are strictly owned by single accounts.

You can control access to [namespaces](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_namespace) within the account by using Cloud Identity and Access Management (IAM) access policies. Storage in IBM Cloud Object Storage is not segmented, but user accounts do not have direct access to the IBM Cloud Object Storage that contains the image data. For more information, see [Managing IAM access for IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-iam).

All traffic to the registry, and from the service to IBM Cloud Container Registry dependencies is encrypted in transit. No additional network-level segmentation of traffic is provided. The control plane and data plane are not separated from each other.

## Private connections
{: #registry_architecture_private_connections}

You can decide whether your data plane interactions use private connections. Additionally, you can choose to prohibit public data plane connections for your account.

The flow of all customer data between IBM Cloud Container Registry and its dependencies uses private network connections. For more information about private connections, see [Securing your connection to IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_private).

================================

---
name: Registry-registry_public_images
title: Public IBM images available in Container Registry
description: You can access the images that are provided by IBM by using the IBM Cloud&reg; Container Registry command-line interface.
last-updated: 2025-08-12
---

# Public IBM images available in Container Registry
{: #public_images}

You can access the images that are provided by IBM by using the IBM Cloud&reg; Container Registry command-line interface.
{: shortdesc}

 You can't access the public IBM images by using the IBM Cloud console anymore.
 {: note}

## Accessing the public IBM images by using the CLI
{: #public_images_cli}

You can access the public IBM images by using the command-line interface (CLI).

Before you begin, complete the following tasks.

1. Ensure that the IBM Cloud Container Registry CLI is installed, see [Installing the `container-registry` CLI plug-in](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#cli_namespace_registry_cli_install).

2. Log in to [IBM Cloud](https://cloud.ibm.com/docs/cli?topic=cli-ibmcloud_cli#ibmcloud_login).

    ```txt
    ibmcloud login
    ```
    {: pre}

To list the public images, complete the following steps.

1. Target the global registry:

    ```txt
    ibmcloud cr region-set global
    ```
    {: pre}

2. List the IBM public images.

    ```txt
    ibmcloud cr images --include-ibm
    ```
    {: pre}

================================
