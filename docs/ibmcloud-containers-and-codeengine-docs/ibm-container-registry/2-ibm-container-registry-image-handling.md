================================

---
name: Registry-registry_images_
title: Adding images to your namespace in Container Registry
description: You can securely store and share Docker images with other users by adding images to your namespace in IBM Cloud&reg; Container Registry.
last-updated: 2026-05-21
---

# Adding images to your namespace in Container Registry
{: #registry_images_}

You can securely store and share Docker images with other users by adding images to your [namespace](#x2031005){: term} in IBM Cloud&reg; Container Registry.
{: shortdesc}

Every image that you want to add to your namespace must exist on your local computer first. You can either download (pull) an image from another repository to your local computer, or build your own image from a [Dockerfile](#x9860414){: term} by using the Docker `build` command. To add an image to your namespace, you must upload (push) the local image to your namespace in IBM Cloud Container Registry.

Do not put personal information in your container images, namespace names, description fields, or in any image configuration data (for example, image names or image labels).
{: important}

## Pulling images from another registry
{: #registry_images_pulling_reg}
{: help}
{: support}

You can pull (download) an image from any private or public [registry](#x2064940){: term} source to your computer, and then tag it for later use in IBM Cloud Container Registry.

![Pull an image from a private or public registry to your computer.](images/pulling_images_mul.svg "You can pull an image from IBM Cloud Container Registry or from any private or public registry source to your local computer."){: caption="Pulling images from another registry" caption-side="bottom"}{: external download="../images/pulling_images_mul.svg"}

Before you begin, complete the following tasks.

- [Install the Container Registry command-line interface (CLI)](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#cli_namespace_registry_cli_install) to work with images in your namespace.
- [Set up your own namespace in IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#registry_namespace_setup).
- [Make sure that you can run Docker commands without root permissions](https://docs.docker.com/engine/install/linux-postinstall/){: external}. If your Docker client is set up to require root permissions, you must run `ibmcloud login`, `ibmcloud cr login`, `docker pull`, and `docker push` commands with `sudo`.

    If you change your permissions to run Docker commands without root privileges, you must run the `ibmcloud login` command again.

1. Download the image, see [Pull an image](https://cloud.ibm.com/docs/Registry?topic=Registry-getting-started#gs_registry_images_pulling) in the Getting Started documentation.

    If you get an `unauthorized: authentication required` or a `denied: requested access to the resource is denied` message, run the [`ibmcloud cr login`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_login) command.
    {: tip}

After you pull an image and [tag](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_tag) it for your [namespace](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_namespace), you can upload (push) the image from your local computer to your namespace.

If you deploy a workload that pulls an image from Container Registry and your pods fail with an ImagePullBackOff status, see [Why do images fail to pull from registry with ImagePullBackOff or authorization errors?](https://cloud.ibm.com/docs/Registry?topic=Registry-ts-app-image-pull) for assistance.
{: tip}

## Pushing Docker images to your namespace
{: #registry_images_pushing_namespace}
{: help}
{: support}

You can push (upload) an image from your computer to your namespace in IBM Cloud Container Registry to store your image and share it with other users.

![Push an image from your computer to IBM Cloud Container Registry.](images/pushing_images_mul.svg "Push (upload) an image from your local computer to your namespace in IBM Cloud Container Registry to store and share your image with other users."){: caption="Push Docker images to your namespace" caption-side="bottom"}{: external download="../images/pushing_images_mul.svg"}

Before you begin, complete the following tasks.

- [Install the CLI](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#cli_namespace_registry_cli_install) to work with images in your namespace.
- [Set up your own namespace in IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#registry_namespace_setup).
- [Pull](#registry_images_pulling_reg) an image on your local computer and tag the image with your namespace information.
- [Make sure that you can run Docker commands without root permissions](https://docs.docker.com/engine/install/linux-postinstall/){: external}. If your Docker client is set up to require root permissions, you must run `ibmcloud login`, `ibmcloud cr login`, `docker pull`, and `docker push` commands with `sudo`.

    If you change your permissions to run Docker commands without root privileges, you must run the `ibmcloud login` command again.

IBM Cloud Container Registry supports other clients as well as Docker. To log in by using other clients, see [Accessing your namespaces interactively](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_access#registry_access_interactive).
{: tip}

To upload (push) an image, complete the following steps:

1. Log in to the CLI by running the [`ibmcloud cr login`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_login) command.

    ```txt
    ibmcloud cr login
    ```
    {: pre}

    You must log in if you pull an image from your private IBM Cloud Container Registry.
    {: requirement}

    If you have a problem when you try to log in, see [Why can't I log in to Container Registry?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-login) for assistance.
    {: tip}

2. To view all namespaces that are available in your account, run the `ibmcloud cr namespace-list` command.
3. [Upload the image to your namespace.](https://cloud.ibm.com/docs/Registry?topic=Registry-getting-started#gs_registry_images_pushing)

    If you get an `unauthorized: authentication required` or a `denied: requested access to the resource is denied` message, run the `ibmcloud cr login` command.
    {: tip}

After you push your image to IBM Cloud Container Registry, you can do one of the following tasks.

- [Manage security with Vulnerability Advisor](https://cloud.ibm.com/docs/Registry?topic=Registry-va_index&interface=ui) to find information about potential security issues and vulnerabilities.
- [Create a cluster and use this image to deploy a container](https://cloud.ibm.com/docs/containers?topic=containers-getting-started#getting-started) to the cluster in IBM Cloud Kubernetes Service.

## Copying images between registries
{: #registry_images_copying}
{: help}
{: support}

You can copy images between registries by pulling an image from a registry in one region and pushing it to a registry in another region so that you can share the image with users in both regions.

![Copying images between registries.](images/copying_images_mul.svg "Pull an image from a registry in one region and push it to a registry in another region."){: caption="Copying images between registries" caption-side="bottom"}{: external download="../images/copying_images_mul.svg"}

Before you begin, complete the following tasks.

- [Install the CLI](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#cli_namespace_registry_cli_install) to work with images in your namespace.
- [Set up your own namespace in IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#registry_namespace_setup).
- [Make sure that you can run Docker commands without root permissions](https://docs.docker.com/engine/install/linux-postinstall/){: external}. If your Docker client is set up to require root permissions, you must run `ibmcloud login`, `ibmcloud cr login`, `docker pull`, and `docker push` commands with `sudo`.

    If you change your permissions to run Docker commands without root privileges, you must run the `ibmcloud login` command again.

To copy an image between two registries, complete the following steps:

1. [Pull an image from a registry](#registry_images_pulling_reg).
2. [Push the image to another registry](#registry_images_pushing_namespace). Make sure that you use the correct [domain name](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_domain_name) for the new region you're targeting.

After you copy your image, you can do one of the following tasks.

- [Manage image security with Vulnerability Advisor](https://cloud.ibm.com/docs/Registry?topic=Registry-va_index&interface=ui) to find information about potential security issues and vulnerabilities.
- [Create a cluster and use this image to deploy a container](https://cloud.ibm.com/docs/containers?topic=containers-getting-started#getting-started) to the cluster in IBM Cloud Kubernetes Service.

## Creating images that refer to a source image
{: #registry_images_source}
{: help}
{: support}

Create an image by using the [`ibmcloud cr image-tag`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_tag) command.

In the region that you're logged in to, create an image in IBM Cloud Container Registry that refers to an existing image in the same region. This action is supported for source images that are created by using supported versions of Docker Engine, see [Support for Docker](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#docker).

New images that are created by using this mechanism do not retain signatures. If you require the new image to be signed, do not use this mechanism.
{: important}

Before you begin, complete the following tasks.

- [Install the CLI](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#cli_namespace_registry_cli_install) to work with images in your namespace.
- Ensure that you have access to a private namespace in IBM Cloud Container Registry that contains a source image to which you want to refer another image.

To create an image from a source image, complete the following steps.

1. Log in to the CLI by running the [`ibmcloud cr login`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_login) command.

    ```txt
    ibmcloud cr login
    ```
    {: pre}

2. Run the following command to add the new reference, where `SOURCE_IMAGE` is the name of your source image and `TARGET_IMAGE` is the name of your target image. The source and target images must be in the same region. `SOURCE_IMAGE` must be in the format `repository:tag` or `repository@digest` and `TARGET_IMAGE` must be in the format `repository:tag`, for example, `us.icr.io/namespace/image:latest`.

    To find the names of your images, run `ibmcloud cr image-list`. Combine the content of the **Repository** column (`repository`) and **Tag** column (`tag`) separated by a colon (`:`) to create the image name in the format `repository:tag`. To identify your image by digest, run the `ibmcloud cr image-digests` command. Combine the content of the **Repository** column (`repository`) and the **Digest** column (`digest`) separated by an at (`@`) symbol to create the image name in the format `repository@digest`. If the list images command times out, see [Why is it timing out when I list images?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-image-timeout) for assistance.
    {: tip}

    ```txt
    ibmcloud cr image-tag [SOURCE_IMAGE] [TARGET_IMAGE]
    ```
    {: pre}

3. Verify that the new image was created by running the following command, and check that the image is shown in the list with the same image [digest](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_digest) as the source image.

    ```txt
    ibmcloud cr image-list
    ```
    {: pre}

## Pushing images by using an API key
{: #registry_api_key_push_image}
{: help}
{: support}

Create a service ID that uses an [API key](#x8051010){: term} to push images to IBM Cloud Container Registry.

Complete the following steps:

1. Create a service ID, see [Creating and working with service IDs](https://cloud.ibm.com/docs/iam?topic=iam-serviceids&interface=ui#serviceids).
2. Create a policy that gives the service ID permission to access the registry, for example, Administrator and Manager roles, see [Managing IAM access for Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-iam).
3. Create an API key, see [Creating an API key for a service ID](https://cloud.ibm.com/docs/iam?topic=iam-serviceidapikeys&interface=ui#create_service_key).
4. Use the API key to log in to registry so that you can push images to the registry, see [Automating access to IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_access).
5. Push your images, see [Pushing Docker images to your namespace](#registry_images_pushing_namespace).

You can now use clusters to pull the images, see [Building containers from images](https://cloud.ibm.com/docs/containers?topic=containers-images).

## Removing tags from images in your private repository
{: #registry_images_untag}
{: help}
{: support}

You can remove a [tag](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_tag), or tags, from an image in your private IBM Cloud repository, and make sure that the underlying image and any other tags remain in place by using the [`ibmcloud cr image-untag`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_untag) command.

If multiple tags exist for the same image [digest](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_digest) within a repository and you want to remove the underlying image and all its tags, see [Deleting images from your private IBM Cloud repository](#registry_images_remove).
{: tip}

To remove a tag, or tags, by using the CLI, complete the following steps:

1. Log in to IBM Cloud by running the `ibmcloud login` command.
2. To remove a tag, run the following command, where `IMAGE` is the name of the image that you want to remove, in the format `repository:tag`. If a tag is not specified in the image name, the command fails. You can delete the tags for multiple images by listing each private IBM Cloud registry path in the command with a space between each path.

    ```sh
    ibmcloud cr image-untag IMAGE
    ```

    To find the names of your images, run `ibmcloud cr image-list`. Combine the content of the **Repository** column (`repository`) and **Tag** column (`tag`) separated by a colon (`:`) to create the image name in the format `repository:tag`.
    {: tip}

3. Verify that the tag was removed by running the following command, and check that the tag does not show in the list.

    ```sh
    ibmcloud cr image-list
    ```
    {: pre}

    If the list images command times out, see [Why is it timing out when I list images?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-image-timeout) for assistance.
    {: tip}

## Deleting images from your private repository
{: #registry_images_remove}

You can delete unwanted images from your private IBM Cloud repository by using either the IBM Cloud console or the CLI.

If you want to delete a private repository and its associated images, see [Deleting a private repository and any associated images](#registry_repo_remove).

Deleting an image that is being used by an existing deployment might cause scale-up, reschedule, or both, to fail.
{: attention}

If you want to restore a deleted image, you can list the contents of the trash by running the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command and restore a selected image by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command.
{: tip}

Where multiple tags exist for the same image digest within a repository, the [`ibmcloud cr image-rm`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_rm) command removes the underlying image and all its tags. If the same image exists in a different repository or namespace, the copy of the image is not removed. If you want to remove a tag from an image and make sure that the underlying image and any other tags remain in place, see [Removing tags from images in your private repository](#registry_images_untag) command.
{: tip}

### Deleting images from your private repository in the CLI
{: #registry_images_remove_cli}

You can delete unwanted images and all their tags from your private IBM Cloud repository by using the CLI.

Deleting an image that is being used by an existing deployment might cause scale-up, reschedule, or both, to fail.
{: attention}

If you want to restore a deleted image, you can list the contents of the trash by running the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command and restore a selected image by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command.
{: tip}

To delete an image by using the CLI, complete the following steps:

1. Log in to IBM Cloud by running the `ibmcloud login` command.
2. To delete an image, run the following command, where `IMAGE` is the name of the image that you want to remove, in the format `repository@digest` or `repository:tag`. If a tag is not specified in the image name, the image tagged `latest` is deleted by default. You can delete multiple images by listing each private IBM Cloud registry path in the command with a space between each path.

    ```txt
    ibmcloud cr image-rm IMAGE
    ```
    {: pre}

    To find the names of your images, run `ibmcloud cr image-list`. Combine the content of the **Repository** column (`repository`) and **Tag** column (`tag`) separated by a colon (`:`) to create the image name in the format `repository:tag`. To identify your image by digest, run the `ibmcloud cr image-digests` command. Combine the content of the **Repository** column (`repository`) and the **Digest** column (`digest`) separated by an at (`@`) symbol to create the image name in the format `repository@digest`. If the list images command times out, see [Why is it timing out when I list images?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-image-timeout) for assistance.
    {: tip}

3. Verify that the image was deleted by running the following command, and check that the image does not show in the list.

    ```txt
    ibmcloud cr image-list
    ```
    {: pre}

### Deleting images from your private repository in the IBM Cloud console
{: #registry_images_remove_gui}

You can delete unwanted images and all their tags from your private IBM Cloud image repository by using the IBM Cloud console.

Deleting an image that is being used by an existing deployment might cause scale-up, reschedule, or both, to fail.
{: attention}

If you want to restore a deleted image, you can list the contents of the trash by running the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command and restore a selected image by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command.
{: tip}

To delete an image by using the IBM Cloud console, complete the following steps:

1. Log in to the IBM Cloud console [https://cloud.ibm.com/login](https://cloud.ibm.com/login){: external} with your IBMid.
2. If you have multiple IBM Cloud accounts, from the account menu, select the account and region that you want to use.
3. Click the **Navigation menu** icon, then click **Container Registry**.
4. Click **Images**. A list of your images is displayed.
5. In the row that contains the image that you want to delete, select the checkbox.
6. Click **Delete Image**.

## Listing images in the trash
{: #registry_images_list_trash}
{: help}
{: support}

You can list deleted images that are in the trash and see when they expire.

To find out which images are in the trash, you can use the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command. Images are stored in the trash for 30 days.

To list the images in the trash, complete the following steps:

1. Log in to IBM Cloud by running the `ibmcloud login` command.
2. List the images in the trash by using one of the following options:
    - List all the images in the trash by running the following command:

    ```txt
    ibmcloud cr trash-list
    ```
    {: pre}

    - List only the images in the trash for the namespace that you're interested in by running the following command, where `NAMESPACE` is your namespace:

    ```txt
    ibmcloud cr trash-list --restrict NAMESPACE
    ```
    {: pre}

## Restoring images
{: #registry_images_restore}

You can restore images from the trash. Deleted images are stored in the trash for 30 days.

You can restore an image from the trash by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command. To find out which images are in the trash, run the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command.

You can restore images by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command. You can use the following options:

- `REPO@DIGEST` this option restores the digest and all its tags in the repository that aren't already in the live repository. For more information, see [Restoring images by digest](#registry_images_restore_digest).
- `REPO:TAG` this option restores the tag. For more information, see [Restoring images by tag](#registry_images_restore_tag).

### Restoring images by digest
{: #registry_images_restore_digest}
{: help}
{: support}

When you restore an image by digest, the digest is copied from the trash into your live repository, and all the tags for the digest in the repository are restored. The digest continues to show in the trash because a copy is restored.

To restore an image from the trash by using the digest, complete the following steps:

1. Log in to IBM Cloud by running the `ibmcloud login` command.
2. List the images in the trash by running the following command:

    ```txt
    ibmcloud cr trash-list
    ```
    {: pre}

    A table is displayed that shows the items in the trash. The table shows the digest, the days until expiry, and the tags for that digest.

3. Note the digest for the image that you want to restore.
4. Run the following command to restore the image to your repository. Where `DNS` is the [domain name](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_domain_name), `NAMESPACE` is the [namespace](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_namespace), `REPO` is the [repository](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_repository), and `DIGEST` is the [digest](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_digest) of the image that you want to restore.

    ```txt
    ibmcloud cr image-restore DNS/NAMESPACE/REPO@DIGEST
    ```
    {: pre}

    If some tags aren't restored, see [Why aren't all the tags restored when I restore by digest?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-image-restore-digest) for assistance.
    {: tip}

    In your live repository, you can pull the image by digest. If you run the [`ibmcloud cr image-digests`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_digests) command, the image shows in the output.
    {: tip}

### Restoring images by tag
{: #registry_images_restore_tag}
{: help}
{: support}

When you restore an image by tag, only that specific tag is moved out of the trash into your live repository.

To restore an image from the trash by using a tag, complete the following steps:

1. Log in to IBM Cloud by running the `ibmcloud login` command.
2. List the images in the trash by running the following command:

    ```txt
    ibmcloud cr trash-list
    ```
    {: pre}

    A table is displayed that shows the items in the trash. The table shows the digest, the days until expiry, and the tags for that digest.

3. For the image that you want to restore, make a note of the digest up to, but not including, the at sign (`@`). This part of the digest is `DNS/NAMESPACE/REPO`, where `DNS` is the domain name, `NAMESPACE` is the namespace, and `REPO` is the repository.
4. For the image that you want to restore, make a note of the tag `TAG`.
5. Run the following command to restore the image to your repository, where `DNS/NAMESPACE/REPO` is the name of the image that you want to restore and `TAG` is the tag.

    ```txt
    ibmcloud cr image-restore DNS/NAMESPACE/REPO:TAG
    ```
    {: pre}

    In your live repository, you can pull the image by tag.

    If you get an error when you're restoring an image that says that the tagged image exists, see [Why do I get an error when I'm restoring an image?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-image-restore) for assistance.
    {: tip}

    If you run the `ibmcloud cr trash-list` command, the digest and any other tags show in the output, but the tag is no longer displayed.
    {: tip}

## Deleting a private repository and any associated images
{: #registry_repo_remove}
{: help}
{: support}

You can delete private repositories that are no longer required, and any associated images, by using the IBM Cloud console.

When you delete a repository, all images in that repository are deleted. This action can't be undone.
{: attention}

Before you begin, you must back up any images that you want to keep.
{: important}

To delete a private repository by using the IBM Cloud console, complete the following steps:

1. Log in to the IBM Cloud console [https://cloud.ibm.com/login](https://cloud.ibm.com/login){: external} with your IBMid.
2. If you have multiple IBM Cloud accounts, from the account menu, select the account and region that you want to use.
3. Click the **Navigation menu** icon, then click **Container Registry**.
4. Click **Repositories**. A list of your private repositories is displayed.
5. In the row that contains the private repository that you want to delete, select the checkbox.

    Ensure that the correct repository is selected because this action can't be undone.
    {: attention}

6. Click **Delete Repository**.

================================

---
name: Registry-registry_helm_charts
title: Using Helm charts in Container Registry
description: You can securely store and share Helm charts with other users in IBM Cloud&reg; Container Registry.
last-updated: 2025-10-10
---

# Using Helm charts in Container Registry
{: #registry_helm_charts}


You can securely store and share Helm charts with other users in IBM Cloud&reg; Container Registry.
{: shortdesc}

## OCI support for Helm charts
{: #registry_helm_charts_oci}

The [Open Container Initiative (OCI)](https://opencontainers.org){: external} released [Open Container Initiative Distribution Specification v1.0.0](https://specs.opencontainers.org/distribution-spec/?v=v1.0.0){: external} in September 2021. This specification supports other artifact types in addition to container images. One of the [artifact types that is supported](https://github.com/opencontainers/artifacts/blob/main/artifact-authors.md#defining-oci-artifact-types){: external} is the [Helm chart](https://helm.sh/docs/topics/charts/){: external}.

[Helm v3.8.0](https://github.com/helm/helm/releases/tag/v3.8.0){: external} provides support to store and work with charts in OCI registries, as an alternative to [Helm chart repositories](https://helm.sh/docs/topics/chart_repository/){: external}. For more information, see the [Helm Registries documentation](https://helm.sh/docs/topics/registries/){: external}.

## Adding Helm charts to your namespace
{: #registry_helm_charts_add}
{: help}
{: support}

You can securely store and share Helm charts with other users by adding charts to your [namespace](#x2031005){: term} in IBM Cloud Container Registry.

Every Helm chart that you want to add to your namespace must exist on your local computer first. You can either download (pull) a chart from another repository to your local computer, or build your own chart by using the [`helm create`](https://helm.sh/docs/helm/helm_create/){: external} command. To add a chart to your namespace, you must upload (push) the local chart to your namespace in IBM Cloud Container Registry.

Do not put personal information in your charts (for example, in namespace names or description fields) or in any chart or chart configuration data (for example, chart names or chart labels).
{: important}

### Pulling charts from another registry or Helm repository
{: #registry_helm_charts_pull}
{: help}
{: support}

You can pull (download) a chart from any private or public [registry](#x2064940){: term} source or Helm repository to your computer, and then tag it for later use in IBM Cloud Container Registry.

![Pull a chart from a private or public registry or Helm repository to your computer.](images/pulling_images_mul.svg "You can pull a chart from IBM Cloud Container Registry or from any private or public registry source or Helm repository to your local computer."){: caption="Pull charts from another registry" caption-side="bottom"}{: external download="../images/pulling_images_mul.svg"}

Before you begin, complete the following tasks.

- [Install the Container Registry command-line interface (CLI)](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#cli_namespace_registry_cli_install) to work with your namespace.
- [Set up your own namespace in IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#registry_namespace_setup).
- Install the latest release of [Helm CLI](https://github.com/helm/helm/releases){: external} to work with charts.

1. Download the Helm chart to your local computer.

    - Download the Helm chart from the OCI registry:

        ```sh
        helm pull oci://REGISTRY/MY_NAMESPACE/CHART_NAME --version CHART_VERSION
        ```

        Example, where `REGISTRY` is `localhost:5000`, `MY_NAMESPACE` is `helm-charts`, `CHART_NAME` is `mychart`, and `CHART_VERSION` is `0.1.0`:

        ```sh
        helm pull oci://localhost:5000/helm-charts/mychart --version 0.1.0
        ```
        {: pre}

    - Download the Helm chart from a Helm repository:

        ```sh
        helm pull [CHART_URL | REPO/CHART_NAME] --version CHART_VERSION
        ```

        Example, where `REPO/CHART_NAME` is `ibm-charts/ibm-istio` and `CHART_VERSION` is `1.2.2`.

        You can add the repo alias by using the [`helm repo add`](https://helm.sh/docs/helm/helm_repo_add/){: external} command.
        {: tip}

        ```sh
        helm pull ibm-charts/ibm-istio  --version 1.2.2
        ```
        {: pre}

    If you get an `unauthorized: authentication required` or a `denied: requested access to the resource is denied` message, run the [`ibmcloud cr login`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_login) command.
    {: tip}

After you pull a chart for your [namespace](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_namespace), you can upload (push) the chart from your local computer to your namespace.

### Pushing Helm charts to your namespace
{: #registry_helm_charts_push}
{: help}
{: support}

You can push (upload) a chart from your computer to your namespace in IBM Cloud Container Registry to store your chart and share it with other users.

![Push a chart from your computer to IBM Cloud Container Registry.](images/pushing_images_mul.svg "You can push (upload) a chart from your local computer to your namespace in IBM Cloud Container Registry to store and share your chart with other users."){: caption="Push charts to your namespace" caption-side="bottom"}{: external download="../images/pushing_images_mul.svg"}

Before you begin, complete the following tasks.

- [Install the CLI](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#cli_namespace_registry_cli_install) to work with your namespace.
- [Set up your own namespace in IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#registry_namespace_setup).
- Install the latest release of [Helm CLI](https://github.com/helm/helm/releases){: external} to work with charts.
- [Pull](#registry_helm_charts_pull) or [create](https://helm.sh/docs/chart_template_guide/getting_started/){: external} a chart on your local computer. If you create a chart, you must save the chart as an archive by using the [`helm package`](https://helm.sh/docs/helm/helm_package/){: external} command.

To upload (push) a chart, complete the following steps:

1. Log in to the CLI by running the following command, where `DOMAIN` is the domain name and the username (`-u`) is set to `iamapikey`. To find out more about the domain names, see [Regions](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#registry_regions).

    ```sh
    helm registry login DOMAIN -u iamapikey
    ```

    The command then prompts you to input the password, which is the IAM API key.

    You must log in if you pull a chart from your private IBM Cloud Container Registry.
    {: requirement}

2. To view all namespaces that are available in your account, run the [`ibmcloud cr namespace-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_namespace_list) command.
3. Upload the chart to your namespace.

    ```sh
    helm push MY_CHART_PACKAGE oci://REGION.icr.io/MY_NAMESPACE
    ```

    Example, where `MY_CHART_PACKAGE` is `mychart-0.1.0.tgz`, `REGION` is `uk`, and `MY_NAMESPACE` is `helm-charts`:

    ```sh
    helm push mychart-0.1.0.tgz oci://uk.icr.io/helm-charts
    ```
    {: pre}

    If you get an `unauthorized: authentication required` or a `denied: requested access to the resource is denied` message, run the `ibmcloud cr login` command.
    {: tip}

After you push your chart to IBM Cloud Container Registry, you can [install the Helm chart to the cluster in IBM Cloud Kubernetes Service](#registry_helm_charts_install).

### Copying charts between registries
{: #registry_helm_charts_copy}
{: help}
{: support}

You can copy charts between registries by pulling a chart from a registry in one region and pushing it to a registry in another region so that you can share the chart with users in both regions.

![Copying charts between registries.](images/copying_images_mul.svg "Pull a chart from a registry in one region and push it to a registry in another region."){: caption="Copying charts between registries" caption-side="bottom"}{: external download="../images/copying_images_mul.svg"}

Before you begin, complete the following tasks.

- [Install the CLI](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#cli_namespace_registry_cli_install) to work with your namespace.
- [Set up your own namespace in IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_setup_cli_namespace#registry_namespace_setup).
- Install the latest release of [Helm CLI](https://github.com/helm/helm/releases){: external} to work with charts.

To copy a chart between two registries, complete the following steps:

1. [Pull a chart from a registry](#registry_helm_charts_pull).
2. [Push the chart to another registry](#registry_helm_charts_push). Make sure that you use the correct domain name for the new region that you are targeting.

After you copy your chart, you can [install the Helm chart to the cluster in IBM Cloud Kubernetes Service](#registry_helm_charts_install).

### Installing a Helm chart to the cluster
{: #registry_helm_charts_install}
{: help}
{: support}

You can install a Helm chart to the cluster in IBM Cloud Kubernetes Service directly from the registry. Follow the instructions in the Helm chart `README`, and use the full registry reference to the chart and chart version for installation.

```sh
helm install RELEASE_NAME oci://REGION.icr.io/MY_NAMESPACE/CHART_NAME --version CHART_VERSION
```

Example, where `RELEASE_NAME` is `myrelease`, `REGION` is `uk`, `MY_NAMESPACE` is `helm-charts`, `CHART_NAME` is `mychart`, and `CHART_VERSION` is `0.1.0`:

```sh
helm install myrelease oci://uk.icr.io/helm-charts/mychart --version 0.1.0
```
{: pre}

## Deleting charts from your private repository
{: #registry_helm_charts_remove}
{: help}
{: support}

You can delete unwanted charts from your private IBM Cloud [repository](https://cloud.ibm.com/docs/Registry?topic=Registry-registry_overview#overview_elements_repository) by using either the IBM Cloud console or the CLI.

If you want to delete a private repository and its associated charts, see [Deleting a private repository and any associated charts](#registry_helm_charts_repo_remove).

Deleting a chart that is being used by an existing deployment might cause a Helm upgrade, rollback, or delete to fail.
{: attention}

If you want to restore a deleted chart, you can list the contents of the trash by running the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command and restore a selected chart by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command. You can use these commands because Helm charts are a supported artifact type in OCI.
{: tip}

Where multiple [tags](#x2040924){: term} exist for the same chart digest within a repository, the [`ibmcloud cr image-rm`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_rm) command removes the underlying chart and all its tags. If the same chart exists in a different repository or namespace, then the copy of the chart is not removed.
{: tip}

A tag must always match the chart's semantic version, which means that a `latest` tag isn't used.
{: requirement}

### Deleting charts from your private repository in the CLI
{: #registry_helm_charts_remove_cli}
{: help}
{: support}

You can delete unwanted charts and all their tags from your private IBM Cloud repository by using the CLI.

Deleting a chart that is being used by an existing deployment might cause a Helm upgrade, rollback, or delete to fail.
{: attention}

If you want to restore a deleted chart, you can list the contents of the trash by running the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command and restore a selected chart by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command.
{: tip}

To delete a chart by using the CLI, complete the following steps:

1. Log in to IBM Cloud by running the `ibmcloud login` command.
2. To delete a chart, run the following command, where `CHART` is the name of the chart that you want to remove, in the format `repository@digest` or `repository:tag`. Unlike images, a tag must be specified because the `latest` tag doesn't exist because a tag must always match the chart's semantic version. You can delete multiple charts by listing each private IBM Cloud registry path in the command with a space between each path.

    ```sh
    ibmcloud cr image-rm CHART
    ```

    To find the names of your charts, run `ibmcloud cr image-list`. The registry stores different artifact types that include Helm charts and container images. Combine the content of the **Repository** column (`repository`) and **Tag** column (`tag`) separated by a colon (`:`) to create the image name in the format `repository:tag`. To identify your chart by digest, run the `ibmcloud cr image-digests` command. Combine the content of the **Repository** column (`repository`) and the **Digest** column (`digest`) separated by an at (`@`) symbol to create the image name in the format `repository@digest`.
    {: tip}

3. Verify that the chart was deleted by running the following command, and check that the chart does not show in the list.

    ```sh
    ibmcloud cr image-list
    ```
    {: pre}

### Deleting charts from your private repository in the IBM Cloud console
{: #registry_helm_charts_remove_gui}
{: help}
{: support}

You can delete unwanted charts and all their tags from your private IBM Cloud repository by using the IBM Cloud console.

Deleting a chart that is being used by an existing deployment might cause a Helm upgrade, rollback, or delete to fail.
{: attention}

If you want to restore a deleted chart, you can list the contents of the trash by running the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command and restore a selected chart by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command.
{: tip}

To delete a chart by using the IBM Cloud console, complete the following steps.

1. Log in to the IBM Cloud console [https://cloud.ibm.com/login](https://cloud.ibm.com/login){: external} with your IBMid.
2. If you have multiple IBM Cloud accounts, select the account and region that you want to use from the account menu.
3. Click the **Navigation menu** icon, then click **Container Registry**.
4. Click **Images**. A list of your charts (and images if they exist) is displayed. The registry stores different artifact types that include Helm charts and container images.
5. In the row that contains the chart that you want to delete, select the checkbox.
6. Click **Delete Image**.

## Listing charts in the trash
{: #registry_helm_charts_list_trash}
{: help}
{: support}

You can list deleted charts that are in the trash and see when they expire.

To find out which charts are in the trash, you can use the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command. Charts are stored in the trash for 30 days.

To list the charts in the trash, complete the following steps.

1. Log in to IBM Cloud by running the `ibmcloud login` command.
2. You can list the charts in the trash by running the following command.

    ```sh
    ibmcloud cr trash-list
    ```
    {: pre}

3. You can list only the charts in the trash for the namespace that you are interested in by running the following command, where `NAMESPACE` is your namespace.

    ```sh
    ibmcloud cr trash-list --restrict NAMESPACE
    ```

## Restoring charts
{: #registry_helm_charts_restore}
{: help}
{: support}

You can restore the charts from the trash. Deleted charts are stored in the trash for 30 days.

You can restore a chart from the trash by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command. To find out which charts are in the trash, run the [`ibmcloud cr trash-list`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_trash_list) command.

You can restore the charts by running the [`ibmcloud cr image-restore`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_restore) command. You can use the following options:

- `REPO@DIGEST` this option restores the digest and all its tags in the repository that aren't already in the live repository. For more information, see [Restoring charts by digest](#registry_helm_charts_restore_digest).
- `REPO:TAG` this option restores the tag. For more information, see [Restoring charts by tag](#registry_helm_charts_restore_tag).

### Restoring charts by digest
{: #registry_helm_charts_restore_digest}
{: help}
{: support}

When you restore a chart by digest, the digest is moved from the trash into your live repository, and all the tags for that digest in the repository are restored.

To restore a chart by digest from the trash, complete the following steps:

1. Log in to IBM Cloud by running the `ibmcloud login` command.
2. List the charts in the trash by running the following command.

    ```sh
    ibmcloud cr trash-list
    ```
    {: pre}

    A table is displayed that shows the items in the trash. The table shows the digest, the days until expiry, and the tags for that digest.

3. Note the digest for the chart that you want to restore.
4. Run the following command to restore the chart to your repository. Where `DNS` is the domain name, `NAMESPACE` is the namespace, `REPO` is the repository, and `DIGEST` is the digest of the chart that you want to restore.

    ```sh
    ibmcloud cr image-restore DNS/NAMESPACE/REPO@DIGEST
    ```

    If some tags aren't restored, see [Why aren't all the tags restored when I restore by digest?](https://cloud.ibm.com/docs/Registry?topic=Registry-troubleshoot-image-restore-digest) for assistance.
    {: tip}

    In your live repository, you can pull the chart by digest. If you run the [`ibmcloud cr image-digests`](https://cloud.ibm.com/docs/Registry?topic=Registry-containerregcli#bx_cr_image_digests) command, the chart shows in the output.
    {: tip}

### Restoring charts by tag
{: #registry_helm_charts_restore_tag}
{: help}
{: support}

When you restore a chart by tag, only that specific tag is moved out of the trash into your live repository.

To restore a chart by tag from the trash, complete the following steps.

1. Log in to IBM Cloud by running the `ibmcloud login` command.
2. List the charts in the trash by running the following command.

    ```sh
    ibmcloud cr trash-list
    ```
    {: pre}

    A table is displayed that shows the items in the trash. The table shows the digest, the days until expiry, and the tags for that digest.

3. For the chart that you want to restore, make a note of the digest up to, but not including, the at sign (`@`). This part of the digest is `DNS/NAMESPACE/REPO`, where `DNS` is the domain name, `NAMESPACE` is the namespace, and `REPO` is the repository.
4. For the chart that you want to restore, make a note of the tag `TAG`.
5. Run the following command to restore the chart to your repository, where `DNS/NAMESPACE/REPO` is the name of the chart that you want to restore and `TAG` is the tag.

    ```sh
    ibmcloud cr image-restore DNS/NAMESPACE/REPO:TAG
    ```

    In your live repository, you can pull the chart by tag.

    If you run the `ibmcloud cr trash-list` command, the digest and any other tags show in the output, but the tag is no longer displayed.
    {: tip}

## Deleting a private repository and any associated charts
{: #registry_helm_charts_repo_remove}
{: help}
{: support}

You can delete private repositories that are no longer required, and any associated charts, by using the IBM Cloud console.

When you delete a repository, all charts in that repository are deleted. This action can't be undone.
{: attention}

Before you begin, you must back up any charts that you want to keep.
{: important}

To delete a private repository by using the IBM Cloud console, complete the following steps.

1. Log in to the IBM Cloud console [https://cloud.ibm.com/login](https://cloud.ibm.com/login){: external} with your IBMid.
2. If you have multiple IBM Cloud accounts, select the account and region that you want to use from the account menu.
3. Click the **Navigation menu** icon, then click **Container Registry**.
4. Click **Repositories**. A list of your private repositories is displayed.
5. In the row that contains the private repository that you want to delete, select the checkbox.

    Ensure that the correct repository is selected because this action can't be undone.
    {: attention}

6. Click **Delete Repository**.

================================