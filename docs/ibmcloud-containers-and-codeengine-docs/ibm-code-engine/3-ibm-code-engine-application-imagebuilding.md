================================

---

name: codeengine-persistentdatastore
title: Working with persistent data stores
description: You can mount an IBM Cloud Object Storage(COS) bucket to your IBM Cloud&reg; Code Engine application or job by using a **persistent data store**. This feature allows your workloads to access the contents of a COS bucket through the local file system by using standard file operations.
last-updated: 2026-05-19
---

# Working with persistent data stores

{: #persistent-data-store}

You can mount an IBM Cloud Object Storage(COS) bucket to your IBM Cloud&reg; Code Engine application or job by using a **persistent data store**. This feature allows your workloads to access the contents of a COS bucket through the local file system by using standard file operations.

A persistent data store in Code Engine is a reference to an existing data store that Code Engine does not manage. Currently, IBM Cloud Object Storage is the only supported data store type. By creating a reference to your COS bucket, you can mount it directly into your application or job container's file system.

## Before you begin

{: #pds-prereqs-ui}
{: ui}

Before you can work with persistent data stores, ensure that the following prerequisites are met.

- You must have an [IBM Cloud Object Storage instance](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-provision).
- You must create a service credential for your Object Storage instance with [**HMAC credentials**](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-uhc-hmac-credentials-main) enabled. The HMAC credential requires at least the **Writer** service access role to read from and write to the bucket. If you only need read access, choose the **Content Reader** service access role instead.
- You must have a bucket available in your Object Storage instance. For more information, see [Create a new bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage).
- You must have a [Code Engine project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project) and it must be selected as the current context.

## Step 1: Create an HMAC secret in Code Engine by using the console

{: #pds-create-secret-ui}
{: ui}

To securely access your COS bucket, Code Engine requires the HMAC credentials that are associated with your Object Storage instance. You store these credentials in a secret within your Code Engine project.

Follow [Creating an HMAC secret from the console](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secret#secret-create-ui-hmac) to create a secret of format `HMAC`.

Provide the corresponding values from your COS service credential when prompted.

## Step 2: Create a persistent data store by using the console

{: #pds-create-datastore-ui}
{: ui}

Now, create the persistent data store resource in Code Engine. This resource acts as a reference to your COS bucket and links it with the HMAC secret that you created.

1. Click the name of your project on the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}.
2. From the Components page, click **Persistent data stores**.
3. From the Persistent data stores page, click **Create**.
4. From the Create a persistent data store page, complete the following steps:
    1. Provide a name; for example, `mysecret-hmac`.
    2. Specify if to **Select existing** COS bucket specification or if you want to **Add manually**.
    3. **Select a COS instance** or specify its name manually.
    4. **Select a bucket** or specify its name manually.
    5. Select the HMAC **Access secret** needed to authenticate to the COS instance.
    6. Click **Create** to create the persistent data store.

## Step 3: Mount the data store into a workload by using the console

{: #pds-mount-workload-ui}
{: ui}

After you create the persistent data store, you can mount it as **Volume mount** when you create or update an application or job.

### Mounting into an application

{: #pds-mount-app-ui}
{: ui}

1. Navigate to your app.
    - From the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}, click the name of your project. Click **Applications** to work with your applications.
    - From the Applications page, click the name of the application that you want to update or create a new one by clicking **Create**.

2. Select the **Configuration** tab.
3. From the **Volume mounts** tab, click **Add**.
4. Select **Volume type** as **Persistent data stores**.
5. Select a **Persistent data store**.
6. Specify a relative **Bucket subpath (optional)** if your application should access objects in the bucket with that subpath prefix only, for example `path/in/bucket`. This is useful when you want to isolate access to a specific folder within the bucket. The subpath must be a valid prefix in your COS bucket. Only the contents under that path will be accessible from the mounted directory.
7. Specify **Mount path**. This is the directory inside the application container where the data of the volume mount can be accessed, for example at `/mnt/bucket`.
8. Select a value for **Access permissions**, that is **Read-write** or **Read-only**.
9. Click **Add** to create the volume mount.
10. Click **Deploy** to save your changes and deploy the app revision.

When you update your application, your app creates a new revision and routes traffic to that instance.

### Mounting into a job

{: #pds-mount-job-ui}
{: ui}

1. Navigate to your job page.
    - From the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}, click the name of your project. Click **Jobs** to work with your jobs and job runs.
    - From the Jobs page, click the **Jobs** tab, and click the name of the job that you want to update or create a new one by clicking **Create**.

2. Select the **Configuration** tab.
3. From the **Volume mounts** tab, click **Add**.
4. Select **Volume type** as **Persistent data stores**.
5. Select a **Persistent data store**.
6. Specify a relative **Bucket subpath (optional)** if your job runs should access objects in the bucket with that subpath prefix only, for example `path/in/bucket`. This is useful when you want to isolate access to a specific folder within the bucket. The subpath must be a valid prefix in your COS bucket. Only the contents under that path will be accessible from the mounted directory.
7. Specify **Mount path**. This is the directory inside the job run container where the data of the volume mount can be accessed, for example at `/mnt/bucket`.
8. Select a value for **Access permissions**, that is **Read-write** or **Read-only**.
9. Click **Add** to create the volume mount.
10. Click **Deploy** to save your changes and deploy the job.
11. Click **Submit job**.

## Before you begin

{: #pds-prereqs-cli}
{: cli}

Before you can work with persistent data stores, ensure that the following prerequisites are met.

- You must have an [IBM Cloud Object Storage instance](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-provision).
- You must create a service credential for your Object Storage instance with [**HMAC credentials**](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-uhc-hmac-credentials-main) enabled. The HMAC credential requires at least the **Writer** service access role to read from and write to the bucket. If you only need read access, choose the **Content Reader** service access role instead.
- You must install the IBM Cloud Object Storage plugin by running the following command:

  ```txt
  ibmcloud plugin install cloud-object-storage
  ```

  {: pre}

- You must have a bucket available in your Object Storage instance. For more information, see [Create a new bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-ic-cos-cli#create-a-new-bucket).
- You must have a [Code Engine project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project) and it must be selected as the current context.

## Step 1: Create an HMAC secret in Code Engine by using the CLI

{: #pds-create-secret-cli}
{: cli}

To securely access your COS bucket, Code Engine requires the HMAC credentials that are associated with your Object Storage instance. You store these credentials in a secret within your Code Engine project.

To create a secret of format `hmac`, use the **`secret create`** command.

```bash
ibmcloud ce secret create --name my-hmac-secret --format hmac --secret-access-key-prompt --access-key-id-prompt
```

{: pre}

Provide the corresponding values from your COS service credential when prompted by the **`secret create`** command.

## Step 2: Create a persistent data store by using the CLI

{: #pds-create-datastore-cli}
{: cli}

Now, create the persistent data store resource in Code Engine. This resource acts as a reference to your COS bucket and links it with the HMAC secret that you created.

```bash
ibmcloud ce persistentdatastore create --name my-cos-bucket-pds --cos-bucket-name my-cos-bucket --cos-access-secret my-hmac-secret
```

{: pre}

- Replace `my-cos-bucket-pds` with a unique name for your data store.
- Replace `my-cos-bucket` with the exact name of your COS bucket.
- Replace `my-hmac-secret` with the name of the HMAC secret.

## Step 3: Mount the data store into a workload by using the CLI

{: #pds-mount-workload-cli}
{: cli}

After you create the persistent data store, you can mount it when you create or update an application or job. Use the `--mount-data-store` option with the format `MOUNT_PATH=PDS_NAME`.

### Mounting into an application

{: #pds-mount-app-cli}
{: cli}

The following command creates an application named `myapp` and mounts the `my-cos-bucket-pds` data store to the `/mnt/bucket` directory inside the application container.

```bash
ibmcloud ce application create --name myapp --image icr.io/codeengine/helloworld --mount-data-store /mnt/bucket=my-cos-bucket-pds
```

{: pre}

### Mounting into a job

{: #pds-mount-job-cli}
{: cli}

Similarly, this command creates a job named `myjob` and mounts the same data store to the `/mnt/bucket` directory.

```bash
ibmcloud ce job create --name myjob --image icr.io/codeengine/helloworld --mount-data-store /mnt/bucket=my-cos-bucket-pds
```

{: pre}

### Mounting a subpath within the bucket

{: #pds-mount-subpath-cli}
{: cli}

You can also mount a specific subpath within your COS bucket by appending the relative path to the mount definition using a colon (`:`). This is useful when you want to isolate access to a specific folder within the bucket.

For example, to mount only the `path/in/bucket` directory from the `my-cos-bucket-pds` data store into `/mnt/bucket`:

```bash
ibmcloud ce application create --name myapp --image icr.io/codeengine/helloworld --mount-data-store /mnt/bucket=my-cos-bucket-pds:path/in/bucket
```

{: pre}

Or for a job:

```bash
ibmcloud ce job create --name myjob --image icr.io/codeengine/helloworld --mount-data-store /mnt/bucket=my-cos-bucket-pds:path/in/bucket
```

{: pre}

> **Note:** The `path/in/bucket` must be a valid prefix in your COS bucket. Only the contents under that path will be accessible from the mounted directory.

## Step 4: Accessing files in the mounted data store

{: #pds-access-files}

Once your application or job is running, the code can interact with the mounted COS bucket as if it were a local directory. All standard file system operations are supported.

For example, inside your container, you can list files, read content, and write new files:

```bash
# List files in the bucket
ls -l /mnt/bucket

# Read a file from the bucket
cat /mnt/bucket/my-document.txt

# Write a new file to the bucket
echo "Hello from Code Engine" > /mnt/bucket/new-file.txt
```

{: pre}

## Limitations

{: #pds-limitations}

The mount is implemented using [`s3fs`](https://github.com/s3fs-fuse/s3fs-fuse){: external}, which provides a FUSE-based file system interface to S3-compatible storage. Be aware of the following limitations:

- **Number of persistent data stores:**
  - There is a restriction allowing a maximum of two persistent data store mounts per application or job.
- **Performance:**
  - Object Storage has high latency for the time-to-first-byte, making them slower than local file systems for operations that require immediate access.
  - Operations that modify files, such as random writes or appends, require rewriting the entire object in the backend, which can be slow and inefficient as there is no random write access.
  - Metadata operations, like listing directories, can have poor performance.
- **Consistency:**
  - IBM Cloud Object Storage provides strong read-after-write consistency for new objects, but eventual consistency for object overwrites and deletes. This means that after an update or deletion, read operations might temporarily return stale data.
  - Changes made to the bucket from outside the mount (for example, directly via the COS API or another client) are not immediately detected and might not be visible for some time.
- **File System Semantics:**
  - Standard POSIX file system features are not fully supported. Specifically, there are **no atomic renames** of files or directories and **no hard links**.
- **Concurrency:**
  - There is no coordination between multiple clients (for example, multiple app instances) mounting the same bucket. Concurrent writes to the same file from different instances can lead to data loss or corruption.
- **Event Subscriptions:**
  - If you have configured an event subscription for your Object Storage bucket, be aware that file create operations performed through the mount may generate multiple update events. This can result in your Code Engine app or job being triggered more than once for a single file operation, which may affect downstream processing or event-driven workflows.
Due to these limitations, this feature is not suitable for all workloads. It is best suited for workloads that primarily read large files, such as in deep learning or data analytics, where good throughput can be achieved. It is not recommended for workloads that require low latency, frequent small writes, or transactional file operations.

---

name: codeengine-persistentdatastore
title: Working with persistent data stores
description: You can mount an IBM Cloud Object Storage(COS) bucket to your IBM Cloud&reg; Code Engine application or job by using a **persistent data store**. This feature allows your workloads to access the contents of a COS bucket through the local file system by using standard file operations.
last-updated: 2026-05-19
---

# Working with persistent data stores

{: #persistent-data-store}

You can mount an IBM Cloud Object Storage(COS) bucket to your IBM Cloud&reg; Code Engine application or job by using a **persistent data store**. This feature allows your workloads to access the contents of a COS bucket through the local file system by using standard file operations.

A persistent data store in Code Engine is a reference to an existing data store that Code Engine does not manage. Currently, IBM Cloud Object Storage is the only supported data store type. By creating a reference to your COS bucket, you can mount it directly into your application or job container's file system.

## Before you begin

{: #pds-prereqs-ui}
{: ui}

Before you can work with persistent data stores, ensure that the following prerequisites are met.

- You must have an [IBM Cloud Object Storage instance](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-provision).
- You must create a service credential for your Object Storage instance with [**HMAC credentials**](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-uhc-hmac-credentials-main) enabled. The HMAC credential requires at least the **Writer** service access role to read from and write to the bucket. If you only need read access, choose the **Content Reader** service access role instead.
- You must have a bucket available in your Object Storage instance. For more information, see [Create a new bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-getting-started-cloud-object-storage).
- You must have a [Code Engine project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project) and it must be selected as the current context.

## Step 1: Create an HMAC secret in Code Engine by using the console

{: #pds-create-secret-ui}
{: ui}

To securely access your COS bucket, Code Engine requires the HMAC credentials that are associated with your Object Storage instance. You store these credentials in a secret within your Code Engine project.

Follow [Creating an HMAC secret from the console](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secret#secret-create-ui-hmac) to create a secret of format `HMAC`.

Provide the corresponding values from your COS service credential when prompted.

## Step 2: Create a persistent data store by using the console

{: #pds-create-datastore-ui}
{: ui}

Now, create the persistent data store resource in Code Engine. This resource acts as a reference to your COS bucket and links it with the HMAC secret that you created.

1. Click the name of your project on the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}.
2. From the Components page, click **Persistent data stores**.
3. From the Persistent data stores page, click **Create**.
4. From the Create a persistent data store page, complete the following steps:
    1. Provide a name; for example, `mysecret-hmac`.
    2. Specify if to **Select existing** COS bucket specification or if you want to **Add manually**.
    3. **Select a COS instance** or specify its name manually.
    4. **Select a bucket** or specify its name manually.
    5. Select the HMAC **Access secret** needed to authenticate to the COS instance.
    6. Click **Create** to create the persistent data store.

## Step 3: Mount the data store into a workload by using the console

{: #pds-mount-workload-ui}
{: ui}

After you create the persistent data store, you can mount it as **Volume mount** when you create or update an application or job.

### Mounting into an application

{: #pds-mount-app-ui}
{: ui}

1. Navigate to your app.
    - From the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}, click the name of your project. Click **Applications** to work with your applications.
    - From the Applications page, click the name of the application that you want to update or create a new one by clicking **Create**.

2. Select the **Configuration** tab.
3. From the **Volume mounts** tab, click **Add**.
4. Select **Volume type** as **Persistent data stores**.
5. Select a **Persistent data store**.
6. Specify a relative **Bucket subpath (optional)** if your application should access objects in the bucket with that subpath prefix only, for example `path/in/bucket`. This is useful when you want to isolate access to a specific folder within the bucket. The subpath must be a valid prefix in your COS bucket. Only the contents under that path will be accessible from the mounted directory.
7. Specify **Mount path**. This is the directory inside the application container where the data of the volume mount can be accessed, for example at `/mnt/bucket`.
8. Select a value for **Access permissions**, that is **Read-write** or **Read-only**.
9. Click **Add** to create the volume mount.
10. Click **Deploy** to save your changes and deploy the app revision.

When you update your application, your app creates a new revision and routes traffic to that instance.

### Mounting into a job

{: #pds-mount-job-ui}
{: ui}

1. Navigate to your job page.
    - From the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}, click the name of your project. Click **Jobs** to work with your jobs and job runs.
    - From the Jobs page, click the **Jobs** tab, and click the name of the job that you want to update or create a new one by clicking **Create**.

2. Select the **Configuration** tab.
3. From the **Volume mounts** tab, click **Add**.
4. Select **Volume type** as **Persistent data stores**.
5. Select a **Persistent data store**.
6. Specify a relative **Bucket subpath (optional)** if your job runs should access objects in the bucket with that subpath prefix only, for example `path/in/bucket`. This is useful when you want to isolate access to a specific folder within the bucket. The subpath must be a valid prefix in your COS bucket. Only the contents under that path will be accessible from the mounted directory.
7. Specify **Mount path**. This is the directory inside the job run container where the data of the volume mount can be accessed, for example at `/mnt/bucket`.
8. Select a value for **Access permissions**, that is **Read-write** or **Read-only**.
9. Click **Add** to create the volume mount.
10. Click **Deploy** to save your changes and deploy the job.
11. Click **Submit job**.

## Before you begin

{: #pds-prereqs-cli}
{: cli}

Before you can work with persistent data stores, ensure that the following prerequisites are met.

- You must have an [IBM Cloud Object Storage instance](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-provision).
- You must create a service credential for your Object Storage instance with [**HMAC credentials**](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-uhc-hmac-credentials-main) enabled. The HMAC credential requires at least the **Writer** service access role to read from and write to the bucket. If you only need read access, choose the **Content Reader** service access role instead.
- You must install the IBM Cloud Object Storage plugin by running the following command:

  ```txt
  ibmcloud plugin install cloud-object-storage
  ```

  {: pre}

- You must have a bucket available in your Object Storage instance. For more information, see [Create a new bucket](https://cloud.ibm.com/docs/cloud-object-storage?topic=cloud-object-storage-ic-cos-cli#create-a-new-bucket).
- You must have a [Code Engine project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project) and it must be selected as the current context.

## Step 1: Create an HMAC secret in Code Engine by using the CLI

{: #pds-create-secret-cli}
{: cli}

To securely access your COS bucket, Code Engine requires the HMAC credentials that are associated with your Object Storage instance. You store these credentials in a secret within your Code Engine project.

To create a secret of format `hmac`, use the **`secret create`** command.

```bash
ibmcloud ce secret create --name my-hmac-secret --format hmac --secret-access-key-prompt --access-key-id-prompt
```

{: pre}

Provide the corresponding values from your COS service credential when prompted by the **`secret create`** command.

## Step 2: Create a persistent data store by using the CLI

{: #pds-create-datastore-cli}
{: cli}

Now, create the persistent data store resource in Code Engine. This resource acts as a reference to your COS bucket and links it with the HMAC secret that you created.

```bash
ibmcloud ce persistentdatastore create --name my-cos-bucket-pds --cos-bucket-name my-cos-bucket --cos-access-secret my-hmac-secret
```

{: pre}

- Replace `my-cos-bucket-pds` with a unique name for your data store.
- Replace `my-cos-bucket` with the exact name of your COS bucket.
- Replace `my-hmac-secret` with the name of the HMAC secret.

## Step 3: Mount the data store into a workload by using the CLI

{: #pds-mount-workload-cli}
{: cli}

After you create the persistent data store, you can mount it when you create or update an application or job. Use the `--mount-data-store` option with the format `MOUNT_PATH=PDS_NAME`.

### Mounting into an application

{: #pds-mount-app-cli}
{: cli}

The following command creates an application named `myapp` and mounts the `my-cos-bucket-pds` data store to the `/mnt/bucket` directory inside the application container.

```bash
ibmcloud ce application create --name myapp --image icr.io/codeengine/helloworld --mount-data-store /mnt/bucket=my-cos-bucket-pds
```

{: pre}

### Mounting into a job

{: #pds-mount-job-cli}
{: cli}

Similarly, this command creates a job named `myjob` and mounts the same data store to the `/mnt/bucket` directory.

```bash
ibmcloud ce job create --name myjob --image icr.io/codeengine/helloworld --mount-data-store /mnt/bucket=my-cos-bucket-pds
```

{: pre}

### Mounting a subpath within the bucket

{: #pds-mount-subpath-cli}
{: cli}

You can also mount a specific subpath within your COS bucket by appending the relative path to the mount definition using a colon (`:`). This is useful when you want to isolate access to a specific folder within the bucket.

For example, to mount only the `path/in/bucket` directory from the `my-cos-bucket-pds` data store into `/mnt/bucket`:

```bash
ibmcloud ce application create --name myapp --image icr.io/codeengine/helloworld --mount-data-store /mnt/bucket=my-cos-bucket-pds:path/in/bucket
```

{: pre}

Or for a job:

```bash
ibmcloud ce job create --name myjob --image icr.io/codeengine/helloworld --mount-data-store /mnt/bucket=my-cos-bucket-pds:path/in/bucket
```

{: pre}

> **Note:** The `path/in/bucket` must be a valid prefix in your COS bucket. Only the contents under that path will be accessible from the mounted directory.

## Step 4: Accessing files in the mounted data store

{: #pds-access-files}

Once your application or job is running, the code can interact with the mounted COS bucket as if it were a local directory. All standard file system operations are supported.

For example, inside your container, you can list files, read content, and write new files:

```bash
# List files in the bucket
ls -l /mnt/bucket

# Read a file from the bucket
cat /mnt/bucket/my-document.txt

# Write a new file to the bucket
echo "Hello from Code Engine" > /mnt/bucket/new-file.txt
```

{: pre}

## Limitations

{: #pds-limitations}

The mount is implemented using [`s3fs`](https://github.com/s3fs-fuse/s3fs-fuse){: external}, which provides a FUSE-based file system interface to S3-compatible storage. Be aware of the following limitations:

- **Number of persistent data stores:**
  - There is a restriction allowing a maximum of two persistent data store mounts per application or job.
- **Performance:**
  - Object Storage has high latency for the time-to-first-byte, making them slower than local file systems for operations that require immediate access.
  - Operations that modify files, such as random writes or appends, require rewriting the entire object in the backend, which can be slow and inefficient as there is no random write access.
  - Metadata operations, like listing directories, can have poor performance.
- **Consistency:**
  - IBM Cloud Object Storage provides strong read-after-write consistency for new objects, but eventual consistency for object overwrites and deletes. This means that after an update or deletion, read operations might temporarily return stale data.
  - Changes made to the bucket from outside the mount (for example, directly via the COS API or another client) are not immediately detected and might not be visible for some time.
- **File System Semantics:**
  - Standard POSIX file system features are not fully supported. Specifically, there are **no atomic renames** of files or directories and **no hard links**.
- **Concurrency:**
  - There is no coordination between multiple clients (for example, multiple app instances) mounting the same bucket. Concurrent writes to the same file from different instances can lead to data loss or corruption.
- **Event Subscriptions:**
  - If you have configured an event subscription for your Object Storage bucket, be aware that file create operations performed through the mount may generate multiple update events. This can result in your Code Engine app or job being triggered more than once for a single file operation, which may affect downstream processing or event-driven workflows.
Due to these limitations, this feature is not suitable for all workloads. It is best suited for workloads that primarily read large files, such as in deep learning or data analytics, where good throughput can be achieved. It is not recommended for workloads that require low latency, frequent small writes, or transactional file operations.

================================

---
name: codeengine-add-registry
title: Accessing container registries
description: Images that are used by IBM Cloud&reg; Code Engine are typically stored in a registry that can either be accessible by the public (public registry) or set up with limited access for a small group of users (private registry).
last-updated: 2025-07-24
---

# Accessing container registries
{: #add-registry}

Images that are used by IBM Cloud&reg; Code Engine are typically stored in a registry that can either be accessible by the public (public registry) or set up with limited access for a small group of users (private registry).
{: shortdesc}

A container registry, or registry, is a service that stores container images. For example, IBM Cloud Container Registry and Docker Hub are container registries. A container registry can be public or private. A container registry that is public does not require credentials to access. In contrast, accessing a private registry does require credentials.

Code Engine requires access to container registries to complete the following actions:
- To retrieve (or "pull") a container image to run an app or job
- To store a newly created container image as an output of an image build
- To store and retrieve local files when a build is run from local source

Code Engine handles many of the underlying details of the interactions between the system and your registry.

To pull images from a registry, Code Engine uses a special type of Kubernetes secret that is called an `imagePullSecret`. This image pull secret stores the credentials to access a container registry. When you add access to a container registry with Code Engine to pull images, you are creating an image pull secret. For more information about image pull secrets, see [Kubernetes documentation](https://kubernetes.io/docs/home/){: external}.
{: note}

## Types of image registries
{: #types-registries}

Images are typically stored in a registry that can either be accessible by the public (public registry) or set up with limited access for a small group of users (private registry).

Public registries, such as public Docker Hub, can be used to get started with Docker and Code Engine to create your first application or job. But when it comes to enterprise workloads, use a private registry, such as the one provided in IBM Cloud Container Registry to protect your images from being used by unauthorized users. For private registries, use registry secrets to ensure that the credentials are available to gain access to the private registry.

| Registry                                                                                                           | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-getting-started#getting-started) | With this type of registry, you can set up your own secured image repository in IBM Cloud Container Registry where you can safely store and share images between users. \n With IBM Cloud Container Registry, you can \n - Manage access to images in your account. \n - Use IBM provided images and sample apps, such as IBM Liberty, as a base image and add your own app code to it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Any other private registry                                                                                         | Connect any existing private registry to Code Engine by adding access. Adding access securely saves your registry URL and credentials in a Kubernetes secret. \n With private registries, you can: \n - Use existing private registries independent of their source (Docker Hub, organization-owned registries, or other private Cloud registries).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| [Public Docker Hub](https://hub.docker.com/){: external}{: #dockerhub}                                             | Use this type of registry to pull existing public images from Docker Hub directly in your Code Engine applications or jobs. \n  \n Important:  \n - This registry type might not meet your organization's security requirements such as access management, vulnerability scanning, or app privacy. \n - When you pull an image from Docker Hub to use with apps or jobs in Code Engine, be aware of [Docker rate limits](https://docs.docker.com/docker-hub/usage/){: external} for free plan (unauthenticated) users. You might experience pull limits if you receive a `429` error which indicates that you have reached your pull rate limit. To [increase rate limits](https://docs.docker.com/docker-hub/usage/){: external}, you can upgrade your account to a Docker `Pro` or `Team` subscription. \n  \n With public Docker Hub, you can: \n - These images can be referred to directly when you create an app or job, no additional setup is required. \n - Includes various open source applications. |
{: caption="Public and private image registry types" caption-side="bottom"}

## Types of registry secrets
{: #types-registryaccesssecrets}

 To access images in a registry, Code Engine uses one of the following types of registry secrets.

* Code Engine managed secret - If your registry uses an IBM Cloud Container Registry namespace that is in your account, then you can let Code Engine create and manage the registry secret for you. In the console, this automatically created registry secret is called a `Code Engine managed secret`. In the CLI, the name of an automatically created registry secret is of the format, `ce-auto-icr-private-<region>`.
* User managed secret - This is a secret that you create and manage. You can [access images from your account with an API key](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#images-your-account-api-key) or use an access token for the container registry of your choice; for example, Docker Hub. For this case, the registry secret that is listed in the console is the name of your registry secret.

If your registry is public and does not require credentials; for example, Code Engine sample images in `icr.io/codeengine` or Docker Hub public, then you do not need a registry secret. For this case, the registry secret that is listed in the console is `None`.


## Setting up authorities for image registries
{: #authorities-registry}

If your registry is public, you do not have to set up authorities to pull images. Note that pulling images from a public registry while you are getting started with Code Engine is acceptable. Use a private registry when it comes to your enterprise workloads.

### What authorities do I need?
{: #authorities-registry-what-auth}

To determine the authorities that you need, consider the following cases:

* When you deploy apps or run jobs, Code Engine can automatically access images that are in your own account.

* If you want to access images from a shared account, other IBM Cloud accounts, or a private Docker account, you must be assigned the proper access authorities.

* When you deploy apps or run jobs and your registry uses an IBM Cloud Container Registry namespace that is in your account, then you can let Code Engine automatically create and manage the registry secret for you, as long as your account has the required permissions as described in the following table.
    - In the console, this registry secret is called a `Code Engine managed secret`. This option is available when you use the **Configure image** or **Specify build details** workflows for building an image with Code Engine.
    - In the CLI, this registry secret is of the format, `ce-auto-icr-private-<region>`. This registry secret is automatically created when you specify the `--build-source` option but you do not provide the `--registry-secret` option with the **`app create`**, **`app update`**, **`job create`**, or **`job update`** commands.


| Action                                            | IAM service access                                                                  | Description                                                                                                                                                                                                                                                              |
| ------------------------------------------------- | ----------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Pull images                                       | `Reader` service access                                                             | When you deploy an image as an application or job, you must pull the image from a registry. To pull images, you need read access. If the registry is public, you already have read access to the images. If the registry is private, then a registry secret is required. |
| Push images                                       | `Reader` and `Writer` service access                                                | When you build source code, you must push the image to a registry. To push images to your registry, you must have read and write access, and you must have a registry secret.                                                                                            |
| Create a namespace                                | `Reader`, `Writer`, and `Manager` service access                                    | This action is only supported for IBM Cloud Container Registry.                                                                                                                                                                                                          |
| Code Engine automatically created registry secret | `Administrator` platform access \n `Reader`, `Writer`, and `Manager` service access | This action is only supported for IBM Cloud Container Registry.                                                                                                                                                                                                          |
{: caption="Access authorities for image registry" caption-side="bottom"}

### Can I use a service ID?
{: #authorities-registry-service-id}

Yes, you can create a service ID and assign authorities to it. Note that service IDs are also automatically created by the Code Engine UI when you automatically create access to your IBM Cloud Container Registry. DO NOT delete this service ID as you will lose access to the images in the registry.

### Can I access images in a different registry?
{: #authorities-registry-access-images}

Yes! [Here is how](#images-different-account).

### Can I restrict pull access to a certain regional registry or even a single namespace?
{: #authorities-registry-pull-access}

Yes, you can edit the existing [IAM policy of the service ID](#authorize-cr-service-id) that restricts the **Reader** service access role to that regional registry or a registry resource such as a namespace. Before you can customize registry IAM policies, you must [enable IBM Cloud IAM policies for IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-user).


## Accessing images from a public account
{: #images-public-account}

If your image is stored in a public repository, such as a public Docker Hub, then you can simply reference the image directly when you deploy your application or run your job. Note that while storing images in a public registry is fine for getting started with applications and jobs, store your enterprise images in a private registry.

## Accessing images in your own account from console
{: #images-your-account}

If you are accessing Code Engine from an account that you own or administer, then Code Engine can automatically push and pull images to and from an IBM Cloud Container Registry namespace in your account when you create or update apps, jobs, or builds from the console. Code Engine can even create a namespace for you when you push an image. For more information, see the following topics.

- [Deploying an app that references an image in IBM Cloud Container Registry with the console](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-crimage#deploy-app-crimage-console).
- [Deploying your app from source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code).
- [Creating a job from images in IBM Cloud Container Registry with the console](https://cloud.ibm.com/docs/codeengine?topic=codeengine-create-job-crimage#create-job-crimage-console).
- [Creating a job from source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-run-job-source-code).

## Accessing images from your account with an API key
{: #images-your-account-api-key}

If you are accessing Code Engine with the CLI, you must first create an IAM API key and then [save the IAM API key as registry access](#add-registry-access-ce) in Code Engine.

The following steps create an API key that stores the credentials of a user ID. Instead of using a user ID, you might want to create an API key for a service ID that has an IBM Cloud IAM service access policy to IBM Cloud Container Registry. If you choose to authenticate a user ID, make sure that the user is a functional ID or plan for cases where the user leaves so that Code Engine can still access the registry.
{: note}

### Creating an API key from the console
{: #access-registry-account-console}

To create an IBM Cloud IAM API key from the console,

1. Launch [Access (IAM) Overview](https://cloud.ibm.com/iam/overview).
2. Select **API keys**.
3. Click **Create an IBM Cloud API key**.
4. Enter a name and optional description for your API key and click **Create**.
5. Copy the API key or click download to save it.

    You won't be able to see this API key again, so be sure to record it in a safe place.
    {: important}

Now that you created your API key, [save it as registry access](#add-registry-access-ce).

### Creating an API key with the CLI
{: #access-registry-account-cli}

To create an IBM Cloud IAM API key with the CLI, run the [**`iam api-key-create`**](https://cloud.ibm.com/docs/account?topic=account-ibmcloud_commands_iam#ibmcloud_iam_api_key_create) command. For example, to create an API key called `cliapikey` with a description of `My CLI API key` and save it to a file called `key_file`, run the following command:

```txt
ibmcloud iam api-key-create cliapikey -d "My CLI API key" --file key_file
```
{: pre}

If you choose to not save your key to a file, you must record the API key that is displayed when you create it. You cannot retrieve it later.
{: important}

Now that you created your API key, [save it as registry access](#add-registry-access-ce).

## Accessing images in a shared account
{: #images-shared-account}

To access images from IBM Cloud Container Registry in a shared account, you must be assigned the [proper authority](#authorities-registry).

If you are planning to deploy apps and run jobs from the shared account, Code Engine can pull or push images for you when you deploy your application or create your job.

If you want to pull images from the shared account to your own account, then you must be [authorized to access IBM Cloud Container Registry](#authorities-registry).

## Accessing images in a different account
{: #images-different-account}

You can assign IBM Cloud IAM access policies to users or a service ID to restrict permissions to specific registry image namespaces or actions (such as push or pull). Then, create an API key and store these registry credentials in Code Engine.
{: shortdesc}

For example, to access images in other IBM Cloud accounts, [create an API key](#images-your-account-api-key) that stores the IBM Cloud Container Registry credentials of a user or service ID in that account. Then, in Code Engine, use that key to [create access](#add-registry-access-ce) in your account.

## Accessing images in a private Docker Hub account
{: #access-private-docker-hub}

To access images in a private Docker Hub account, create registry access by providing your password or an access token. By using an access token, you can more easily grant and revoke access to your Docker Hub account without requiring a password change. For more information about access tokens and Docker Hub, see [Create and manage access tokens](https://docs.docker.com/security/access-tokens/){: external}.

After you decide whether to use your password directly or to create an access token, [create your registry access](#add-registry-access-ce).

## Add registry access to Code Engine
{: #add-registry-access-ce}

To set up access to an IBM Cloud Container Registry in a different IBM Cloud account, to pull images from a private Docker Hub account, or to pull or push images by using the Code Engine CLI, you can use the [IBM API key](#images-your-account-api-key) or [Docker Hub password or access token](#access-private-docker-hub) to create registry access through Code Engine to store your authentication key or token for you.

### Adding registry access from the console
{: #add-registry-access-ce-console}

Before you begin, [create a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project).

1. After your project is in **Active** status, click the name of your project on the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}.
2. From the Components page, click **Secrets and configmaps**.
3. From the Secrets and configmaps page, click **Create** to create your secret.
4. From the Create secret or configmap page, complete the following steps:
    1. Select **Registry secret**, and click **Next**.
    2. Provide a name; for example, `mysecret-registry`.
    3. Specify the target registry for this secret, such as IBM Cloud Container Registry or Docker Hub.
    4. Specify the location of the registry.
    5. Specify a username. If this secret is for IBM Cloud Container Registry, the username is `iamapikey`. If this secret is for Docker Hub, it is your Docker ID.
    6. Enter the credentials for the username. For IBM Cloud Container Registry, use your IAM API key. For Docker Hub, you can use your Docker Hub password or an [access token](#access-private-docker-hub). For other target registries, specify the password or API key for the username.
    7. Click **Create** to create the secret.

Now that your secret is created from the console, go to the Secrets and configmaps page to view a list of defined secrets and configmaps. You can apply filters to customize the list to meet your needs.

You can add access to a container registry when you create an application or job, or when you build an image. Click **Configure image** and specify the container image to run, including the registry where the image is stored and the [registry access](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#types-registryaccesssecrets) to use to retrieve the image.
{: tip}



### Adding registry access with the CLI
{: #add-registry-access-ce-cli}


Beginning with CLI version 1.42.0, defining and working with secrets in the CLI is unified under the **`secret`** command group. See [**`ibmcloud ce secret`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-secret-create) commands. Use the `--format` option to specify the category of secret, such as `basic_auth`, `generic`, `hmac`, `ssh`, `tls`, or `registry`. 
While you can continue to use the **`registry`** command group, take advantage of the unified **`secret`** command group.
To create a secret to access a container registry, use the [**`ibmcloud ce secret create --format registry`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-secret-create) command. To learn more about working with secrets in Code Engine, see [Working with secrets](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secret).
{: important}


To add IBM Cloud Container Registry or Docker Hub access with the CLI, use the **`secret create --format registry`** command. This command requires a name of the registry secret, the URL of the registry server, and the username and password information to access the registry server, and also allows other optional arguments. For a complete listing of options, see the [**`ibmcloud ce secret create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-secret-create) command.
{: shortdesc}

For example, the following command creates registry access to an IBM Cloud Container Registry instance called `myregistry` that is on the `us.icr.io` registry server:

```txt
ibmcloud ce secret create --format registry --name myregistry --server us.icr.io --username iamapikey --password API_KEY
```
{: pre}

Example output

```txt
Creating registry secret 'myregistry'...
OK
```
{: screen}

The following table summarizes the options that are used with the **`secret create --format registry`** command in this example. For more information about the command and its options, see the [**`ibmcloud ce secret create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-secret-create) command.

| Option       | Description                                                                                                                                                                                                                                                                                              |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--name`     | The name of the registry secret. Use a name that is unique within the project. This value is required. \n - The name must begin and end with a lowercase alphanumeric character. \n - The name must be 253 characters or fewer and can contain lowercase letters, numbers, periods (.), and hyphens (-). |
| `--server`   | Enter the URL of the registry server. For Container Registry, the server name is `<region>.icr.io`. For example, `us.icr.io`. For [Docker Hub](https://hub.docker.com/), the value is `https://index.docker.io/v1/`.                                                                                     |
| `--username` | Enter the username to access the registry server. For Container Registry, it is `iamapikey`. For Docker Hub, it is your Docker ID.                                                                                                                                                                       |
| `--password` | Enter the password. For Container Registry, the password is your API key. For Docker Hub, you can use your Docker Hub password or an [access token](#access-private-docker-hub).                                                                                                                         |
{: caption="Command description" caption-side="bottom"}

## Authorizing access to Container Registry with service ID
{: #authorize-cr-service-id}

Before you can add access to a service ID in a different account, you must first authorize access to the service ID.

When you create a service ID, you can restrict access to a regional IBM Cloud Container Registry or even a specific namespace within that IBM Cloud Container Registry account.

### Authorizing access to Container Registry with service ID from the console
{: #authorize-console-service-id}

To pull or push images from or to IBM Cloud Container Registry, you must create a service ID, create an access policy for the service ID, and then create an API key to store the credentials.

#### Step 1 Create or identify a service ID and authorize it to the IBM Cloud Container Registry service
{: #create-service-id}

1. Launch [Access (IAM) Overview](https://cloud.ibm.com/iam/overview){: external}.
2. Select **Service IDs**.
3. If you have a Service ID that you want to use, select it. If not, select **Create**, enter a name and description, and click **Create**.
4. From the Service ID page, from the **Access policies** section, select **Assign access**.
5. From the **Assign service ID additional access** section,
    1. Select **Container Registry** for type of access. Click **Next**.
    2. Select the type of access: **All resources** or **Specific resources**. If you specify **Specific resources**, you can add attributes based on resource group, geography, region, resource type, resource ID, or resource name to further restrict access. If you select a certain resource group, make sure to select **Viewer** access for **Resource group** access. Click **Next**.
    3. In the **Roles and Actions** section, select the type of access you want to grant. If you plan to use only images for your applications and jobs, select **Reader**. If you want to push the source code and images to Container Registry, then also select **Writer**. Click **Review**.
    4. Click **Add** and then **Assign**.

#### Step 2 Enabling Container Registry discovery
{: #registry-discovery}

To allow the Code Engine console to automatically discover Container registry, you must authenticate the service ID to the IAM Identity Service.


1. From the Service ID page, from the **Access policies** section, select **Assign access**.
2. From the **Assign service ID additional access** section,
    1. Select **IAM Identity Service** for type of access. Click **Next**.
    2. Select **Specific resources** for resource scope. Select **Resource type** as attribute type, keep **string equals** as operator and enter `serviceid` as value. Click **Add a condition**.
    3. Select **Resource ID** as attribute type, keep **string equals** as operator and put the identifier of your service ID. You can find your service ID on the **Details** page for the service ID or in the browser URL when configuring it. Click **Next**.
    4. In the **Roles and Actions** section, select Platform **Operator** access. Click **Review**
    5. Click **Add** and then **Assign**.

#### Step 3 Creating an API key for a service ID
{: #create-api-key}

Create an API key for a service ID.

1. From the Service ID page, select **API keys** and then **Create**.
2. Enter a name and optional description for your API key and click **Create**.
3. Copy the API key or click download to save it.

    You won't be able to see this API key again, so be sure to record it in a safe place.
    {: important}

Now that you have your access policies in place for your service ID and your API key created, you can [add access to Code Engine](#add-registry-access-ce) to pull images from your container registry.

### Authorizing access to Container Registry with the CLI
{: #authorize-cr-cli}

To pull images from IBM Cloud Container Registry in a different account, you must create a service ID, create access policies for the service ID, and then create an API key to store your credentials.
{: shortdesc}

1. Create an IBM Cloud IAM service ID for your project that is used for the IAM policies and API key credentials in the image pull secret with the **`iam service-id-create`** command. Be sure to give the service ID a description that helps you retrieve the service ID later, such as including the project name. For a complete listing of the **`iam service-id-create`** command and its options, see the [**`ibmcloud iam service-id-create`**](https://cloud.ibm.com/docs/account?topic=account-ibmcloud_commands_iam#ibmcloud_iam_service_id_create) command.

    For example, the following command creates a service ID called `codeengine-myproject-id` with the description `Service ID for IBM Cloud Container Registry in Code Engine project myproject`:

    ```txt
    ibmcloud iam service-id-create codeengine-myproject-id --description "Service ID for IBM Cloud Container Registry in Code Engine project my proj"
    ```
    {: pre}

2. Create a custom IBM Cloud IAM policy for your service ID that grants access to IBM Cloud Container Registry with the **`iam service-policy-create`** command. For a complete listing of the **`iam service-policy-create`** command and its options, see the [**`ibmcloud iam service-policy-create`**](https://cloud.ibm.com/docs/account?topic=account-ibmcloud_commands_iam#ibmcloud_iam_service_policy_create) command.

    For example, the following command creates a policy for `codeengine-myproject-id` service ID with the role of `Reader`:

    ```txt
    ibmcloud iam service-policy-create codeengine-myproject-id --roles Reader --service-name container-registry
    ```
    {: pre}

    The following table summarizes the options that are used with the **`iam service-policy-create`** command in this example. For more information about the command and its options, see the [**`ibmcloud iam service-policy-create`**](https://cloud.ibm.com/docs/account?topic=account-ibmcloud_commands_iam#ibmcloud_iam_service_policy_create) command.

    | Option                                | Description                                                                                                                                                                                                                                                                                                                                                                                                                    |
    | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
    | `<service_ID>`                        | Required. Replace with the `codeengine-<project_name>-id` service ID that you previously created.                                                                                                                                                                                                                                                                                                                              |
    | `--roles <service_access_role>`       | Required. Enter the [service access role for IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-iam#service_access_roles) that you want to scope the service ID access to. Possible values are `Reader`, `Writer`, and `Manager`. If you are pulling images, then `Reader` access is sufficient. For more information, see [Setting up authorities for image registries](#authorities-registry). |
    | `--service-name <container-registry>` | Required. Enter `container-registry` to create an IAM policy for IBM Cloud Container Registry.                                                                                                                                                                                                                                                                                                                                 |
    {: caption="iam service-policy-create command components" caption-side="bottom"}


3. Create a custom service policy to allow access to `iam-identity` service so that Code Engine can retrieve the API key for your service ID with the **`iam service-policy-create`** command.

    For example, create a policy for `codeengine-myproject-id` service ID with the role of `Operator`:

    ```txt
    ibmcloud iam service-policy-create codeengine-myproject-id --roles Operator --service-name iam-identity
    ```
    {: pre}

    The following table summarizes the options that are used with the **`iam service-policy-create`** command in this example. For more information about the command and its options, see the [**`ibmcloud iam service-policy-create`**](https://cloud.ibm.com/docs/account?topic=account-ibmcloud_commands_iam#ibmcloud_iam_service_policy_create) command.

    | Option                           | Description                                                                                                                                                                                                       |
    | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | `<service_ID>`                   | Required. Replace with the `codeengine-<project_name>-id` service ID that you previously created.                                                                                                                 |
    | `--roles <platform_access_role>` | Required. Enter the platform access role that you want to scope the service ID access to. Possible values are `Administrator`, `Editor`, `Operator`, and `Viewer`. Your service ID requires `Operator` or higher. |
    | `--service-name <iam-identity>`  | Required. Enter `iam-identity` to create an IAM policy for IAM identify services.                                                                                                                                 |
    {: caption="iam service-policy-create command components" caption-side="bottom"}


4. Create an API key for the service ID with the **`iam service-api-key-create`** command. For a complete listing of the **`iam service-api-key-create`** command and its options, see the [**`ibmcloud iam service-api-key-create`**](https://cloud.ibm.com/docs/account?topic=account-ibmcloud_commands_iam#ibmcloud_iam_service_api_key_create) command. Name the API key similar to your service ID, and include the service ID that you previously created, `codeengine-<project_name>-id`. Be sure to give the API key a description that helps you retrieve the key later.

    For example, the following command creates a key that is called `codeengine-myproject-key` for the `codeengine-myproject-id` service ID with a description of `API key for service ID codeengine-myproject-id for Code Engine myproject`:

    ```txt
    ibmcloud iam service-api-key-create codeengine-myproject-key codeengine-myproject-id --description "API key for service ID codeengine-myproject-id for Code Engine myproject"
    ```
    {: pre}

    Example output

    ```txt
    Please preserve the API key! It cannot be retrieved after it's created.

    Name          codeengine-myproject-key
    Description   API key for service ID codeengine-myproject-id for Code Engine myproject
    Bound To      crn:v1:bluemix:public:iam-identity::a/1bb222bb2b33333ddd3d3333ee4ee444::serviceid:ServiceId-ff55555f-5fff-6666-g6g6-777777h7h7hh
    Created At    2019-02-01T19:06+0000
    API Key       i-8i88ii8jjjj9jjj99kkkkkkkkk_k9-llllll11mmm1
    Locked        false
    UUID          ApiKey-222nn2n2-o3o3-3o3o-4p44-oo444o44o4o4
    ```
    {: screen}

    You won't be able to see this API key again, so be sure to record it in a safe place.
    {: important}

    Now that you have your access policies in place for your service ID and your API key that is created, you can [add access to Code Engine](#add-registry-access-ce) to pull images from your container registry.



## Controlling access to Container Registry for Code Engine workloads
{: #control-cr-access}

Suppose that you want to control access to IBM Cloud Container Registry when Code Engine pulls images. For example, you want to control access to Container Registry to specific IP addresses. Consider the following approaches.

* Use a [context-based restriction](https://cloud.ibm.com/docs/Registry?topic=Registry-registry-cbr). By using a context-based restriction, if the IP addresses for your Code Engine project ever change, you do not need to change your access. You can restrict access to Container Registry to a network zone, where your network zone includes Code Engine and anything that requires access to the registry.

* Disable the public access to IBM Cloud Container Registry and make sure Code Engine uses the private endpoints instead of the public endpoints. See [Securing your connection to Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-registry-cbr).

* To control access by a specific IP range, use an API endpoint to fetch the IP addresses for your particular Code Engine project. It is important to note that these IP addresses are subject to change, and you must take appropriate steps when this happens. See [Code Engine public and private IP addresses](https://cloud.ibm.com/docs/codeengine?topic=codeengine-network-addresses) and [How can I add my Code Engine app to an allowlist](https://cloud.ibm.com/docs/codeengine?topic=codeengine-ts-allowlist-app)?



## Considerations for images in your registry
{: #considerations-registry}

The name of your image that is used for your app or job must be in one of the following formats.

- `REGISTRY/NAMESPACEorDOCKERUSERorDOCKERORG/REPOSITORY:TAG` where `REGISTRY` and `TAG` are optional. If `REGISTRY` is not specified, the default is `docker.io`. If `TAG` is not specified, do not include the colon (:). The default for `TAG` is `latest`.
- `REGISTRY/NAMESPACEorDOCKERUSERorDOCKERORG/REPOSITORY@IMAGEID` where `REGISTRY` is optional. If `REGISTRY` is not specified, the default is `docker.io` and `ibm` as the Docker organization.

| Component               | Characters allowed      | Length | Additional rules                         |
| ----------------------- | ----------------------- | ------ | ---------------------------------------- |
| `REGISTRY`              | `a-zA-Z0-9 -_.  --__`   | 1-253  | `(0-127Periods)(label:1-63,noDashOnEnd)` |
| `NAMESPACE`             | `a-z   0-9 -_   --__`   | 4-30   | `(start/end with letterOrNumber)`        |
| `DOCKERUSERorDOCKERORG` | `a-z   0-9`             | 4-30   |                                          |
| `REPOSITORY`            | `a-z   0-9 -_. /`       | 2-255  | `(start/end with letterOrNumber)`        |
| `TAG`                   | `a-zA-Z0-9 -_.  --__..` | 0-128  | `(NOT start with periodOrDash)`          |
| `IMAGEID`               | `a-z   0-9    :`        |        | `(startwith sha256: noOtherColon)`       |
{: caption="Rules for image name" caption-side="bottom"}

The parts of the image name must meet the following criteria.

- `REGISTRY` must be 253 characters or fewer and can contain lowercase or uppercase letters, numbers, periods (.), hyphens (-), and underscores (`_`). Do not use a dash (.) as the last character. Do not use more than 127 periods (.) and the labels between them can be between 1 and 63 characters long.
- `NAMESPACE` must be between 4 and 30 characters and must begin and end with a lowercase letter or number. `NAMESPACE` can contain lowercase alphanumeric characters, hyphens (-), and underscores (`_`).
- `DOCKERUSERorDOCKERORG` can be used for Docker registries instead of `NAMESPACE`. Specify your Docker username or Docker organization. Your Docker username and organization must be between 4 and 30 characters and contains only lowercase alphanumeric characters or numbers.
- `REPOSITORY` must be between 2 and 255 characters and must begin and end with a lowercase letter or number. `REPOSITORY` can contain lowercase alphanumeric characters, forward slashes (/), periods (.), hyphens (-), and underscores (`_`).
- `TAG` must be between 0 and 128 characters and can contain lowercase or uppercase letters, numbers, periods (.), hyphens (-), and underscores (`_`). The `TAG` must not begin with a period or dash. If you do not include a `TAG`, do not include the colon either.
- `IMAGEID` is prefixed with `sha256:` and can contain lowercase letters and numbers.

================================

---
name: codeengine-plan-repo
title: Accessing private code repositories
description: A code repository, such as GitHub or GitLab, stores source code. With Code Engine, you can add access to a private code repository and then reference that repository from your build.
last-updated: 2026-03-05
---

# Accessing private code repositories
{: #code-repositories}

A code repository, such as GitHub or GitLab, stores source code. With Code Engine, you can add access to a private code repository and then reference that repository from your build.
{: shortdesc}

After you create access to your private code repository, you can pull code from repo, build it, and deploy an app or job with IBM Cloud&reg; Code Engine. 

## Create code repository access
{: #create-code-repo}

When you create access to a private code repository, you are saving credentials in Code Engine. These credentials are called *SSH secrets*.

Before you begin

- [Set up your Code Engine CLI environment](https://cloud.ibm.com/docs/codeengine?topic=codeengine-install-cli).
- [Create and work with a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project).
- [Choose an SSH key to use](#choose-ssh-key).

### Choosing an SSH key for code repository
{: #choose-ssh-key}

For both GitHub and GitLab, you can decide between two kinds of SSH keys to connect to your source repository.

1. An SSH key associated with the source code repository, this key has access to only those repositories where you register the SSH key. This access is read only, by default, which is the level that is required by Code Engine to download the source code. You can select write access, if needed. Consider choosing this option to set an SSH key that is scoped to specific repositories to control access to only the specified repositories.  
    - [GitHub - Deploy keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys){: external}
    - [GitLab - Deploy keys](https://docs.gitlab.com/user/project/deploy_keys/){: external}

2. An SSH key associated with a user, for example, your own user account or a functional ID that is available in your organization. This SSH key has the repository permissions from the user account. Code Engine requires read access to download the source code.

    Because setting an SSH key that is scoped to a user account provides access to the full account, it is important to be aware of security implications when you choose this option.
    {: important}

    - [Adding an SSH key to your GitHub account](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/adding-a-new-ssh-key-to-your-github-account){: external}.
    - [Add an SSH key to your GitLab account](https://docs.gitlab.com/user/ssh/#add-an-ssh-key-to-your-gitlab-account){: external}.

Do not create your SSH key file with a secure passphrase as this action causes your `build` command to fail.
{: tip}

### Adding private repository access from the console
{: #add-repo-access-ce-console}

Before you begin, [create a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project).

1. After your project is in **Active** status, click the name of your project on the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}. 
2. From the Components page, click **Secrets and configmaps**.
3. From the Secrets and configmaps page, click **Create** to create your secret.
4. From the Create secret or configmap page, complete the following steps:
    1. Select **SSH secret**, and click **Next**.
    2. Provide a name; for example, `mysecret-ssh`.
    3. Add the SSH private key for this secret. 
    4. Click **Create** to create the secret. 

Now that your secret is created from the console, go to the Secrets and configmaps page to view a list of defined secrets and configmaps. You can apply filters to customize the list to meet your needs. 

You can create access when you build an image.
{: tip}

### Adding private repository access with the CLI
{: #create-code-repo-console}

Beginning with CLI version 1.42.0, defining and working with secrets in the CLI is unified under the **`secret`** command group. See [**`ibmcloud ce secret`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-secret-create) commands. Use the `--format` option to specify the category of secret, such as `basic_auth`, `generic`, `hmac`, `ssh`, `tls`, or `registry`. While you can continue to use the **`repo`** command group, take advantage of the unified **`secret`** command group. To create a secret to access a service with an SSH key, such as to authenticate to a Git repository like GitHub or GitLab, use the [**`ibmcloud ce secret create --format ssh`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-secret-create) command. An SSH secret is also used as a Git repository access secret. To learn more about working with secrets in Code Engine, see [Working with secrets](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secret).
{: important}


An SSH secret contains the credentials to access the private repository that contains the source code to build your container image. An SSH secret is also used as a Git repository access secret.

To create an SSH secret with the CLI, use the **`secret create --format ssh`** command. This command requires a name and a key path, and also allows other optional arguments such as the path to the known hosts file. For a complete listing of options, see the [**`ibmcloud ce secret create --format ssh`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-secret-create) command. 

For example, the following command creates an SSH secret that is called `myrepossh` to a repository at `github.com` that uses your personal SSH private key that is found at the default location on your system.

Mac OS or Linux&reg;

```txt
ibmcloud ce secret create --format ssh --name myrepossh --key-path $HOME/.ssh/id_rsa --known-hosts-path $HOME/.ssh/known_hosts
```
{: pre}

Windows

```txt
ibmcloud ce secret create --format ssh --name myrepossh --key-path "%HOMEPATH%\.ssh\id_rsa" --known-hosts-path "%HOMEPATH%\.ssh\known_hosts"
```
{: pre}

The following table summarizes the options that are used with the **`repo create`** command in this example. For more information about the command and its options, see the [**`ibmcloud ce repo create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-repo-create) command.


| Option               | Description                                                                                                                                                                                                                                                                                                                                |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `--name`             | The name of the SSH secret. Use a name that is unique within the project. This value is required.  \n - The name must begin and end with a lowercase alphanumeric character.  \n - The name must be 253 characters or fewer and can contain lowercase letters, numbers, periods (.), and hyphens (-).                                      |
| `--key-path`         | The local path to the unencrypted private SSH key. If you use your personal private SSH key, then this file is usually at `$HOME/.ssh/id_rsa` (Mac OS or Linux) or at `%HOMEPATH%\.ssh\id_rsa`(Windows). This value is required.                                                                                                           |
| `--known-hosts-path` | The path to your known hosts file. This value is a security feature to ensure that the private key is only used to authenticate at hosts that you previously accessed, specifically, the GitHub or GitLab hosts. This file is usually located at `$HOME/.ssh/known_hosts` (Mac OS or Linux) or at `%HOMEPATH%\.ssh\known_hosts` (Windows). |
{: caption="Command description" caption-side="bottom"}


## Referencing a private Git repository in a build
{: #referencing-coderepo-build}

You can reference existing access or create access when you build an image from the console.

### Referencing a private Git repository in a build from the console
{: #referencing-coderepo-build-ui}

To reference your private Git repository in a build,

1. Go to the [Code Engine dashboard](https://cloud.ibm.com/codeengine/overview).
2. Select a project (or [create one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project)).
3. From the project page, click **Image builds**.
4. From the **Image build** tab, click **Create**.
5. To specify a private repository and add access, enter the URL to the repository in the **Code repo URL** field and then select either your existing code repo access or to [create access](#add-repo-access-ce-console).
6. Finish specifying information for your build and click **Done**.

For more information about building images, see [Building a container image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build).

The code repo URL must be an SSH URL such as `git@github.com:IBM/CodeEngine.git` instead of an HTTPS URL such as `https://github.com/IBM/CodeEngine.git`.
{: note}



### Referencing an SSH secret in a build with the CLI
{: #referencing-coderepo}

To use an SSH secret in a build, use the `--git-repo-secret` option when you run the **`build create`** or the **`build update`** command. An SSH secret is also used as a Git repository access secret. 

If you have an existing build, then you can update it by using the [**`build update`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-build-update) command,

```txt
ibmcloud ce build update --name mybuild --git-repo-secret myrepossh
```
{: pre}

If you want to create a new build, then see [Creating a build configuration with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-build-create-config1#build-create-cli).

## Next steps for Git repository access 
{: #nextsteps-coderepo}

After you create your SSH secret to access a Git repository, you can [build images](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) from source code in your private repository. Specify your SSH secret when you run the **`build create`** command with the `--git-repo-secret` option.

================================