---
name: codeengine-getting-started
title: Getting started with IBM Cloud Code Engine
description: IBM Cloud&reg; Code Engine is a fully managed, serverless platform that runs your containerized workloads, including web apps, micro-services, event-driven functions, or batch jobs. Code Engine even builds container images for you from your source code. All these workloads can seamlessly work together because they are all hosted within the same Kubernetes infrastructure. The Code Engine experience is designed so that you can focus on writing code and not on the infrastructure that is needed to host it.
last-updated: 2026-01-27
---

# Getting started with IBM Cloud Code Engine

{: #getting-started}

IBM Cloud&reg; Code Engine is a fully managed, serverless platform that runs your containerized workloads, including web apps, micro-services, event-driven functions, or batch jobs. Code Engine even builds container images for you from your source code. All these workloads can seamlessly work together because they are all hosted within the same Kubernetes infrastructure. The Code Engine experience is designed so that you can focus on writing code and not on the infrastructure that is needed to host it.
{: shortdesc}

First, learn about some [key terms](#term-summary) for Code Engine and then get started with one of the following options.

- [Deploy an application](#app-hello)
- [Create and run a job](#first-job)
- [Run function code](#first-function)
- [Building your first container image from source code](#build-image-gs)
- [Run a fleet](#first-fleet)

## What are Code Engine projects, applications, jobs, functions and fleets?

{: #term-summary}

Before you get started, become familiar with some key terms for Code Engine.

| Term        | Description                                                                                                                                                                                                                                                                                                                                                                                                     |
| ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Project     | A project is a grouping of Code Engine entities such as applications, jobs, and builds. Projects are used to manage resources and provide access to its entities.                                                                                                                                                                                                                                               |
| Application | An application, or app, runs your code to serve HTTP requests. An application has a URL for incoming requests. The number of running instances of an application are automatically scaled up or down (to zero) based on incoming workload.                                                                                                                                                                      |
| Build       | A build, or image build, is a mechanism that you can use to create a container image from your source code. Code Engine supports building from a Dockerfile or Cloud Native Buildpacks.                                                                                                                                                                                                                         |
| Function    | A function is a stateless code snippet that performs tasks in response to an HTTP request.                                                                                                                                                                                                                                                                                                                      |
| Job         | A job runs one or more instances of your executable code in parallel. Unlike applications, which include an HTTP Server to handle incoming requests, jobs are designed to run one time and exit.                                                                                                                                                                                                                |
| Fleet       | A fleet, also called a *serverless fleet* runs one or more instances of user code to complete a series of specified tasks. Fleets are designed to tackle large, compute-heavy work loads. Unlike jobs, fleets are single tenant, implement dynamic task queuing, and provide full control over the machine profile configuration. For more information, see [What is the difference between jobs and fleets?]() |
{: caption="Code Engine Terms" caption-side="bottom"}

For more information about terms, see [Code Engine terminology](https://cloud.ibm.com/docs/codeengine?topic=codeengine-about#terminology).

Not sure what to choose? See [Planning for Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-codeengine).
{: tip}

## How do apps, jobs, functions, and fleets compare?

{: #ce-comp}

| Characteristic            | Application                                                   | Job                                                       | Function                                                    | Fleet                                             |
| ------------------------- | ------------------------------------------------------------- | --------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------- |
| Execution time (duration) | Long-running (10 minutes per request)                         | Long-running (up to 24 hours)                             | Short-running (2 minutes or less)                           | Long-running (minutes to weeks)                   |
| Startup latency           | Medium                                                        | Scheduled start                                           | Low                                                         | Low                                               |
| Termination               | Run-continuously                                              | Run-to-completion                                         | Run-to-completion                                           | Run-to-completion                                 |
| Invocation                | On request or permanently running                             | Scheduled                                                 | On request, instant                                         | Scheduled                                         |
| Programming Model         | Container-based build and execution                           | Container-based build and execution                       | Language-specific source code files and dependency metadata | Container-based build and execution               |
| Parallelism               | Parallel execution, flexible                                  | Low to medium parallel execution                          | High parallel execution                                     | High parallel execution and queuing               |
| Scale-out                 | Based on number of requests                                   | Based on job workload definition                          | Based on events or direct invocations                       | Based on number of tasks and concurrent instances |
| Optimized for             | Long running, highly complex workload and on-demand scale-out | Scheduled or planned workloads with high resource demands | Startup time and rapid scale-out                            | Large, compute-intensive work loads               |
{: caption="Comparing Code Engine applications, jobs, and functions" caption-side="bottom"}

For more information, see [Planning for Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-codeengine).

## Deploying your first Code Engine app

{: #app-hello}

Create your first Code Engine app by using the `icr.io/codeengine/helloworld` image.
{: shortdesc}

1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
2. Select **Start creating**.
3. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). Note that you must have a selected project to deploy an app.
4. Select **Application**.
5. Enter a name for the application, for example, `myapp`. Use a name for your application that is unique within the project.
6. Select to run a **Container image** and specify `icr.io/codeengine/helloworld` for the image reference. For this example, you do not need to modify the default values. For more information about the code that is used for this example, see [`helloworld`](https://github.com/IBM/CodeEngine/tree/main/helloworld){: external}.
7. Click **Create**.
8. After the application status changes to **Ready**, you can test the application. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**.

Example output

```txt
Hello World from:
. ___  __  ____  ____
./ __)/  \(    \(  __)
( (__(  O )) D ( ) _)
.\___)\__/(____/(____)
.____  __ _   ___  __  __ _  ____
(  __)(  ( \ / __)(  )(  ( \(  __)
.) _) /    /( (_ \ )( /    / ) _)
(____)\_)__) \___/(__)\_)__)(____)

Some Env Vars:
--------------
CE_API_BASE_URL=https://api.private.us-south.codeengine.cloud.ibm.com
CE_APP=myapp
CE_DOMAIN=us-south.codeengine.appdomain.cloud
CE_PROJECT_ID=abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f
CE_REGION=us-south
CE_SUBDOMAIN=abcdabcdab
HOME=/root
HOSTNAME=myapp-00001-deployment-5b5895fdf7-abcd
K_REVISION=myapp-00001
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PORT=8080
PWD=/
SHLVL=1
z=Set env var 'SHOW' to see all variables
```

{: screen}

You deployed your first application to Code Engine and tested it out. Go to the [Tutorial: Deploying applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-tutorial) or [Working with apps in Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads) to try out more options for applications.

## Running your first Code Engine job

{: #first-job}

Create and run your first Code Engine job by using the `icr.io/codeengine/helloworld` image.
{: shortdesc}

1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
2. Select **Start creating**.
3. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). Note that you must have a selected project to create a job.
4. Select **Job**.
5. Enter a name for the job, for example, `myjob`. Use a name for your job that is unique within the project.
6. Specify `icr.io/codeengine/helloworld` for the image reference. For this example, you do not need to modify the default values. For more information about the code that is used for this example, see [`helloworld`](https://github.com/IBM/CodeEngine/tree/main/hello){: external}.
7. Click **Create**.
8. From your job page, click **Submit job** to submit a job based on the current configuration.
9. From the Submit job pane, accept all the default values, and click **Submit job** again to run your job.

When logging is enabled, the following example is displayed in the logs. To learn about running jobs with logging enabled, see [Viewing logs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-logging).
{: tip}

Example output from logging instance

```txt
Hello World from:
. ___  __  ____  ____
./ __)/  \(    \(  __)
( (__(  O )) D ( ) _)
.\___)\__/(____/(____)
.____  __ _   ___  __  __ _  ____
(  __)(  ( \ / __)(  )(  ( \(  __)
.) _) /    /( (_ \ )( /    / ) _)
(____)\_)__) \___/(__)\_)__)(____)

Some Env Vars:
--------------
CE_DOMAIN=us-east.codeengine.appdomain.cloud
CE_JOB=myjob
CE_JOBRUN=myjob-jobrun-xgpmz
CE_SUBDOMAIN=abcdabcdab
HOME=/root
HOSTNAME=myjob-jobrun-abcde-0-0
JOB_INDEX=0
...
z=Set env var 'SHOW' to see all variables
```

{: screen}

You created and ran your job from the console. Go to the [Tutorial: Running jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-run-job-tutorial) or [Running jobs in Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-job-plan) to try out more options for jobs.

## Running your first function

{: #first-function}

Create and run your first Code Engine function with sample function code.
{: shortdesc}

1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
2. Select **Start creating**.
3. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). Note that you must have a selected project to create a function.
4. Select **Function**.
5. Enter a name for the function. Use a name for your function that is unique within the project.
6. Select **Node.js 20**
7. Click **Create**. Your function is created with sample code. You can edit this code on the **Function -> Configuration** page.
8. Click **Test function** and then click **Send request** in the Test function pane. To open the function in a web page, click **Function URL**.

Example output

```txt
{
  "args": {
    "__ce_headers": {
      "Accept-Encoding": "gzip, deflate, br",
      "User-Agent": "got (https://github.com/sindresorhus/got)",
      "X-Request-Id": "12340a7b-11c0-4de3-f16b-a6abc27f4146"
    },
    "__ce_method": "GET",
    "__ce_path": "/"
  },
  "env": {
    "HOME": "/root",
    "PATH": "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/lib/nodejs/bin",
    "PWD": "/nodejsAction",
    "SHLVL": "1",
    "_": "/usr/local/lib/nodejs/bin/node",
    "__OW_ALLOW_CONCURRENT": "true",
    "container": "oci"
  }
}
```

{: screen}

You deployed your first function to Code Engine and tested it out. Go to the [Running a function from local source](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-tutorial) or [Working with functions](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-work) to try out more options for functions.

You can [migrate your IBM Cloud Functions to Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-migrate).
{: tip}

## Running your first fleet

{: #first-fleet}

Create and run your first Code Engine fleet by using the `icr.io/codeengine/helloworld` image.

1. Make sure you have completed the [required preparation steps](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fleet-prep) to run a fleet.
1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
1. Select **Start creating**.
1. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). Note that you must have a selected project to run a fleet.
1. Select **Fleet**.
1. Enter a name for the fleet. Use a name that is unique across all fleets within the project.
1. Specify `icr.io/codeengine/helloworld` for the image reference. For this example, you do not need to modify the default values. For more information about the code that is used for this example, see [`helloworld`](https://github.com/IBM/CodeEngine/tree/main/hello){: external}.
1. Click create.

When logging is enabled, the following example is displayed in the logs. To learn about running fleets with logging enabled, see [Viewing fleet logs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fleet-observability-view#log-view).
{: tip}

Example output from logging instance

```txt
Hello from helloworld! I'm a task of fleet: fleet-abcdef1234! Task Index: 4, Task ID: 2b2b2b2b-3c3c-4d4d-5e5e-6f6f6f6f6f6f

Hello World from:
. ___  __  ____  ____
./ __)/  \(    \(  __)
( (__(  O )) D ( ) _)
.\___)\__/(____/(____)
.____  __ _   ___  __  __ _  ____
(  __)(  ( \ / __)(  )(  ( \(  __)
.) _) /    /( (_ \ )( /    / ) _)
(____)\_)__) \___/(__)\_)__)(____)

Some Env Vars:
--------------
CE_API_BASE_URL=https://api.private.eu-de.codeengine.cloud.ibm.com
CE_CPU=1
CE_DOMAIN=eu-de.codeengine.appdomain.cloud
CE_FLEET_ID=1a1a1a1a-2b2b-3c3c-4d4d-5e5e5e5e5e5e
CE_FLEET_NAME=fleet-abcdef1234
...
z=Set env var 'SHOW' to see all variables
```

{: screen}

You created and ran your fleet from the console. Go to the [Running a fleet](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fleet-run) to try out more options for fleets.

## Building your first container image from source code

{: #build-image-gs}

Create and run your first Code Engine build and then deploy the container image in an application.
{: shortdesc}

Code Engine can automatically push images to a Container Registry namespace in your account. It can even create a namespace for you. To push images to a different Container Registry account or to a private Docker Hub account, see [Adding access to a private container registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry).

1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
2. Select **Start creating**.
3. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). Note that you must have a selected project to deploy an app.
4. Select **Application**.
5. Enter a name for the application. Use a name for your application that is unique within the project.
6. Select to run a **Container image** and specify `icr.io/codeengine/helloworld` for the image reference. For this example, you do not need to modify the default values. For more information about the code that is used for this example, see [`helloworld`](https://github.com/IBM/CodeEngine/tree/main/helloworld){: external}.
7. Select **Source code**.
8. Click **Specify build details**.
9. Accept the default for each page, clicking **Next** and then **Done**.
10. Click **Create**.

After your build run is submitted, the built container image is sent to Container Registry and then your application pulls the image and deploys for you. After the application status changes to **Ready**, you can try it out. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**.

Example output

```txt
Hello World from:
     ___  __  ____  ____
    / __)/  \(    \(  __)
   ( (__(  O )) D ( ) _)
    \___)\__/(____/(____)
 ____  __ _   ___  __  __ _  ____
(  __)(  ( \ / __)(  )(  ( \(  __)
 ) _) /    /( (_ \ )( /    / ) _)
(____)\_)__) \___/(__)\_)__)(____)
Some Env Vars:
--------------
CE_API_BASE_URL=https://api.private.us-south.codeengine.cloud.ibm.com
CE_APP=myapp
CE_DOMAIN=us-south.codeengine.appdomain.cloud
CE_PROJECT_ID=abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f
CE_REGION=us-south
CE_SUBDOMAIN=abcdabcdab
HOME=/root
HOSTNAME=myapp-00001-deployment-6db6d89dc7-k6qc7
K_REVISION=myapp-00001
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
PORT=8080
PWD=/
SHLVL=1
```

{: screen}

You submitted source code to Code Engine and created a container image that you then deployed in an application - all from one interface.

Go to [Building a container image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) to explore and try out more options for builds.

## Next steps for Code Engine

{: #nextsteps-getstart}

Learn more about performing these Code Engine tasks from the console or with the [Code Engine CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-install-cli).

- [Managing projects](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project)
- [Deploying applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads)
- [Running jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-job-plan)
- [Running functions](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-work)
- [Building container images](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build)

Looking for more code examples? Check out the [Samples for IBM Cloud Code Engine GitHub repo](https://github.com/IBM/CodeEngine){: external}.
{: tip}

---

---

name: codeengine-about
title: Learn about Code Engine
description: 'IBM Cloud&reg; Code Engine (or "Code Engine") was developed by IBM with the goal of helping you create modern, source-centric, containerized, and serverless apps and jobs. The platform is designed to address the needs of developers who just want their code to run. Code Engine abstracts the operational burden of building, deploying, and managing workloads in Kubernetes so that developers can focus on what matters most to them: the source code.'
last-updated: 2026-01-23
---

# Learn about Code Engine

{: #about}

IBM Cloud&reg; Code Engine (or "Code Engine") was developed by IBM with the goal of helping you create modern, source-centric, containerized, and serverless apps and jobs. The platform is designed to address the needs of developers who just want their code to run. Code Engine abstracts the operational burden of building, deploying, and managing workloads in Kubernetes so that developers can focus on what matters most to them: the source code.
{: shortdesc}
{: #about-par}

## Benefits of Code Engine

{: #benefits}

Review the capabilities that Code Engine provides to run your workloads.

| Capability                | Description                                                                                                                                                                                                                                                                                                                                                                                                        |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Runs your workloads       | Code Engine runs your HTTP-driven applications and your run-to-completion batch jobs.                                                                                                                                                                                                                                                                                                                              |
| Fully managed service     | Code Engine takes care of all the cluster management, including provisioning, configuring, scaling, and managing servers so you do not need to worry about the underlying infrastructure.                                                                                                                                                                                                                          |
| Builds your code          | Code Engine pulls your source code and creates the container image for you. Code Engine supports both Dockerfile and Cloud Native Buildpack.                                                                                                                                                                                                                                                                       |
| Private workloads         | Store your source code in private repositories and push your images to private registries and Code Engine can access them.                                                                                                                                                                                                                                                                                         |
| Fully integrated          | Code Engine is fully integrated into IBM Cloud so that you can take advantage of the full catalog of IBM Cloud services.                                                                                                                                                                                                                                                                                           |
| Event-driven workloads    | Extend the functionality of your applications with messages (events) from event producers. Your application can then react to those events and perform actions based on them.                                                                                                                                                                                                                                      |
| Autoscales - even to zero | Code Engine automatically scales your workloads up and down, and even down to zero when no requests are active. You pay for only the resources that you consume.                                                                                                                                                                                                                                                   |
| Control access            | Assign platform and services access permissions to your projects in IBM Cloud Identity and Access Management to control who can provision and manage resources in your IBM Cloud account.                                                                                                                                                                                                                          |
| Based on open source      | Code Engine is built on a set of open source technologies such as Kubernetes, Knative, Istio, and Tekton, keeping your apps and jobs portable.                                                                                                                                                                                                                                                                     |
| DDoS protection           | Code Engine provides immediate DDoS protection for your application. Code Engine's DDoS protection is provided by Cloud Internet Services (CIS) at no additional cost to you. DDoS protection covers System Interconnection (OSI) Layer 3 and Layer 4 (TCP/IP) protocol attacks, but not Layer 7 (HTTP) attacks. See [DDoS protection](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secure#secure-ddos). |
{: caption="Code Engine benefits" caption-side="bottom"}
{: #benefits-table}

## Code Engine terminology

{: #terminology}

Learn the basics about Code Engine by reviewing the following key terms.

| Term                     | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Application              | An application, or app, runs your code to serve HTTP requests. In addition to traditional HTTP requests, IBM Cloud&reg; Code Engine also supports applications that use WebSockets as their communications protocol. The number of running instances of an app are automatically scaled up or down (to zero) based on incoming requests and your configuration settings. An app contains one or more revisions. A revision represents an immutable version of the configuration properties of the app. Each update of an app configuration property creates a new revision of the app.                                                                         |
| Build                    | A build, or image build, is a mechanism that you can use to create a container image from your source code. Code Engine supports building from a Dockerfile and Cloud Native Buildpacks.                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Code bundle              | A code bundle is a collection of files that represents your function code. This code bundle is injected into the runtime container. Your code bundle is created by Code Engine and is stored in container registry or inline with the function. A code bundle is not a Open Container Initiative (OCI) standard container image.                                                                                                                                                                                                                                                                                                                               |
| Code repository          | A code repository, such as GitHub or GitLab, stores source code. With Code Engine, you can add access to a private code repository and then reference that repository from your build.                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| Configmap                | A configmap provides a method to include non-sensitive data information to your deployment. By referencing values from your configmap as environment variables, you can decouple specific information from your deployment and keep your app, job, or function portable. A configmap contains information in key-value pairs.                                                                                                                                                                                                                                                                                                                                  |
| Container image registry | A container registry, or registry, is a service that stores container images. For example, IBM Cloud Container Registry and Docker Hub are container registries. A container registry can be public or private. A container registry that is public does not require credentials to access. In contrast, accessing a private registry does require credentials.                                                                                                                                                                                                                                                                                                |
| Function                 | A function is a stateless code snippet that performs tasks as it is invoked by HTTP requests. With IBM Code Engine functions, you can run your business logic in a scalable and serverless way. IBM Code Engine functions provide an optimized runtime environment to support low latency and rapid scale-out scenarios. Your function code can be written in a managed runtime that includes specific [Node.js or Python](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-runtime) versions.                                                                                                                                                       |
| Job                      | A job runs one or more instances of your executable code in parallel. Unlike applications, which handle HTTP requests, jobs are designed to run one time and exit. When you create a job, you can specify workload configuration information that is used each time that the job is run.                                                                                                                                                                                                                                                                                                                                                                       |
| Fleet                    | A fleet, also called a *serverless fleet*, runs one or more instances of user code to complete a set of specified tasks. Fleets can process large, compute-intensive workloads, allow control over machine profiles, and can run on GPU resources. Fleets are single tenant, implement dynamic task queuing, and provide full control over the machine profile configuration. Additionally, fleets can connect to Virtual Private Clouds (VPCs) to securely access user data and services.                                                                                                                                                                     |
| Project                  | A project is a grouping of Code Engine entities such as applications, jobs, and builds. A project is based on a Kubernetes namespace. The name of your project must be unique within your IBM Cloud&reg; resource group, user account, and region. Projects are used to manage resources and provide access to its entities. A project provides the following items. \n - Provides a unique namespace for entity names. \n - Manages access to project resources (inbound access). \n - Manages access to backing services, registries, and repositories (outbound access). \n - Has an automatically generated certificate for Transport Layer Service (TLS). |
| Secret                   | A secret provides a method to include sensitive configuration information, such as passwords or SSH keys, to your deployment. By referencing values from your secret, you can decouple sensitive information from your deployment to keep your app, function, or job portable. Anyone who is authorized to your project can also view your secrets; be sure that you know that the secret information can be shared with those users. Secrets contain information in key-value pairs.                                                                                                                                                                          |
| Service binding          | Service bindings provide applications, jobs, and functions access to IBM Cloud services.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| Subscription             | A subscription provides a way of signing up to receive events from a particular event producer. For more information about the different types of event producers and how to subscribe to them, see [Subscribing to event producers](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribing-events).                                                                                                                                                                                                                                                                                                                                               |
{: caption="Code Engine Terms" caption-side="bottom"}

================================

name: codeengine-plan-codeengine
title: Planning for Code Engine
description: 'IBM Cloud&reg; Code Engine supports three basic types of workloads: applications, jobs, and functions.'
last-updated: 2025-10-02
---

# Planning for Code Engine

{: #plan-codeengine}

IBM Cloud&reg; Code Engine supports three basic types of workloads: applications, jobs, and functions.

An application, or app, runs your code to serve HTTP requests. In addition to traditional HTTP requests, IBM Cloud&reg; Code Engine also supports applications that use WebSockets as their communications protocol. The number of running instances of an app are automatically scaled up or down (to zero) based on incoming requests and your configuration settings. An app contains one or more revisions. A revision represents an immutable version of the configuration properties of the app. Each update of an app configuration property creates a new revision of the app.

A job runs one or more instances of your executable code in parallel. Unlike applications, which handle HTTP requests, jobs are designed to run one time and exit. When you create a job, you can specify workload configuration information that is used each time that the job is run.

A function is a stateless code snippet that performs tasks as it is invoked by HTTP requests. With IBM Code Engine functions, you can run your business logic in a scalable and serverless way. IBM Code Engine functions provide an optimized runtime environment to support low latency and rapid scale-out scenarios. Your function code can be written in a managed runtime that includes specific [Node.js or Python](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-runtime) versions.

A fleet, also called a *serverless fleet*, runs one or more instances of user code to complete a set of specified tasks. Fleets can process large, compute-intensive workloads, allow control over machine profiles, and can run on GPU resources. Fleets are single tenant, implement dynamic task queuing, and provide full control over the machine profile configuration. Additionally, fleets can connect to Virtual Private Clouds (VPCs) to securely access user data and services.

| Characteristic            | Application                                                   | Job                                                       | Function                                                    | Fleet                                             |
| ------------------------- | ------------------------------------------------------------- | --------------------------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------- |
| Execution time (duration) | Long-running (10 minutes per request)                         | Long-running (up to 24 hours)                             | Short-running (2 minutes or less)                           | Long-running (minutes to weeks)                   |
| Startup latency           | Medium                                                        | Scheduled start                                           | Low                                                         | Low                                               |
| Termination               | Run-continuously                                              | Run-to-completion                                         | Run-to-completion                                           | Run-to-completion                                 |
| Invocation                | On request or permanently running                             | Scheduled                                                 | On request, instant                                         | Scheduled                                         |
| Programming Model         | Container-based build and execution                           | Container-based build and execution                       | Language-specific source code files and dependency metadata | Container-based build and execution               |
| Parallelism               | Parallel execution, flexible                                  | Low to medium parallel execution                          | High parallel execution                                     | High parallel execution and queuing               |
| Scale-out                 | Based on number of requests                                   | Based on job workload definition                          | Based on events or direct invocations                       | Based on number of tasks and concurrent instances |
| Optimized for             | Long running, highly complex workload and on-demand scale-out | Scheduled or planned workloads with high resource demands | Startup time and rapid scale-out                            | Large, compute-intensive work loads               |
{: caption="Comparing Code Engine applications, jobs, and functions" caption-side="bottom"}

## Code Engine use cases

{: #ce-use-cases}

While the use cases for Code Engine widely vary, here are some examples to get you started.

Experienced with containers, but no skill or budget for managing clusters
:    You are a developer who is knowledgeable about containers. However, you don't want the complexity or time consumption of managing a cluster. With Code Engine, you do not need to worry about the skills that are required to manage a cluster or the time it takes to do so. Instead, Code Engine takes these complexities away and the IBM team manages your infrastructure as part of the IBM Cloud service.

Workloads with intermittent spikes
:    Your website is busy on the weekends, but experiences less traffic during the week. Because this website experiences bursts of activity followed by periods of inactivity, Code Engine is a good solution. With Code Engine, the website application automatically scales up the application instances for the increase in traffic, and then back down again for the periods of inactivity (even down to zero).

Batch workloads integrated with storage
:    Your batch job processes employee salaries at the end of every month. Because this job runs monthly, it is idle most of the time, but consumes a high amount of CPU and memory when it does runs. The batch job needs to integrate with storage to store the results. By using Code Engine, you can integrate the batch job with IBM Cloud Object Storage and are charged only for the resources that the job uses when it is running. When the job is idle, it isn't consuming any resources and therefore is not incurring charges. However, the job might incur costs with the IBM Cloud Object Storage instance.

Bring your workload
:    Part of your job is to create images and deploy them. You are experienced with creating container images and with deploying them, but you want to simplify this process so that you can concentrate on other tasks. With Code Engine, you can build images and deploy them directly from the same interface, thus simplifying daily tasks and freeing up time to develop more code.

Testing, proof-of-concepts, or "tire-kicking”
:    You are interested in learning more about container-based architecture. Your team developed an application, but wants to test it out before the application is presented to stakeholders. This application is small, so they do not want to pay for even a small, dedicated cluster. In this case, you can test the application and then provide a proof-of-concept of the design to the stakeholders without the cost that a dedicated cluster might require.

## When to use an app, job, or function

{: #when-app-job}

Applications and jobs are very similar, in the end, they both simply run code. However, there are some key aspects to consider when you decide to structure your code as an app or job,

Does your code need to respond to an event?
:    In the context of Code Engine, any incoming HTTP request (even the request to load a web page) or a REST API call is considered an event. The concept of being event-driven is often the key factor when you choose between an app or a job because, by definition, apps are run because of an HTTP request while jobs are run as of result of an invocation.

:    If you know that your workload responds to incoming HTTP requests, then app is the right choice. However, if your workload is run and then done, a job is a better fit.

How does your code scale?
:    Both apps and jobs are scalable. Apps are scaled in response to measurable real-time criteria such as the number of active incoming requests because each instance of your app might be able to process only a certain number of concurrent requests at one time. Jobs are scaled based on how many instances are specified when the job is created.

:    If you know that you want a specific number of instances of your code to run, and each instance can be run without an incoming HTTP request, then a job is the right choice. However, if the number of instances must scale dynamically based on the incoming HTTP load, apps are a better fit.

## Common scenarios for Code Engine

{: #common-scenarios}

Read through some of these common scenarios to gain understanding of when to choose a specific type of workload.

Does your workload require low latency or is it interactive?
:    If your workload requires a client or user to wait synchronously for the response of the request, and the response must be available within a few milliseconds, use an application. Applications provide an externally reachable endpoint and respond synchronously to the request. Examples of such workloads are websites, chatbots, and mobile applications. Use [applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads).

Is your computation lightweight and does it require low CPU, memory, and I/O?
:    If your workload is lightweight and requires low CPU, memory, and I/O, then the concurrency option, available for applications might be helpful. A typical example is an API Server that provides basic operations and is backed with a NoSQL database. These types of requests typically have a small amount of data and require low memory or fewer CPU cycles. With higher concurrency, the application can process the data of a first request while the second request is waiting for I/O. Because the CPU and memory requirements are low, many requests can be run concurrently. Use [applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads).

Is your computation bound to CPU, memory, or I/O?
:    To process a specific amount of data, where each chunk of the data is large and requires a large amount of CPU and memory, jobs are typically the better choice. However, if the workload requires a request-response pattern, it's also possible to use apps. In both cases, the computation task runs with single concurrency. Each application instance or job task processes only one request or chunk of data concurrently to fully leverage the resources that are configured for the instance. Parallelism is achieved by the number of instances or tasks, where the cost of creating an additional task is negligible due to the high resource constraints. A typical example is the processing of image data in a Object Storage bucket or serving machine learning models. Use [applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads) or [jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-job-plan).

Does your computation run for a long time?
:    If the computation runs for longer durations, jobs are the better choice because of their asynchronous nature. The maximum duration of applications is always limited because maintaining an open connection at scale is expensive. Typical workloads are training machine learning models or hyper-parameter optimization. Use [jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-job-plan).

Can you specify the concurrency of your computation upfront?
:    If you know how much computation you need to perform, you can run a job with the exact number of instances until it completes. Typical examples are hyper-parameter tuning or training a neural network. Use [jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-job-plan).

Does your workload react to some event?
:    If your workload is required to react to an event, such as a Git commit that is pushed to your repository, an object that is uploaded into a Object Storage bucket, or a document that is modified within your database, use applications. Applications provide an endpoint that can be configured to receive events from the event source. Use [applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads).

Do you need to process a large amount of data in a short time in response to events or requests?
:    If your workload requires a fast response to unpredicted requests or events, then applications are typically a better fit because applications are scaled dynamically, even from zero. Use [applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads).

Combining apps and jobs
:    You can even combine apps and jobs, where an application can start a job to outsource specific computations. Jobs can also query an application. A typical example of a combination of both jobs and apps is training and serving of machine learning models. Jobs are typically used to train the models and applications are used to serve the models. Use [applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads) and [jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-job-plan).

================================

name: codeengine-app-workloads
title: Application workloads
description: 'IBM Cloud&reg; Code Engine is designed to address the needs of developers who want their code to run. Code Engine abstracts the operational burden of building, deploying, and managing workloads in Kubernetes so that developers can focus on what matters most to them: the source code. Developers can deploy and scale their applications, which are written in any framework or language, by delegating the complexity of building and managing their workloads to Code Engine. Learn about working with applications in Code Engine.'
last-updated: 2025-09-29
---

# Application workloads

{: #ceapplications}

IBM Cloud&reg; Code Engine is designed to address the needs of developers who want their code to run. Code Engine abstracts the operational burden of building, deploying, and managing workloads in Kubernetes so that developers can focus on what matters most to them: the source code. Developers can deploy and scale their applications, which are written in any framework or language, by delegating the complexity of building and managing their workloads to Code Engine. Learn about working with applications in Code Engine.
{: shortdesc}

## What are application workloads?

{: #ceapp-workloads}

An application, or app, runs your code to serve HTTP requests. In addition to traditional HTTP requests, IBM Cloud&reg; Code Engine also supports applications that use WebSockets as their communications protocol. The number of running instances of an app are automatically scaled up or down (to zero) based on incoming requests and your configuration settings. An app contains one or more revisions. A revision represents an immutable version of the configuration properties of the app. Each update of an app configuration property creates a new revision of the app.

## What are the key features of working with Code Engine applications?

{: #ceapp-features}

Review the following topics to learn more about working with applications in Code Engine.

- [Isolation](#ceapp-isolation)
- [Logging](#ceapp-logging)
- [Running applications](#ceapp-runapp)
- [Scaling](#ceapp-scaling)
- [Security](#ceapp-security)
- [Triggering applications with events](#ceapp-eventing)
- [Visibility](#ceapp-visibility)

### Isolation

{: #ceapp-isolation}

Code Engine is a multi-tenant, regional service where tenants share the same network and compute infrastructure. In particular, the network and compute infrastructure are shared resources and some management components are common to all tenants. However, tenants and their workloads are isolated from each other by using Code Engine projects. Code Engine prevents communication between projects, providing isolation to your applications inside a multi-tenant environment. In addition, there are access controls that are performed on a resource level to only allow authorized users to perform certain operations on project resources, such as applications or other Code Engine workloads.

For more information about workload isolation, see [Code Engine workload isolation](https://cloud.ibm.com/docs/codeengine?topic=codeengine-architecture#workload-isolation).

### Logging

{: #ceapp-logging}

When you work with Code Engine applications with the console and with logging enabled, logs are forwarded to an IBM Cloud Logs service instance that is associated with your Code Engine project. In the IBM Cloud Logs service instance, the logs are indexed, enabling full-text search through all generated messages and convenient querying based on specific fields. See [Getting logs for applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-troubleshoot-apps#ts-app-gettinglogs).

System event information can also be helpful to troubleshoot problems when you run jobs. You can view system event information with the CLI. See [Getting system event information for applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-troubleshoot-apps#ts-app-gettingevent).

For more information about logging, see [Viewing logs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-logging).

### Running applications

{: #ceapp-runapp}

Whether your code exists as source in a local file or in a Git repository, or your code is a container image that exists in a public or private registry, Code Engine provides you with a streamlined way to run your code as an app.

You can deploy and run applications in Code Engine in the following ways:

- Run from an existing container image. Create an application and provide a reference to your image to use when you deploy your app with Code Engine.

- Run from existing source code without any container image. If you are starting with source code that is located in a Git repository or on your local workstation, you can point to the location of your source and Code Engine takes care of building the image for you. Code Engine supports building from a Dockerfile and Cloud Native Buildpacks, which inspects your source code to determine how it must be built and packaged as a container image.

For more information about deploying and running applications, see [Working with apps in Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads).

### Scaling

{: #ceapp-scaling}

Code Engine applications scale up or down depending on the incoming requests. Applications follow the *scale-to-zero* model, where no instances are created in the absence of traffic, leading to cost optimization. When there is an incoming request, an app automatically scales up from zero to accommodate the workload.

With Code Engine, you can control autoscaling by setting the minimum and maximum number of instances. You can also specify the concurrency of the application by specifying the number of requests to run in parallel for a specific application instance to help determine when a new instance is provisioned.

For more information about scaling your app, see [Configuring application scaling](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-scale).

### Security

{: #ceapp-security}

Code Engine provides immediate DDOS protection for your application. Code Engine's DDOS protection is provided by Cloud Internet Services (CIS) at no additional cost to you. DDoS protection covers System Interconnection (OSI) Layer 3 and Layer 4 (TCP/IP) protocol attacks, but not Layer 7 (HTTP) attacks. See [DDoS protection](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secure#secure-ddos).

Code Engine also provides a service mesh to use its networking layer, which enables mutual Transport Layer Security (TLS) traffic on applications, thus securing *service-to-service* and *user-to-service* communication.

For more information about security, see [Code Engine and security](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secure).

### Triggering applications with events

{: #ceapp-eventing}

You can configure your Code Engine applications to receive cron events, IBM Cloud Object Storage events, or Kafka topics. When you subscribe to an event producer, you must specify the name of your destination application to receive the events.

For more information about working with event producers, see [Getting started with subscriptions](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribing-events).

### Visibility

{: #ceapp-visibility}

With Code Engine, you can determine the right level of visibility for your application by defining the endpoints, or system domain mappings that are available for receiving requests. An application can be exposed to the internet, to the IBM Cloud private network or scoped only to other resources in the same Code Engine project.

By default, every running application gets its own TLS secured endpoint, which you can map to your own domain.

In addition, you can map your own custom domain to a Code Engine application to route requests from your custom URL to your application. If you want to target your application with a domain that you own, you can use a custom domain mapping. When you set a custom domain mapping in Code Engine, you define a 1-to-1 mapping between your fully qualified domain name (FQDN) and a Code Engine application in your project.

For more information about visibility, see [Options for visibility for a Code Engine application](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsvisibility) and [Configuring custom domain mappings for your application](https://cloud.ibm.com/docs/codeengine?topic=codeengine-domain-mappings).

## How can I get started with applications?

{: #ceapp-getstart}

To deploy a simple Code Engine application with the `icr.io/codeengine/helloworld` sample image, see [Creating your first Code Engine app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-getting-started#app-hello).

Also, you can try an application tutorial, see [Deploying and scaling applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-tutorial).

To dive deeper into working with applications, see [Working with apps in Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads).

---

---

name: codeengine-batchjob-workloads
title: Batch job workloads
description: IBM Cloud&reg; Code Engine is a fully managed, serverless platform that runs your containerized workloads, including batch job or application workloads. Learn about running batch jobs in Code Engine.
last-updated: 2025-09-29
---

# Batch job workloads

{: #cebatchjobs}

IBM Cloud&reg; Code Engine is a fully managed, serverless platform that runs your containerized workloads, including batch job or application workloads. Learn about running batch jobs in Code Engine.
{: shortdesc}

## What are batch job workloads?

{: #batchjob-workloads}

A job in Code Engine runs one or more instances of your executable code. Unlike applications, which handle HTTP requests, jobs are designed to run one time and exit, such that the resources to run the job workload are freed up.

You can scale batch jobs by defining multiple instances. Workloads can be split into parallel tasks to reduce compute time. You can set the job to run with automatic retry to address failing workloads within a job instance. You can trigger batch jobs manually, programmatically, and by events, such as Object Storage events.

When you create a job, you can specify the workload configuration information that is used each time that the job is run.

Typical batch job workloads include:

- Machine model training
- Analyzing files, such as voice analysis or image recognition
- Compressing or decompressing files
- Archiving information

When you create a job, you can specify workload configuration information that is used each time that the job is run.

### What is the lifecycle of a batch job?

{: #batchjob-lifecycle}

When you submit a batch job, it runs to completion. Typically, batch jobs retrieve input data, do computational work, and store the results in persistent data stores. When the batch job is completed, resources that are used to run the job are removed and no cost is incurred for any stand-by resources.

### What are job arrays and job array statuses?

{: #batchjob-jobarray}

The job array specification is part of the job and the job run configuration. A job array has two functions:

- It determines the number of concurrent instances that are started for the job run.
- It allows user code to determine which part of the work each instance should perform based on the individual array index provided to it.

Specify a job array by either array size or by a set of array indexes:

- If you specify an array size with a value of value *n*, then the number of instances that are started for the job run is *n*. Each instance is provided an array index (either 0, 1, 2, and so on, until *n*-1), using the `JOB_INDEX` environment variable. The `JOB_ARRAY_SIZE` environment variable is set to *n* unless you specify a particular value for it.

- If you specify a set of one or more array indexes, then the number of instances that are started is the number of indexes. Each instance is provided with one of the specified indexes by using the `JOB_INDEX` environment variable. The `JOB_ARRAY_SIZE` environment variable is set to the number of specified indexes unless you specify a particular value for it.

The `JOB_ARRAY_SIZE` environment variable is also available for user code and is, by default, set to the number of indexes.

If an instance finishes with a successful return code, then the status of the associated array index changes to completed. Otherwise, Code Engine starts a new instance for the same index, if the configured number of retries has not yet exceeded. If an instance fails, and no more retries are allowed, the associated array index changes its status to failed.

## What are the key features of working with Code Engine batch jobs?

{: #batchjob-features}

Review the following topics to learn more about working with batch jobs in Code Engine.

- [Isolation](#batchjob-isolation)
- [Logging](#batchjob-logs)
- [Queuing](#batchjob-queue)
- [Retries](#batchjob-retries)
- [Running batch jobs](#batchjob-run)
- [Scaling](#batchjob-scaling)
- [Status](#batchjob-status)
- [Submitting similar batch jobs](#batchjob-reuse)
- [Triggering batch jobs with events](#batchjob-eventing)

### Isolation

{: #batchjob-isolation}

Code Engine is a multi-tenant, regional service where tenants share the same network and compute infrastructure. In particular, the network and compute infrastructure are shared resources and some management components are common to all tenants. However, tenants and their workloads are isolated from each other by using Code Engine projects.  Code Engine prevents communication between projects, providing isolation to your applications inside a multi-tenant environment. In addition, there are access controls that are performed on a resource level to allow only authorized users to perform certain operations on project resources, such as applications or other Code Engine workloads.

For more information about workload isolation, see [Code Engine workload isolation](https://cloud.ibm.com/docs/codeengine?topic=codeengine-architecture#workload-isolation).

### Logging

{: #batchjob-logs}

When you work with Code Engine jobs in the console with logging enabled, logs are forwarded to an IBM Cloud Logs service instance that is associated with your Code Engine project. In the IBM Cloud Logs service instance, the logs are indexed, enabling full-text search through all generated messages and convenient querying based on specific fields. See [Getting logs for jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-troubleshoot-job#ts-jobrun-gettinglogs).

System event information can also be helpful to troubleshoot problems when you run jobs. You can view system event information with the CLI. See [Getting system event information for jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-troubleshoot-job#ts-job-gettingevent).

For more information, see [Viewing logs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-logging).

### Queuing

{: #batchjob-queue}

Submitted batch jobs are automatically queued and are in a pending state until dispatched. Batch jobs are run based on the available compute resources as defined by your Code Engine project. Batch jobs that are in a `pending` status can be removed from the queue. You can monitor batch jobs that are pending, running, or completed by using the Code Engine console or command-line interface.

### Retries

{: #batchjob-retries}

Each job instance runs to completion. However, the workload code might encounter an error during the job run. When a job instance completes with a nonzero return code, Code Engine restarts the job instance. With Code Engine, you can specify to limit the number of retries to avoid restarting failed job instances.

### Running batch jobs

{: #batchjob-run}

Whether your code exists as source in a local file or in a Git repository, or your code is a container image that exists in a public or private registry, Code Engine provides a streamlined way for you to run your code as a job.

You can create and run batch jobs in Code Engine in the following ways:

- Run an existing container image. Create a job and provide a reference to your image to use when you submit the job. For an example, see [Create and run a job](https://cloud.ibm.com/docs/codeengine?topic=codeengine-getting-started#first-job).
- Start with source code. If you are starting with source code that is located in a Git repository or on your local workstation, you can point to the location of your source and Code Engine takes care of building the image for you. See [Create a job from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-run-job-source-code) and [Create a job from local source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-job-local-source-code).

For more information, see [Working with jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-job-plan).

### Scaling

{: #batchjob-scaling}

A job in Code Engine (batch job) consists of one or more job instances. While job instances run independent of each other, they run the same code. Suppose you have a database with 100 records to analyze. You can run your job such that each job instance analyzes 10 records each. For example, the first job instance analyzes records 0 - 9, the second job instance can analyze records 10 - 19, and so on. In this example, each job instance receives the system provided job input parameter `JOB_INDEX` as an environment variable that you can use to calculate the range of database records to analyze by each job instance. The number of job instances is specified when the batch job is submitted.

When you run a batch job, during the startup time, job instances might linger in a pending state as the instances are being started. Pending times for job instances can vary due to the system and network infrastructure, as the system adjusts to fulfill the resource demands related to this run of the job. If the system infrastructure is responding to a high usage demand, the result might be a multi-minute delay of the startup for jobs because job instances are provisioned just-in-time.
{: note}

### Status

{: #batchjob-status}

A batch job is in the `Succeeded` status when all job run instances are completed.

A batch job is in `Failed` status after one or more job run instances reaches the retry limit. Also, if a job takes too long to complete, the job is in `Failed` status whenever the maximum execution time is reached. For more information, see [job status](https://cloud.ibm.com/docs/codeengine?topic=codeengine-access-job-details#job-status).

### Submitting similar batch jobs

{: #batchjob-reuse}

When you create a job, you can specify workload configuration information that is used each time that the job is run. When you use a common set of configuration information for batch jobs, with Code Engine, you can specify additional parameters with the job submission to overwrite the batch job parameters for this specific job submission.

### Triggering batch jobs with events

{: #batchjob-eventing}

Batch jobs can be submitted automatically based on events, such as periodic timers, Object Storage events, or Kafka topics.

Suppose you want to trigger your batch job automatically based on a subscription to an IBM Cloud Object Storage bucket that generates events whenever a file changes or is added to the Object Storage bucket. Review the [Code Engine `cos-event-job` sample](https://github.com/IBM/CodeEngine/tree/main/cos-event-job){: external} for information about how to create Object Storage events and use the events to trigger batch jobs.

For more information about using eventing with Code Engine jobs, see the following topics: [Working with the Periodic timer (cron) event producer](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribe-cron#eventing-cron-job), [Working with the IBM Cloud Object Storage event producer](https://cloud.ibm.com/docs/codeengine?topic=codeengine-eventing-cosevent-producer#obstorage_ev_job), and [Working with the Kafka event producer](https://cloud.ibm.com/docs/codeengine?topic=codeengine-working-kafkaevent-producer#subscribe-kafka-job).

Looking for more code examples? Check out the [Samples for IBM Cloud Code Engine GitHub repo](https://github.com/IBM/CodeEngine){: external}.
{: tip}

## How can I get started with batch jobs?

{: #batchjob-getstart}

To create and run a simple Code Engine batch job application with the `icr.io/codeengine/firstjob` sample image, see [Running your first Code Engine job](https://cloud.ibm.com/docs/codeengine?topic=codeengine-getting-started#first-job).

Also, you can try a batch job tutorial, see [Running and updating jobs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-run-job-tutorial).

To dive deeper into working with batch jobs, see [Working with jobs and job runs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-job-plan).

---

---

name: codeengine-function-workloads
title: Function workloads
description: A function is a stateless code snippet that performs tasks as it is invoked by HTTP requests. With IBM Code Engine functions, you can run your business logic in a scalable and serverless way. IBM Code Engine functions provide an optimized runtime environment to support low latency and rapid scale-out scenarios. Your function code can be written in a managed runtime that includes specific Node.js or Python versions.
last-updated: 2025-09-29
---

# Function workloads

{: #cefunctions}

A function is a stateless code snippet that performs tasks as it is invoked by HTTP requests. With IBM Code Engine functions, you can run your business logic in a scalable and serverless way. IBM Code Engine functions provide an optimized runtime environment to support low latency and rapid scale-out scenarios. Your function code can be written in a managed runtime that includes specific [Node.js or Python](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-runtime) versions.
{: shortdesc}

A code bundle is a collection of files that represents your function code. This code bundle is injected into the runtime container. Your code bundle is created by Code Engine and is stored in container registry or inline with the function. A code bundle is not a Open Container Initiative (OCI) standard container image.

## Lifecycle of a function instance

{: #functions-lifecycle}

When a function is invoked (started), the corresponding Function instance is initialized with the configured Runtime container and Resource parameters. The process of the first initialization is referred to as *cold start*.

To reduce the cold start latency, Code Engine optimizes the invocation by pre-warming certain runtimes with specific CPU and memory configurations. Pre-warmed combinations for functions include Node.js and Python runtimes as well as the default CPU and memory combination for Functions, which is 0.25 vCPU x 1 GB of memory. In addition, the system is designed to improve the reuse of Function instances that are already initialized. Therefore, a Function instance is kept alive after the invocation is finished to allow subsequent invocations by reusing the same instance and reusing the state of the instance when the last invocation completed. The reuse of a Function instance is not guaranteed.

## What are key features of working with functions?

{: #functions-work-ce}

Review the following topics to learn more about working with IBM Code Engine Functions.

- [Isolation](#cefun-isolation)
- [Logging](#functions-logging)
- [Runtimes](#functions-runtime)
- [Running functions](#cefun-runfun)
- [Security](#cefun-security)
- [Invocation concurrency and scaling of function instances](#functions-concur-ce)
- [Packaging your source code for a function](#functions-packaging)

### Isolation

{: #cefun-isolation}

Code Engine is a multi-tenant, regional service where tenants share the same network and compute infrastructure. In particular, the network and compute infrastructure are shared resources and some management components are common to all tenants. However, tenants and their workloads are isolated from each other by using Code Engine projects.  Code Engine prevents communication between projects, providing isolation to your applications inside a multi-tenant environment, which can include applications, batch jobs, and functions. In addition, there are access controls that are performed on a resource level to allow only authorized users to perform certain operations on project resources, such as functions or other Code Engine workloads.

For more information about workload isolation, see [Code Engine workload isolation](https://cloud.ibm.com/docs/codeengine?topic=codeengine-architecture#workload-isolation).

### Logging

{: #functions-logging}

Function code can write `stdout` and `stderr` logs that are captured and forwarded to an IBM Cloud Logs instance. IBM Cloud Logs is a Platform logging instances that you can set up to index your logs. For more information, see [Viewing logs](https://cloud.ibm.com/docs/codeengine?topic=codeengine-logging).

### Runtimes

{: #functions-runtime}

Code Engine includes *Managed runtimes* that you can use for your Functions.

Managed runtimes include Node.js and Python versions and specific CPU and memory combinations. These runtimes are optimized for fast startup. These runtimes are pre-warmed, which avoids the overhead of pulling container images and starting containers and processes. Your code is injected into an already running container.

For more information, see [Runtimes](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-runtime).

### Running functions

{: #cefun-runfun}

Whether your code exists as source in a local file or in a Git repository, or your code is a container image that exists in a public or private registry, Code Engine provides you a streamlined way to run your code as an app.

You can create and invoke your function in Code Engine in the following ways:

- Run from an existing code bundle.

- Run from existing source code. If you are starting with source code that is located in a Git repository or on your local workstation, you can point to the location of your source and Code Engine takes care of building the image for you.

For more information about creating and invoking functions, see [Working with functions in Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-work).

### Security

{: #cefun-security}

Code Engine provides immediate DDOS protection for your function. Code Engine's DDOS protection is provided by Cloud Internet Services (CIS) at no additional cost to you. DDoS protection covers System Interconnection (OSI) Layer 3 and Layer 4 (TCP/IP) protocol attacks, but not Layer 7 (HTTP) attacks. See [DDoS protection](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secure#secure-ddos).

Code Engine also provides a service mesh to use its networking layer, which enables mutual Transport Layer Security (TLS) traffic for functions, thus securing *service-to-service* and *user-to-service* communication.

For more information about security, see [Code Engine and security](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secure).

### Invocation concurrency and scaling of function instances

{: #functions-concur-ce}

When multiple functions are being invoked at the same time, Code Engine initializes new function instances for each invocation, but at the same time, tries to maximize the reuse. Only one function invocation is handled by a function instance at a single point in time. For Node.js, the function can be configured with `concurrency > 0` to allow multiple invocations to be handled in a single function instance.

### Packaging your source code for a function

{: #functions-packaging}

Functions can be packaged in three different ways.

- as a single file
- as multiple files (with a folder structure and dependent modules)
- as a container image

## How can I get started with functions?

{: #cefun-getstart}

To deploy a simple Code Engine application with a `hello-world` sample image, see [Running IBM Code Engine Functions](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-tutorial) tutorial.

To dive deeper into working with functions, see [Working with functions in Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fun-work).

---

---

name: codeengine-fleets-workloads
title: Fleets workloads
description: IBM Cloud&reg; Code Engine is a fully managed, serverless platform that runs your containerized workloads, including fleet workloads. Learn about running fleets in Code Engine.
last-updated: 2026-05-22
---

# Fleets workloads

{: #cefleets}

IBM Cloud&reg; Code Engine is a fully managed, serverless platform that runs your containerized workloads, including fleet workloads. Learn about running fleets in Code Engine.
{: shortdesc}

## What are fleets?

{: #fleet-workloads}

A fleet, also called a **serverless fleet**, is a Code Engine compute component that runs one or more instances of user code in parallel to complete a large queue of compute-intensive tasks. Fleets can connect to Virtual Private Clouds to securely exchange user data when connecting to other services. Unlike batch jobs, fleets provide dynamic task queuing and single-tenant isolation, and are compatible with both vCPU and GPUs.

## How do fleets work?

{: #fleet-how}

Fleets have three principal elements: tasks, instances, and worker nodes. A single task is completed by a single instance of user code, which runs on a worker node. Each worker node can run several tasks concurrently, allowing many tasks to be completed in parallel. When a task is complete, a new instance spins up on the worker node to complete the next available task in the queue. This process repeats on each worker node until all tasks are completed, at which point worker nodes are automatically deprovisioned.  

## How are fleets different from jobs?

{: #fleet-v-job}

Unlike batch jobs, which are primarily intended for small to medium sized tasks, fleets are designed to complete large, compute-intensive tasks. Review the table below for specific differences between jobs and fleets.

| Characteristic        | Fleets                            | Jobs                            |
| --------------------- | --------------------------------- | ------------------------------- |
| Isolation             | Single-tenant                     | Multi-tenant                    |
| Task size             | Large tasks                       | Small-to-medium sized tasks     |
| Implementation        | Dynamic queue                     | Static array                    |
| Machine configuration | Full control over machine profile | No control over machine profile |
| VPC connection        | Natively connects to existing VPC | Requires private path           |
{: caption="Comparing Code Engine Fleets and jobs " caption-side="bottom"}

## What are the key features of working with Code Engine fleets?

{: #fleet-features}

Review the following topics to learn more about working with fleets in Code Engine.

### Automatic scaling

{: #fleet-scaling}

With a fleet, you can take advantage of large scale parallelism to complete large, compute-intensive tasks. Code Engine automatically scales the worker nodes in your fleet to meet resource requirements most efficiently. You can let Code Engine determine the profiles of the workers that are deployed, or you can choose a specific profile, such as a GPU type. In either case, Code Engine automatically scales the number of workers for the greatest level of efficiency.

The number of workers deployed is based on the number of tasks to complete, the resources required for an instance of your code, and the maximum number of concurrent instances you want to run at a time. By adjusting these settings, you can scale your fleet to complete as few as 1 or as many as several million tasks.

For example, imagine you have 4 tasks to complete. Each instance of code to complete a task requires `1 vCPU and 2 GB memory`, for a total requirement of `4 vCPU and 8GB memory`. If you set the maximum number of concurrent instances to 2, Code Engine can deploy 1 worker node with `2 vCPU and 4 GB memory` to run 2 instances at one time. If you set the maximum number of concurrent instances to 4, Code Engine can deploy 2 of the same worker nodes to run all 4 instances at the same time across both workers. In the second scenario, the fleet finishes more quickly but requires more workers to be deployed. Keep in mind that there is an infinite number of combinations for automatic worker node deployment, and that worker nodes of various profiles might be deployed.

Automatic scaling is not available for GPUs. To deploy GPUs for a fleet, you must specify the type of GPU worker to deploy.
{: note}

### Task and instance specification

{: #fleet-taskspec}

When deploying a fleet, users can specify the number of tasks to complete, the number of instances to run at a time, the order in which tasks are completed. Fleets can work on many tasks in parallel by starting multiple instances concurrently. All instances are created with the same amount of vCPU and memory as in the fleet's specification. Additionally users can create a task specification file to provide specific commands and arguments for each task or to create custom task indexes.

### Task storage in COS

{: #fleet-cos}

You can use a COS bucket to provide the tasks for your fleet by specifying a persistent data store and bucket subpath when you create the fleet. Each object in the COS bucket represents a single task.

### Isolation

{: #fleet-isolation}

Unlike batch jobs, fleets provide single-tenant isolation. Your fleet workers are not shared with other users.

### Retries

{: #fleet-retries}

Each fleet instance runs to completion. However, in case of an error, Code Engine restarts the instance. You can limit the maximum number of retries to avoid restarting failed instances.

### Status

{: #fleet-status-summary}

A fleet is in the `Running` status when at least one worker node is provisioned. When the fleet is no longer running, it is in the `Succeeded` status if all tasks completed successfully, or `Failed` if one or more tasks failed. You can also cancel a fleet.

For more information, see [Understanding the status of your fleet](https://cloud.ibm.com/docs/codeengine?topic=codeengine-fleet-status).

### Worker profile

{: #fleet-profile}

You can optionally choose the profile for your fleet worker. If you do not specify a profile, Code Engine will pick a profile for you.

Code Engine fleets support the following profile families:

| Instance profile |
| ---------------- |
| bx2-2x8          |
| bx2-4x16         |
| bx2-8x32         |
| bx2-16x64        |
| bx2-32x128       |
| bx2-48x192       |
| bx2-64x256       |
| bx2-96x384       |
| bx2-128x512      |
| bx2a-2x8         |
| bx2a-4x16        |
| bx2a-8x32        |
| bx2a-16x64       |
| bx2a-32x128      |
| bx2a-48x192      |
| bx2a-64x256      |
| bx2a-96x384      |
| bx2a-128x512     |
| bx2a-228x912     |
| bx2d-2x8         |
| bx2d-8x32        |
| bx2d-16x64       |
| bx3d-2x10        |
| bx3d-4x20        |
| bx3d-8x40        |
| bx3d-16x80       |
| bx3d-24x120      |
| bx3d-32x160      |
| bx3d-48x240      |
| bx3d-64x320      |
{: caption="Balanced" caption-side="bottom"}
{: tab-title="Balanced"}
{: tab-group="profiles-tab-group"}
{: class="simple-tab-table"}
{: #balanced}

| Instance profile |
| ---------------- |
| cx2-2x4          |
| cx2-4x8          |
| cx2-8x16         |
| cx2-16x32        |
| cx2-32x64        |
| cx2-48x96        |
| cx2-64x128       |
| cx2-96x192       |
| cx2-128x256      |
| cx3d-2x5         |
| cx3d-4x10        |
| cx3d-8x20        |
| cx3d-16x40       |
| cx3d-24x60       |
| cx3d-32x80       |
| cx3d-48x120      |
| cx3d-64x160      |
{: caption="Compute" caption-side="bottom"}
{: tab-title="Compute"}
{: tab-group="profiles-tab-group"}
{: class="simple-tab-table"}
{: #compute}

| Instance profile |
| ---------------- |
| mx2-2x16         |
| mx2-4x32         |
| mx2-8x64         |
| mx2-16x128       |
| mx2-32x256       |
| mx2-48x384       |
| mx2-64x512       |
| mx2-96x768       |
| mx2-128x1024     |
| mx2d-16x128      |
| mx2d-64x512      |
| mx2d-96x768      |
| mx3d-2x20        |
| mx3d-4x40        |
| mx3d-8x16        |
| mx3d-16x160      |
| mx3d-24x240      |
| mx3d-32x320      |
| mx3d-48x480      |
| mx3d-64x640      |
{: caption="Memory" caption-side="bottom"}
{: tab-title="Memory"}
{: tab-group="profiles-tab-group"}
{: class="simple-tab-table"}
{: #memory}

| Instance profile    |
| ------------------- |
| gx3-16x80x1l4       |
| gx3-32x160x2l4      |
| gx3-64x320x4l4      |
| gx3-24x120x1l40s    |
| gx3-48x240x2l40s    |
| gx2-8x64x1v100      |
| gx2-16x128x1v100    |
| gx2-16x128x2v100    |
| gx2-32x256x2v100    |
| gx3d-24x120x1a100p  |
| gx3d-48x240x2a100p  |
| gx3d-160x1792x8h100 |
| gx3d-160x1792x8h200 |
| gx4d-232x3840x8b300 |
{: caption="GPU" caption-side="bottom"}
{: tab-title="GPU"}
{: tab-group="profiles-tab-group"}
{: class="simple-tab-table"}
{: #gpu}

| Instance profile |
| ---------------- |
| nxf-2x1          |
| nxf-2x2          |
| bxf-2x8          |
| bxf-4x16         |
| bxf-8x32         |
| bxf-16x64        |
| bxf-24x96        |
| bxf-32x128       |
| bxf-48x192       |
| bxf-64x256       |
| cxf-2x4          |
| cxf-4x8          |
| cxf-8x16         |
| cxf-16x32        |
| cxf-24x48        |
| cxf-32x64        |
| cxf-48x96        |
| cxf-64x128       |
| mxf-2x16         |
| mxf-4x32         |
| mxf-8x64         |
| mxf-16x128       |
| mxf-24x192       |
| mxf-32x256       |
| mxf-48x384       |
| mxf-64x512       |
{: caption="Flex" caption-side="bottom"}
{: tab-title="Flex"}
{: tab-group="profiles-tab-group"}
{: class="simple-tab-table"}
{: #flex}

Some profiles may not be available in all VPC network zones. You can use the following CLI command to list worker profiles supported by Code Engine serverless fleets in a region.

```txt
ibmcloud ce fleet worker profiles
```

{: pre}

- If you want to know zonal availability and capacity of certain profiles, such as H100 and L40s, [open a support case](https://cloud.ibm.com/docs/codeengine?topic=codeengine-get-support) and select "Virtual Private Cloud (VPC)" as the topic.
- If you need a certain VPC profile which is not supported by fleets today, [open a support case](https://cloud.ibm.com/docs/codeengine?topic=codeengine-get-support) and select "Code Engine" as the topic.

## How can I get started with fleets?

{: #fleet-getstart}

To create and run a simple Code Engine fleet with the `icr.io/codeengine/helloworld` sample image, see [Running your first Code Engine fleet](https://cloud.ibm.com/docs/codeengine?topic=codeengine-getting-started#first-fleet).
