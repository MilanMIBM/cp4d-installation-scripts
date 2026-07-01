================================

---

name: codeengine-appdeploy-plan
title: Working with apps in Code Engine
description: An application, or app, runs your code to serve HTTP requests. In addition to traditional HTTP requests, IBM Cloud&reg; Code Engine also supports applications that use WebSockets as their communications protocol. The number of running instances of an app are automatically scaled up or down (to zero) based on incoming requests and your configuration settings. An app contains one or more revisions. A revision represents an immutable version of the configuration properties of the app. Each update of an app configuration property creates a new revision of the app.
last-updated: 2026-01-27
---

# Working with apps in Code Engine

{: #application-workloads}

An application, or app, runs your code to serve HTTP requests. In addition to traditional HTTP requests, IBM Cloud&reg; Code Engine also supports applications that use WebSockets as their communications protocol. The number of running instances of an app are automatically scaled up or down (to zero) based on incoming requests and your configuration settings. An app contains one or more revisions. A revision represents an immutable version of the configuration properties of the app. Each update of an app configuration property creates a new revision of the app.
{: shortdesc}

Before you begin

* If you want to use the Code Engine console, go to [Code Engine overview](https://cloud.ibm.com/codeengine/overview){: external}.
* If you want to use the CLI, [set up your Code Engine CLI environment](https://cloud.ibm.com/docs/codeengine?topic=codeengine-install-cli).
* Plan and choose your approach for making your code run as a Code Engine application component.
* Ensure that your app follows the [12-factor app methodology](https://12factor.net/){: external}.

For security features provided with Code Engine, see [Code Engine and security](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secure).

Code Engine provides custom resource definition (CRD) methods. For more information, see [Serving CRD methods](https://cloud.ibm.com/docs/codeengine?topic=codeengine-kubernetes#api-crd-serving).

Not sure what type of Code Engine workload to create? See [Planning for Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-codeengine).
{: tip}

## How do I make my code run as a Code Engine application component?

{: #deploy-app-containerimage}

Whether your code exists as source in a local file or in a Git repository, or your code is a container image that exists in a public or private registry, Code Engine provides you with a streamlined way to run your code as an app.

* If you have a container image, per the [Open Container Initiative (OCI) standard](https://opencontainers.org/){: external}, then you need to provide only a reference to the image, which points to the location of your container registry when you create and deploy your app. You can deploy your app with an image in a [public registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app) or [private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

* If you are starting with source code that resides in a Git repository, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** operation. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you create and deploy your app.

* If you are starting with source code that resides on a local workstation, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** CLI command. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from local source code with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you create and deploy your app.

After your app is deployed, you can also [update your deployed app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app) by using *any* of the preceding ways, independent of how you created or previously updated your app.

When you deploy your application, the latest version of your referenced container image is downloaded and deployed, unless a tag is specified for the image. If a tag is specified for the image, then the tagged image is used for the deployment.

The image that is associated with your specific application revision has a unique container registry digest, and Code Engine uses this digest for the life of your application revision. If you create a newer version of an image with the same tag as the original image, the original image is overwritten in the container registry and becomes untagged. The newer image is tagged, and this newer image has a different digest. Your Code Engine application does not use this newer image, because the newer image has a different digest than the  image that is referenced by the application revision. Code Engine can still create new instances of the application revision as long as the untagged image, which was referenced originally, still exists. For more information, see [Why can't Code Engine pull an image?](https://cloud.ibm.com/docs/codeengine?topic=codeengine-image-cannot-pull)
{: important}

The default URL for applications is of the format `https://<appname>.<uuid>.<region>.codeengine.appdomain.cloud` where `appname` is the name of your app, `uuid` is the automatically generated unique identifier, and `region` is the region in which your Code Engine project resides. The UUID portion of the URL of an application is of the format `aaaabbbbccc`. The automatically generated application URL persists for the lifecycle of the project for your application.

For more information about endpoints to access applications by region, see [Code Engine endpoints for accessing applications](https://cloud.ibm.com/docs/codeengine?topic=codeengine-regions#endpoints-app).

## What do I need to know about ports for apps in Code Engine?

{: #deploy-app-ports}

By default, Code Engine assumes that apps listen for incoming connections on port `8080`. In addition, Code Engine sets the `PORT` environment variable to the port value that the application is expected to be listening on. If your app needs to listen on a port other than port `8080`, either deploy your app from the console and specify the correct port or use the `--port` option on the **`app create`** command. For more information about environment variables that are set by Code Engine, see [Automatically injected environment variables](https://cloud.ibm.com/docs/codeengine?topic=codeengine-inside-env-vars). The following ports are reserved by Code Engine:  `8022`, `8008`, `8012`, `9090`, `9091`, and `15090`. Only one port can be exposed as the listening port.

Inbound connections to Code Engine over HTTP on the Internet use port `80`. Inbound connections to Code Engine over HTTPS on the Internet use port `443`

If a port scan shows more open ports, see [Why does my port scan show more open ports than expected](https://cloud.ibm.com/docs/codeengine?topic=codeengine-ts-app-toomanyports)?

## Considerations for HTTP handling

{: #considerationshttphandlingapp}

When you are working with applications (or jobs), it is helpful to be aware of basic HTTP handling in Code Engine.

* For incoming application connections that use HTTP, the transport layer security (TLS) aspects are managed automatically by Code Engine outside of the application code. The HTTP Server for the application needs to be concerned about only HTTP connectivity and not HTTPS connectivity. In particular, Code Engine uses Cloud Internet Services (CIS) in IBM Cloud, which is based on CloudFlare, as the intrusion prevention system (IPS) for DNS and DDOS protection on layer 4. The TCP/IP connection that is established on the IPS is owned and managed by Cloudflare. For more information, see [Cloudflare documentation](https://developers.cloudflare.com/fundamentals/reference/network-ports/#how-to-block-traffic-on-additional-ports){: external}.

* Internet connections that are bound for Code Engine applications are automatically redirected to use HTTPS.

* Outbound connections from applications to other Code Engine applications are automatically protected by TLS. Code Engine automatically manages this connectivity, so the protocol (or URL) that is used is `HTTP` and not `HTTPS`.

* Outbound connections from applications to non-Code Engine applications, such as the internet, use `HTTP` or `HTTPS` depending on the protocol that is specified in the app code or URL.

* Outbound connections from batch jobs use the `HTTP` or `HTTPS` protocol that is specified in the job code or URL. This behavior includes connections from batch jobs to Code Engine apps.

## Options for visibility for a Code Engine application

{: #optionsvisibility}

With Code Engine, you can determine the right level of visibility for your application by defining the endpoints, or system domain mappings that are available for receiving requests.
{: shortdesc}

Every application has an *internal* system domain mapping that is visible to all components within the same Code Engine project, but not outside of the project. In addition to the internal system domain mapping, you choose to make the application visible to either the *public* internet or the IBM Cloud *private* network.

For public or private visibility, the application is exposed on an HTTPS endpoint. For details about the TLS certificate that is used, see [TLS certificates for Code Engine projects](https://cloud.ibm.com/docs/codeengine?topic=codeengine-tls-certificate).

You can deploy your application with the following visibility levels:

| Setting                                         | Description                                                                                                                                                                                                                                                                                                                                                             |
| ----------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [internal (project)](#app-endpoint-projectonly) | An app with this setting can receive requests from components in the same Code Engine project. Setting an internal (project) endpoint means that your app is not accessible from the public internet and network access is only possible from other Code Engine components that are running within the same Code Engine project. This endpoint is always enabled.       |
| [public](#app-endpoint-public)                  | An app with this setting is exposed to the internet and your Code Engine project. Setting a public endpoint means that your app can receive requests from the public internet or from components within your Code Engine project. This setting is the default.                                                                                                          |
| [private](#app-endpoint-private)                | An app with this setting is exposed to the IBM Cloud private network and your Code Engine project. Setting a private endpoint means that your app is not accessible from the public internet and network access is only possible from other IBM Cloud services by using Virtual Private Endpoints (VPE) or Code Engine components that are running in the same project. |
{: caption="Visibility for applications" caption-side="bottom"}

You can set the endpoint settings for visibility of an application from the console or with the CLI when you create and deploy, or update your app.

### Deploying your app with a public endpoint

{: #app-endpoint-public}

When you deploy an app, by default, the application deploys such that it can receive requests from the public internet or from components within the same Code Engine project. In this case, the app is deployed with a public endpoint.

### Deploying your app with a private endpoint

{: #app-endpoint-private}

You can set the endpoint visibility for your app such that it is deployed with a private endpoint. Setting a private endpoint means that your app is not accessible from the public internet and network access is only possible from other IBM Cloud services from virtual private endpoints (VPE) or Code Engine components that are running in the same project (cluster-local).

For example, if your solution consists of a component that is running on an IBM Cloud Kubernetes Service Kubernetes cluster within your own virtual private endpoint and you want to access the Code Engine application from the IBM Cloud private network, you can set the visibility of the application to private. When the visibility of the app is set to private, the app is not accessible through the public internet. The application is still accessible from other applications within the project.

You can [deploy your application with a private endpoint](https://cloud.ibm.com/docs/codeengine?topic=codeengine-vpe#using-vpes-app) so that the app is only exposed through the IBM Cloud private network and not exposed to the external internet. The application is still reachable through shared components from within the internal network and the application endpoint needs to be secured.

With the CLI, set the endpoint visibility for your app so that it is deployed with a private endpoint by using the `--visibility=private` option on the [**`app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) or [**`app update`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-update) command. You can obtain the available URLs for your app that reflect your endpoint definition by using the [**`app get`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-get) command.

From the console, set the visibility of endpoints for your app by using the **Endpoints** setting when you create your app. After your app is deployed, you can view and modify these system domain mapping settings on the **Domain mappings** tab on your application page.

For more information about connecting over private networks, see [Using Virtual Private Endpoints with Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-vpe).

### Deploying your app with a project endpoint

{: #app-endpoint-projectonly}

You can set the endpoint visibility for your app such that it is deployed with an internal (project) endpoint. Setting a project-only endpoint means that your app is not accessible from the public internet and network access is only possible from other Code Engine components that are running within the same Code Engine project. This endpoint is always enabled. Applications are still accessible through shared components and therefore need to be secured.

For example, if your solution consists of several applications within a project, you might set up your solution such that only one of those applications is visible from the internet so that it handles incoming traffic. This public-facing application can delegate work to other applications in your solution so that they do not need to be visible from the internet.

With the CLI, set the endpoint visibility for your app so that it is deployed with a project endpoint by using the `--visibility=project` option on the [**`app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) or [**`app update`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-update) command. You can obtain the available URLs for your app that reflect your endpoint definition by using the [**`app get`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-get) command.

From the console, set the visibility of endpoints for your app by using the **Endpoints** setting when you create your app. After your app is deployed, you can view and modify these system domain mapping settings on the **Domain mappings** tab on your application page.

## Options for deploying a Code Engine application

{: #optionsdeploy}

Learn about the options that you can specify when you deploy your app. Note that options can vary between the console and the CLI.
{: shortdesc}

### Memory and CPU

{: #deploy-app-combo}

When you deploy your app, you can specify the amount of memory and CPU that your app can consume. These amounts can vary, depending on if your app is compute-intensive, memory-intensive, or balanced.
{: shortdesc}

By default, your application is assigned 4 G of memory and 1 vCPU. For more information about selecting memory and CPU, see [Supported memory and CPU combinations](https://cloud.ibm.com/docs/codeengine?topic=codeengine-mem-cpu-combo).

### Deploying your app with commands and arguments

{: #deploy-app-cmd-args}

You can define commands and arguments for your application to use at run time.
{: shortdesc}

Define commands and arguments for your application by adding the `--cmd` and `--arg` options to your [**`app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.

```txt
ibmcloud ce app create --name myapp --image icr.io/codeengine/hello --cmd /myapp --arg --debug
```

{: pre}

For more information about using `cmd` and `arg`, see [Defining commands and arguments for your Code Engine workloads](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cmd-args).

### Creating and running your app with environment variables

{: #app-option-envvar}

You can define and set environment variables as key-value pairs that can be used by your application at run time.
{: shortdesc}

You can define environment variables when you create your application, or when you update an existing application from the console or with the CLI.

For more information about defining environment variables, see [Working with environment variables](https://cloud.ibm.com/docs/codeengine?topic=codeengine-envvar).

Code Engine automatically injects certain environment variables into the app. For more information about automatically injected environment variables, see [Automatically injected environment variables](https://cloud.ibm.com/docs/codeengine?topic=codeengine-inside-env-vars).

### Creating and running your app when using secrets and configmaps

{: #app-option-secconfigmap}

In Code Engine, secrets and configmaps can be consumed by your application by using environment variables.
{: shortdesc}

Both secrets and configmaps are key-value pairs. When mapped to environment variables, the `NAME=VALUE` relationships are set such that the name of the environment variable corresponds to the "key" of each entry in those maps, and the value of the environment variable is the "value" of that key.

Your application can use environment variables to fully reference a configmap (or secret) or reference individual keys in a configmap (or secret).

For more information, see [referencing secrets by using environment variables](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secret#secret-ref) and [referencing configmaps by using environment variables](https://cloud.ibm.com/docs/codeengine?topic=codeengine-configmap#configmap-ref).

## Considerations for application quotas

{: #app-quotas}

When you work with applications, functions, and batch jobs, these resources run within the context of a Code Engine project. Resource quotas are defined on a per project basis, and limits apply for applications, functions, and batch jobs.

For more information about Code Engine limits, see [Limits and quotas for Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-limits).

## Next steps

{: #app-nextsteps}

Now that you are familiar with key concepts of working with Code Engine applications, are you ready to deploy and work with apps? See

* [Deploying app workloads from images in a public registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app).
* [Deploying app workloads from images in IBM Cloud Container Registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-crimage).
* [Deploying app workloads from images in a private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).
* [Deploying your app from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code).
* [Deploying your app from local source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code).

For more information about working with apps, see

* [Application workloads](https://cloud.ibm.com/docs/codeengine?topic=codeengine-ceapplications).
* [Configuring application scaling](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-scale).
* [Configuring custom domain mappings for your app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-domain-mappings).
* [Integrating IBM Cloud services with service bindings](https://cloud.ibm.com/docs/codeengine?topic=codeengine-service-binding).
* Working with [environment variables](https://cloud.ibm.com/docs/codeengine?topic=codeengine-envvar), [configmaps](https://cloud.ibm.com/docs/codeengine?topic=codeengine-configmap), and [secrets](https://cloud.ibm.com/docs/codeengine?topic=codeengine-secret).
* [Subscribing to event producers](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribing-events).
* [Troubleshooting apps](https://cloud.ibm.com/docs/codeengine?topic=codeengine-troubleshoot-apps).

================================

---

name: codeengine-appdeploy-public
title: Deploying app workloads from images in a public registry
description: Deploy your app with Code Engine. You can create an app from the console or with the CLI.
last-updated: 2025-02-07
---

# Deploying app workloads from images in a public registry

{: #deploy-app}

Deploy your app with Code Engine. You can create an app [from the console](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app&interface=ui) or [with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app&interface=cli).
{: shortdesc}

## Deploying an app from the console

{: #deploy-app-console}
{: ui}

Deploy an application with an image from a public registry that does not require credentials with the Code Engine console.
{: shortdesc}

This example references the public `icr.io/codeengine/helloworld` image in [IBM Cloud&reg; Container Registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-crimage). Alternatively, you can also reference an image in a public Docker Hub or an [image in a private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
2. Select **Let's go**.
3. Select **Application**.
4. Enter a name for the application. Use a name for your application that is unique within the project.
5. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). You must have a selected project to deploy an app.
6. Specify a container image for your app, for example, `icr.io/codeengine/helloworld`. If you have your own source code that you want to turn into a container image for the app, see [Planning your build](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build). For more information about the code that is used for this example, see [`helloworld`](https://github.com/IBM/CodeEngine/tree/main/helloworld){: external}.
7. Modify any default values for endpoint or runtime settings. For more information about these options, see [Options for endpoint visibility of apps](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy) and [Options for deploying an app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy).
8. Click **Create**.
9. After the application status changes to **Ready**, you can test the application. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**.

Now that you have deployed your application, you can view information about application revisions and any running instances, and configuration details.  

## Deploying an app with the CLI

{: #deploy-app-cli}
{: cli}

To create and deploy your app with the CLI, use the **`app create`** command. This command requires a name and an image and also allows other optional arguments. For a complete listing of options, see the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.
{: shortdesc}

Before you begin

* Set up your [Code Engine CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-install-cli) environment.
* [Create and work with a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project).

The following **`application create`** command creates and deploys an app that is named `myapp` and uses the container image `icr.io/codeengine/hello`.

```txt
ibmcloud ce application create --name myapp --image icr.io/codeengine/hello
```

{: pre}

Example output

```txt
Creating application 'myapp'...
OK
[...]
Run 'ibmcloud ce application get -n myapp' to check the application status.
OK

https://myapp.4idmmq6xpss.us-south.codeengine.appdomain.cloud
```

{: screen}

The following table summarizes the options that are used with the **`app create`** command in this example. For more information about the command and its options, see the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.

| Option    | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--name`  | The name of the application. Use a name that is unique within the project. This value is required. \n - The name must begin with a lowercase letter. \n - The name must end with a lowercase alphanumeric character. \n - The name must be 55 characters or fewer and can contain letters, numbers, and hyphens (-).                                                                                                                                                                                    |
| `--image` | The name of the image that is used for this application. This value is required. The format is `REGISTRY/NAMESPACE/REPOSITORY:TAG` where `REGISTRY` and `TAG` are optional. If `TAG` is not specified, the default is `latest`. For images in [Docker Hub](https://hub.docker.com/){: external}, you can specify the image with `NAMESPACE/REPOSITORY`, as the default for `Registry` is `docker.io`. For other registries, use `REGISTRY/NAMESPACE/REPOSITORY` or `REGISTRY/NAMESPACE/REPOSITORY:TAG`. |
{: caption="Command description" caption-side="bottom"}

## Next steps

{: #nextsteps-appdeploypub}

* After your app deploys, [access your app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-access-service) through a URL.

* You can create a [custom domain mapping](https://cloud.ibm.com/docs/codeengine?topic=codeengine-domain-mappings) and assign it to your app. For more information about deploying apps across multiple regions with a custom domain name, see [Configuring a highly available application](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-multiple-regions).

* Now that your app is deployed, consider making your apps event-driven. By using event subscriptions, you can trigger your apps by [periodic schedules](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribe-cron#eventing-cron-existing-app) or set your app to react to events such as [file uploads](https://cloud.ibm.com/docs/codeengine?topic=codeengine-eventing-cosevent-producer#obstorage_ev_app) or [Kafka messages](https://cloud.ibm.com/docs/codeengine?topic=codeengine-working-kafkaevent-producer).

After your app is deployed, you can [update your deployed app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app) and its referenced code by using *any* of the following ways, independent of how you created or previously updated your app:

* If you have a container image, per the [Open Container Initiative (OCI) standard](https://opencontainers.org/){: external}, then you need to provide only a reference to the image, which points to the location of your container registry when you deploy your app. You can deploy your app with an image in a [public registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app) or [private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

    If you created your app by using the **`app create`** command and you specified the `--build-source` option to build the container image from local or repository source, and you want to change your app to point to a different container image, you must first remove the association of the build from your app. For example, run `ibmcloud ce application update -n APP_NAME --build-clear`. After you remove the association of the build from your app, you can update the app to reference a different image.
    {: important}

* If you are starting with source code that resides in a Git repository, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** operation. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

* If you are starting with source code that resides on a local workstation, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** CLI command. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from local source code with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

    For example, you might choose to let Code Engine handle the build of your local source while you evolve the development of your source for the app. Then, after the image is matured, you can update the deployed app to reference the specific image that you want. You can repeat this process as needed.

When you deploy your updated app, the latest version of your referenced container image is downloaded and deployed, unless a tag is specified for the image. If a tag is specified for the image, then the tagged image is used for the deployment.

---

name: codeengine-appdeploy-public
title: Deploying app workloads from images in a public registry
description: Deploy your app with Code Engine. You can create an app from the console or with the CLI.
last-updated: 2025-02-07
---

# Deploying app workloads from images in a public registry

{: #deploy-app}

Deploy your app with Code Engine. You can create an app [from the console](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app&interface=ui) or [with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app&interface=cli).
{: shortdesc}

## Deploying an app from the console

{: #deploy-app-console}
{: ui}

Deploy an application with an image from a public registry that does not require credentials with the Code Engine console.
{: shortdesc}

This example references the public `icr.io/codeengine/helloworld` image in [IBM Cloud&reg; Container Registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-crimage). Alternatively, you can also reference an image in a public Docker Hub or an [image in a private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
2. Select **Let's go**.
3. Select **Application**.
4. Enter a name for the application. Use a name for your application that is unique within the project.
5. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). You must have a selected project to deploy an app.
6. Specify a container image for your app, for example, `icr.io/codeengine/helloworld`. If you have your own source code that you want to turn into a container image for the app, see [Planning your build](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build). For more information about the code that is used for this example, see [`helloworld`](https://github.com/IBM/CodeEngine/tree/main/helloworld){: external}.
7. Modify any default values for endpoint or runtime settings. For more information about these options, see [Options for endpoint visibility of apps](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy) and [Options for deploying an app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy).
8. Click **Create**.
9. After the application status changes to **Ready**, you can test the application. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**.

Now that you have deployed your application, you can view information about application revisions and any running instances, and configuration details.  

## Deploying an app with the CLI

{: #deploy-app-cli}
{: cli}

To create and deploy your app with the CLI, use the **`app create`** command. This command requires a name and an image and also allows other optional arguments. For a complete listing of options, see the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.
{: shortdesc}

Before you begin

* Set up your [Code Engine CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-install-cli) environment.
* [Create and work with a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project).

The following **`application create`** command creates and deploys an app that is named `myapp` and uses the container image `icr.io/codeengine/hello`.

```txt
ibmcloud ce application create --name myapp --image icr.io/codeengine/hello
```

{: pre}

Example output

```txt
Creating application 'myapp'...
OK
[...]
Run 'ibmcloud ce application get -n myapp' to check the application status.
OK

https://myapp.4idmmq6xpss.us-south.codeengine.appdomain.cloud
```

{: screen}

The following table summarizes the options that are used with the **`app create`** command in this example. For more information about the command and its options, see the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.

| Option    | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--name`  | The name of the application. Use a name that is unique within the project. This value is required. \n - The name must begin with a lowercase letter. \n - The name must end with a lowercase alphanumeric character. \n - The name must be 55 characters or fewer and can contain letters, numbers, and hyphens (-).                                                                                                                                                                                    |
| `--image` | The name of the image that is used for this application. This value is required. The format is `REGISTRY/NAMESPACE/REPOSITORY:TAG` where `REGISTRY` and `TAG` are optional. If `TAG` is not specified, the default is `latest`. For images in [Docker Hub](https://hub.docker.com/){: external}, you can specify the image with `NAMESPACE/REPOSITORY`, as the default for `Registry` is `docker.io`. For other registries, use `REGISTRY/NAMESPACE/REPOSITORY` or `REGISTRY/NAMESPACE/REPOSITORY:TAG`. |
{: caption="Command description" caption-side="bottom"}

## Next steps

{: #nextsteps-appdeploypub}

* After your app deploys, [access your app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-access-service) through a URL.

* You can create a [custom domain mapping](https://cloud.ibm.com/docs/codeengine?topic=codeengine-domain-mappings) and assign it to your app. For more information about deploying apps across multiple regions with a custom domain name, see [Configuring a highly available application](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-multiple-regions).

* Now that your app is deployed, consider making your apps event-driven. By using event subscriptions, you can trigger your apps by [periodic schedules](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribe-cron#eventing-cron-existing-app) or set your app to react to events such as [file uploads](https://cloud.ibm.com/docs/codeengine?topic=codeengine-eventing-cosevent-producer#obstorage_ev_app) or [Kafka messages](https://cloud.ibm.com/docs/codeengine?topic=codeengine-working-kafkaevent-producer).

After your app is deployed, you can [update your deployed app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app) and its referenced code by using *any* of the following ways, independent of how you created or previously updated your app:

* If you have a container image, per the [Open Container Initiative (OCI) standard](https://opencontainers.org/){: external}, then you need to provide only a reference to the image, which points to the location of your container registry when you deploy your app. You can deploy your app with an image in a [public registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app) or [private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

    If you created your app by using the **`app create`** command and you specified the `--build-source` option to build the container image from local or repository source, and you want to change your app to point to a different container image, you must first remove the association of the build from your app. For example, run `ibmcloud ce application update -n APP_NAME --build-clear`. After you remove the association of the build from your app, you can update the app to reference a different image.
    {: important}

* If you are starting with source code that resides in a Git repository, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** operation. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

* If you are starting with source code that resides on a local workstation, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** CLI command. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from local source code with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

    For example, you might choose to let Code Engine handle the build of your local source while you evolve the development of your source for the app. Then, after the image is matured, you can update the deployed app to reference the specific image that you want. You can repeat this process as needed.

When you deploy your updated app, the latest version of your referenced container image is downloaded and deployed, unless a tag is specified for the image. If a tag is specified for the image, then the tagged image is used for the deployment.

================================

---

name: codeengine-appdeploy-cr
title: Deploying app workloads from images in IBM Cloud Container Registry
description: Deploy your app with Code Engine that uses an image in IBM Cloud&reg; Container Registry. You can create an app from the console or with the CLI.
last-updated: 2024-10-17
---

# Deploying app workloads from images in IBM Cloud Container Registry

{: #deploy-app-crimage}

Deploy your app with Code Engine that uses an image in IBM Cloud&reg; Container Registry. You can create an app from the console or with the CLI.
{: shortdesc}

Before you begin

* You must have an image in IBM Cloud&reg; Container Registry. For more information, see [Getting started with Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-getting-started#getting-started). Or, you can build an image from [repository source](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code) or from [local source](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code).

* Verify that you can access the registry. See [Setting up authorities for container registries](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#authorities-registry).

Interested in configuring your project such that all users of the project can store and access images in Container Registry without having to manually create registry secrets? With sufficient permissions, you can configure this default registry access on a per location (region) basis. If you don't have sufficient permissions to perform these actions, you can use this page to help you understand the required permissions. See [Configuring project-wide settings](https://cloud.ibm.com/docs/codeengine?topic=codeengine-project-integrations).
{: note}

## Deploying an app that references an image in Container Registry with the console

{: #deploy-app-crimage-console}

Deploy an application that uses an image in Container Registry by using the Code Engine console.
{: shortdesc}

Code Engine can automatically pull images from a Container Registry namespace in your account. To pull images from a different Container Registry account or from a private Docker Hub account, see [Deploying application workloads from images in a private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
2. Select **Let's go**.
3. Select **Application**.
4. Enter a name for the application; for example, `helloapp`. Use a name for your application that is unique within the project.
5. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). You must have a selected project to deploy an app.
6. Select **Container image** and click **Configure image**.
7. Select a container registry location, such as `IBM Registry Dallas`.
8. Select `Code Engine managed secret` for **Registry secret**. Because this example uses an image in a Container Registry namespace in your account, Code Engine can automatically create and manage the registry secret for you.
9. Select an existing namespace and name of the image in the registry for the Code Engine app to reference. For example, select `mynamespace` and select the image `hello_repo` in that namespace.
10. Select a value for **Tag**; for example, `latest`.
11. Click **Done**.
12. Modify any runtime settings or environment variables for your app. For more information about these options, see [Options for endpoint visibility of apps](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy) and [Options for deploying an app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy).
13. Click **Create** to create the application.
14. After the application status changes to **Ready**, you can test the application. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**.

Now that you have deployed your application, you can view information about application revisions and any running instances, and configuration details.  

If you want to add registry access to a Container Registry instance that is not in your account, see [Adding access to a Container Registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry).

## Deploying an app with an image in Container Registry with the CLI

{: #deploy-app-crimage-cli}

Deploy an application that uses an image in IBM Cloud&reg; Container Registry with the CLI with the **`ibmcloud ce app create`** command. For a complete listing of options, see the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.
{: shortdesc}

Before you begin

* Set up your [Code Engine CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-install-cli) environment.
* [Create and work with a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project).
* Before you can work with a Code Engine application that references an image in Container Registry, you must first add access to the registry so Code Engine can pull the image when the app is deployed. For information about required permissions for accessing image registries, see [Setting up authorities for image registries](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#authorities-registry).

1. To add access to Container Registry, [create an IAM API key](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#images-your-account-api-key). To create an IBM Cloud IAM API key with the CLI, run the [**`iam api-key-create`**](https://cloud.ibm.com/docs/account?topic=account-ibmcloud_commands_iam#ibmcloud_iam_api_key_create) command. For example, to create an API key called `cliapikey` with a description of `My CLI API key` and save it to a file called `key_file`, run the following command:

    ```txt
    ibmcloud iam api-key-create cliapikey -d "My CLI API key" --file key_file
    ```

    {: pre}

    If you choose to not save your key to a file, you must record the API key that is displayed when you create it. You cannot retrieve it later.
    {: important}

2. After you create your API key, add registry access to Code Engine. To add access to Container Registry with the CLI, use the [**`ibmcloud ce secret create --format registry`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-secret-create) command to create a registry secret. For example, the following command creates registry access to a Container Registry instance called `myregistry`. Note, even though the `--server` and `--username` options are specified in the example command, the default value for the `--server` option is `us.icr.io` and the `--username` option defaults to `iamapikey` when the server is `us.icr.io`.

    ```txt
    ibmcloud ce secret create --format registry --name myregistry --server us.icr.io --username iamapikey --password APIKEY
    ```

    {: pre}

    Example output

    ```txt
    Creating registry secret 'myregistry'...
    OK
    ```

    {: screen}

3. Create your app and reference the `hello_repo` image in Container Registry. For example, use the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command to create the `myhelloapp` app to reference the `us.icr.io/mynamespace/hello_repo` by using the `myregistry` access information.

    ```txt
    ibmcloud ce app create --name myhelloapp --image us.icr.io/mynamespace/hello_repo --registry-secret myregistry
    ```

    {: pre}

    The format of the name of the image for this application is `REGISTRY/NAMESPACE/REPOSITORY:TAG` where `REGISTRY` and `TAG` are optional. If `REGISTRY` is not specified, the default is `docker.io`. If `TAG` is not specified, the default is `latest`.
    {: important}

4. After your app deploys, you can access the app. To obtain the URL of your app, run `ibmcloud ce app get --name myhelloapp --output url`. When you curl the `myhelloapp` app, `Hello World` is returned.

    ```txt
    curl https://myhelloapp.abcdabcdhye.us-south.codeengine.appdomain.cloud
    ```

    {: pre}

## Next steps

{: #nextsteps-appdeploycr}

* After your app deploys, [access your app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-access-service) through a URL.

* You can create a [custom domain mapping](https://cloud.ibm.com/docs/codeengine?topic=codeengine-domain-mappings) and assign it to your app. For more information about deploying apps across multiple regions with a custom domain name, see [Configuring a highly available application](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-multiple-regions).

* Now that your app is deployed, consider making your apps event-driven. By using event subscriptions, you can trigger your apps by [periodic schedules](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribe-cron#eventing-cron-existing-app) or set your app to react to events such as [file uploads](https://cloud.ibm.com/docs/codeengine?topic=codeengine-eventing-cosevent-producer#obstorage_ev_app) or [Kafka messages](https://cloud.ibm.com/docs/codeengine?topic=codeengine-working-kafkaevent-producer).

After your app is deployed, you can [update your deployed app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app) and its referenced code by using *any* of the following ways, independent of how you created or previously updated your app:

* If you have a container image, per the [Open Container Initiative (OCI) standard](https://opencontainers.org/){: external}, then you need to provide only a reference to the image, which points to the location of your container registry when you deploy your app. You can deploy your app with an image in a [public registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app) or [private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

    If you created your app by using the **`app create`** command and you specified the `--build-source` option to build the container image from local or repository source, and you want to change your app to point to a different container image, you must first remove the association of the build from your app. For example, run `ibmcloud ce application update -n APP_NAME --build-clear`. After you remove the association of the build from your app, you can update the app to reference a different image.
    {: important}

* If you are starting with source code that resides in a Git repository, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** operation. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

* If you are starting with source code that resides on a local workstation, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** CLI command. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from local source code with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

    For example, you might choose to let Code Engine handle the build of your local source while you evolve the development of your source for the app. Then, after the image is matured, you can update the deployed app to reference the specific image that you want. You can repeat this process as needed.

When you deploy your updated app, the latest version of your referenced container image is downloaded and deployed, unless a tag is specified for the image. If a tag is specified for the image, then the tagged image is used for the deployment.

================================

---

name: codeengine-appdeploy-private
title: Deploying app workloads from images in a private registry
description: Deploy your app with Code Engine that uses an image in a private registry such as private Docker Hub. You can create an app from the console or with the CLI.
last-updated: 2025-07-24
---

# Deploying app workloads from images in a private registry

{: #deploy-app-private}

Deploy your app with Code Engine that uses an image in a private registry such as private Docker Hub. You can create an app from the console or with the CLI.
{: shortdesc}

Before you begin

* To pull images from a private registry, you must first create a private registry. For example, to create a private Docker Hub registry, see [Docker Hub documentation](https://docs.docker.com/docker-hub/repos/){: external}.
* After you create a private registry, [push an image to it](https://docs.docker.com/docker-hub/repos/#pushing-a-docker-container-image-to-docker-hub){: external}.
* You can also set up an access token. By using an access token, you can more easily grant and revoke access to your Docker Hub account without requiring a password change. For more information about access tokens and Docker Hub, see [Create and manage access tokens](https://docs.docker.com/security/access-tokens/){: external}.

## Deploying an app that references an image in a private registry with the console

{: #deploy-app-private-console}

Deploy an application that uses an image in a private registry with the Code Engine console.
{: shortdesc}

Before you can work with a Code Engine application that references an image in a private registry, you must first add access to the registry, pull the image, and then deploy it.

1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
2. Select **Let's go**.
3. Select **Application**.
4. Enter a name for the application; for example, `helloapp`. Use a name for your application that is unique within the project.
5. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). You must have a selected project to deploy an app.
6. Select **Container image** and click **Configure image**.
7. Enter `docker.io` for **Registry server**.
8. For **Registry secret**, select **Create registry secret**.
9. From the Create registry secret page, choose your registry source. For example, **Docker Hub**.
10. Enter a username. For Docker Hub, it is your Docker ID.
11. Enter the password. For Docker Hub, you can use your Docker Hub password or an access token. For more information about access tokens and Docker Hub, see [Create and manage access tokens](https://docs.docker.com/security/access-tokens/){: external}.
12. Click **Create** to add a registry secret for Code Engine.
13. From the Configure image page, the registry secret that was added is listed. Select the registry secret for your image.
14. Select the namespace and name of the image in Docker Hub for the Code Engine app to reference. For example, select `mynamespace` and select the image `hello_repo` in that namespace.
15. Select a value for **Tag**; for example, `latest`.
16. Click **Done**. You selected your image in the registry to reference from your app.
17. Modify any runtime settings or environment variables for your app. For more information about these options, see [Options for endpoint visibility of apps](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy) and [Options for deploying an app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy).
18. From the Create application page, click **Create**.
19. After the application status changes to **Ready**, you can test the application. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**.  

Now that you have deployed your application, you can view information about application revisions and any running instances, and configuration details.  

If you want to add registry access before you create an app, see [Adding access to a private container registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry).

## Deploying an app with an image from a private registry with CLI

{: #deploy-app-private-cli}

Deploy an application that uses an image in a container registry with the CLI with the **`ibmcloud ce app create`** command.
{: shortdesc}

Before you begin

* Set up your [Code Engine CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-install-cli) environment.
* [Create and work with a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project).

Before you can work with a Code Engine application that references an image in a private registry, you must first add access to the registry, pull the image, and then deploy it.

1. To pull images from a private registry, you must first create a private registry. For example, to create a private Docker Hub registry, see [Docker Hub documentation](https://docs.docker.com/docker-hub/repos/){: external}. After you create a private registry, [push an image to it](https://docs.docker.com/docker-hub/repos/#pushing-a-docker-container-image-to-docker-hub){: external}. You can also set up an access token. By using an access token, you can more easily grant and revoke access to your Docker Hub account without requiring a password change. For more information about access tokens and Docker Hub, see [Create and manage access tokens](https://docs.docker.com/security/access-tokens/){: external}.

2. Add access to your private registry to pull images. To add access to a private registry with the CLI, use the [**`ibmcloud ce secret create --format registry`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-secret-create) command to create a registry secret. For example, the following command creates registry access to a Docker Hub registry called `privatedocker` that is at `'https://index.docker.io/v1/'` and uses your username and password.

    ```txt
    ibmcloud ce secret create --format registry --name privatedocker --server 'https://index.docker.io/v1/' --username <Docker_User_Name> --password <Password>
    ```

    {: pre}

    Example output

    ```txt
    Creating registry secret 'privatedocker'...
    OK
    ```

    {: screen}

3. Create your app and reference the image in your private Docker Hub registry. For example, create the `myhelloapp` app to reference the `docker.io/privaterepo/helloworld` by using the `privatedocker` access information.

    ```txt
    ibmcloud ce app create --name myhelloapp --image docker.io/privaterepo/helloworld --registry-secret privatedocker
    ```

    {: pre}

    The format of the name of the image for this application is `REGISTRY/NAMESPACE/REPOSITORY:TAG` where `REGISTRY` and `TAG` are optional. If `REGISTRY` is not specified, the default is `docker.io`. If `TAG` is not specified, the default is `latest`.
    {: important}

4. After your app deploys, you can access the app. To obtain the URL of your app, run `ibmcloud ce app get --name myhelloapp --output url`. When you curl the `myhelloapp` app, `Hello World` is returned.

    ```txt
    curl https://myhelloapp.abcdabcdhye.us-south.codeengine.appdomain.cloud
    ```

    {: pre}

## Next steps

{: #nextsteps-appdeploypriv}

* After your app deploys, [access your app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-access-service) through a URL.

* You can create a [custom domain mapping](https://cloud.ibm.com/docs/codeengine?topic=codeengine-domain-mappings) and assign it to your app. For more information about deploying apps across multiple regions with a custom domain name, see [Configuring a highly available application](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-multiple-regions).

* Now that your app is deployed, consider making your apps event-driven. By using event subscriptions, you can trigger your apps by [periodic schedules](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribe-cron#eventing-cron-existing-app) or set your app to react to events such as [file uploads](https://cloud.ibm.com/docs/codeengine?topic=codeengine-eventing-cosevent-producer#obstorage_ev_app) or [Kafka messages](https://cloud.ibm.com/docs/codeengine?topic=codeengine-working-kafkaevent-producer).

After your app is deployed, you can [update your deployed app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app) and its referenced code by using *any* of the following ways, independent of how you created or previously updated your app:

* If you have a container image, per the [Open Container Initiative (OCI) standard](https://opencontainers.org/){: external}, then you need to provide only a reference to the image, which points to the location of your container registry when you deploy your app. You can deploy your app with an image in a [public registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app) or [private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

    If you created your app by using the **`app create`** command and you specified the `--build-source` option to build the container image from local or repository source, and you want to change your app to point to a different container image, you must first remove the association of the build from your app. For example, run `ibmcloud ce application update -n APP_NAME --build-clear`. After you remove the association of the build from your app, you can update the app to reference a different image.
    {: important}

* If you are starting with source code that resides in a Git repository, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** operation. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

* If you are starting with source code that resides on a local workstation, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** CLI command. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from local source code with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

    For example, you might choose to let Code Engine handle the build of your local source while you evolve the development of your source for the app. Then, after the image is matured, you can update the deployed app to reference the specific image that you want. You can repeat this process as needed.

When you deploy your updated app, the latest version of your referenced container image is downloaded and deployed, unless a tag is specified for the image. If a tag is specified for the image, then the tagged image is used for the deployment.

================================

---

name: codeengine-appdeploy-source
title: Deploying your app from repository source code
description: You can deploy your application directly from source code that is located in a Git repository with the IBM Cloud&reg; Code Engine console and CLI. Find out what advantages are available when you build your image with Code Engine.
last-updated: 2025-07-18
---

# Deploying your app from repository source code

{: #app-source-code}

You can deploy your application directly from source code that is located in a Git repository with the IBM Cloud&reg; Code Engine console and CLI. Find out what advantages are available when you [build your image with Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-faqs#dockerbld-cebuild).
{: shortdesc}

## Deploying your app from repository source code from the console

{: #deploy-app-source-code}

You can deploy your application directly from source code with the console.
{: shortdesc}

Before you begin, [plan for your build](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build). You can also find [tips for creating a Dockerfile](https://cloud.ibm.com/docs/codeengine?topic=codeengine-dockerfile).

Code Engine can automatically push (upload) images to IBM Cloud&reg; Container Registry namespaces in your account and even create a namespace for you. To upload images to a different Container Registry account or to a private Docker Hub account, see [Accessing container registries](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry).

For more information about required permissions for accessing image registries, see [Setting up authorities for image registries](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#authorities-registry).

1. Open the [Code Engine](https://cloud.ibm.com/codeengine/overview){: external} console.
2. Select **Let's go**.
3. Select **Application**.
4. Enter a name for the application. Use a name for your application that is unique within the project.
5. Select a project from the list of available projects. You can also [create a new one](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project#create-a-project). Note that you must have a selected project to deploy an app.
6. Select **Source code**.
7. Click **Specify build details**.
8. Select a source repository, for example `https://github.com/IBM/CodeEngine`. Because we are using sample source that does not require credentials, select `None` for the Code repo access. You can optionally provide a branch name. If you do not provide a branch name and you leave the field empty, Code Engine automatically uses the default branch of the specified repository. Click **Next**.  
9. Select a strategy for your build and resources for your build. For more information about build options, see [Planning your build](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build). Click **Next**.
10. Select a container registry location, such as `IBM Registry Dallas` to specify where to store the image of your build output. If your registry is private, you must [set up access](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry) to it.
11. Provide registry information about where to store the image of your build output. Select an existing **Registry secret** or create a new one. If you are building your image to a Container Registry instance that is in your account, you can select `Code Engine managed secret` and let Code Engine create and manage the secret for you.
12. Select a namespace, name, and a tag for your image. If you are building your image to an IBM Cloud Container Registry instance that is in your account, you can select an existing namespace or let Code Engine create and manage the namespace for you.
13. Click **Done**.
14. Modify any runtime settings or environment variables for your app. For more information about these options, see [Options for endpoint visibility of apps](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy) and [Options for deploying an app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy).
15. Click **Create**.
16. After your build run is submitted, the built container image is sent to Container Registry and then your application pulls the image and deploys for you. After the application status changes to **Ready**, you can test the application. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**.  

Build runs that complete are ultimately automatically deleted. When your build run is based on build configuration, this build run is deleted after 3 hours if the build run is successful. If the build run is not successful, this build run is deleted after 48 hours.  
{: note}

Now that you have deployed your application, you can view information about application revisions and any running instances, and configuration details.  

## Deploying your app from repository source code with the CLI

{: #deploy-app-source-code-cli}

You can deploy your application directly from repository source code with the CLI. Use the **`app create`** command to both build an image from your Git repository source, and deploy your application to reference this built image.
{: shortdesc}

Before you begin

* Set up your [Code Engine CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-install-cli) environment.
* [Create and work with a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project).

In this scenario, Code Engine builds an image from your Git repository source, automatically uploads the image to your container registry, and then creates and deploys your app to reference this built image. You need to provide only a name for the app and the URL to the Git repository if the image is to be located in an IBM Cloud&reg; Container Registry account. In this case, Code Engine manages the namespace for you. However, if you want to use a different container registry, then you must specify the image and a registry secret for that container registry. For a complete listing of options, see the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.  

For more information about required permissions for accessing image registries, see [Setting up authorities for image registries](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#authorities-registry).

The following example **`application create`** command creates and deploys the `myapp` app, which references an image that is built from the `https://github.com/IBM/CodeEngine` build source. This command automatically builds the image and uploads the image to an IBM Cloud&reg; Container Registry namespace in your account and the application references this built image. By specifying the `--build-context-dir` option, the build uses the source in the `helloworld` directory. This example command uses the default `dockerfile` strategy, and the default `medium` build size. Because the branch name of the repository is not specified with the `--build-commit` option, Code Engine automatically uses the default branch of the specified repository.  

```txt
ibmcloud ce application create --name myapp --build-source https://github.com/IBM/CodeEngine --build-context-dir helloworld
```

{: pre}

Example output

```txt
Creating application 'myapp'...
Submitting build run 'myapp-run-220411-13abcdefg'...
Creating image 'private.us.icr.io/ce--abcde-4svg40kna19/app-myapp:220411-1756-if8jv'...
Waiting for build run to complete...
Build run status: 'Running'
Build run completed successfully.
Run 'ibmcloud ce buildrun get -n myapp-run-220411-13abcdefg' to check the build run status.
Waiting for application 'myapp' to become ready.
Configuration 'myapp' is waiting for a Revision to become ready.
Ingress has not yet been reconciled.
Waiting for load balancer to be ready.
Run 'ibmcloud ce application get -n myapp' to check the application status.
OK

https://myapp.4svg40kna19.us-south.codeengine.appdomain.cloud
```

{: screen}

Notice the output of the **`application create`** command provides information on the progression of the build run before the app is created and deployed.
{: tip}

In this example, the built image is uploaded to the `ce--abcde-4svg40kna19` namespace in Container Registry.

The following table summarizes the options that are used with the **`app create`** command in this example. For more information about the command and its options, see the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.

| Option                | Description                                                                                                                                                                                                                                                                                                          |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `--name`              | The name of the application. Use a name that is unique within the project. This value is required. \n - The name must begin with a lowercase letter. \n - The name must end with a lowercase alphanumeric character. \n - The name must be 63 characters or fewer and can contain letters, numbers, and hyphens (-). |
| `--build-source`      | The URL of the Git repository that contains your source code; for example, `https://github.com/IBM/CodeEngine`.                                                                                                                                                                                                      |
| `--build-context-dir` | The directory in the repository that contains the buildpacks file or the Dockerfile. This value is optional.                                                                                                                                                                                                         |
{: caption="Command description" caption-side="bottom"}

The following output shows the result of the **`application get`** command for this example, including information about the build.

Example output

```txt
[...]
Name:          myapp  
ID:            abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f  
Project Name:  myproject  
Project ID:    01234567-abcd-abcd-abcd-abcdabcd1111 
Age:           2d15h
Created:       2022-04-14T16:10:11-04:00
URL:                https://myapp.4svg40kna19.us-south.codeengine.appdomain.cloud
Cluster Local URL:  http://myapp.4svg40kna19.svc.cluster.local
Console URL:        https://cloud.ibm.com/codeengine/project/us-south/01234567-abcd-abcd-abcd-abcdabcd1111/application/myapp/configuration
Status Summary:  Application deployed successfully

Environment Variables:    
    Type     Name             Value  
    Literal  CE_API_BASE_URL  https://api.private.us-south.codeengine.cloud.ibm.com
    Literal  CE_APP           myapp  
    Literal  CE_DOMAIN        us-south.codeengine.appdomain.cloud  
    Literal  CE_PROJECT_ID    abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f
    Literal  CE_REGION        us-south  
    Literal  CE_SUBDOMAIN     abcdabcdab
Image:                  private.us.icr.io/ce--27fe9-4svg40kna19/app-myapp:220414-2010-sqsoj
Resource Allocation:
  CPU:                1
  Ephemeral Storage:  400M
  Memory:             4G
Registry Secrets:
  ce-auto-icr-private-us-south

Revisions:
  myapp-00001:
    Age:                23m
    Latest:             true
    Traffic:            100%
    Image:              private.us.icr.io/ce--27fe9-4svg40kna19/app-myapp:220414-2010-sqsoj (pinned to 86944c)  
    Running Instances:  0

Runtime:
  Concurrency:    100
  Maximum Scale:  10
  Minimum Scale:  0
  Timeout:        300

Build Information:
  Build Run Name:     myapp-run-220414-161009244
  Build Type:         git
  Build Strategy:     dockerfile-medium
  Timeout:            600
  Source:             https://github.com/IBM/CodeEngine
  Context Directory:  helloworld
  Dockerfile:         Dockerfile

  Build Run Summary:  Succeeded
  Build Run Status:   Succeeded
  Build Run Reason:   All Steps have completed executing
  Run 'ibmcloud ce buildrun get -n myapp-run-220414-161009244' for details.
[...]
```

{: screen}

Now that your app is created and deployed from repository source code, you can update the app to meet your needs by using the [**`ibmcloud ce app update`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-update) command. For more information about updating apps, see [Updating your app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app). If you want to update your source to use with your app, you must provide the `--build-source` option on the **`application update`** command.

When your app is deployed from repository source code or from [local source](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code) with the CLI, the resulting build run is not based on a build configuration. Build runs that complete are ultimately automatically deleted. Build runs that are not based on a build configuration are deleted after 1 hour if the build run is successful. If the build run is not successful, this build run is deleted after 24 hours. You can only display information about this build run with the CLI. You cannot view this build run in the console.
{: note}

## Next steps

{: #nextsteps-appdeploysource}

* After your app deploys, [access your app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-access-service) through a URL.

* You can create a [custom domain mapping](https://cloud.ibm.com/docs/codeengine?topic=codeengine-domain-mappings) and assign it to your app. For more information about deploying apps across multiple regions with a custom domain name, see [Configuring a highly available application](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-multiple-regions).

* Now that your app is deployed, consider making your apps event-driven. By using event subscriptions, you can trigger your apps by [periodic schedules](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribe-cron#eventing-cron-existing-app) or set your app to react to events such as [file uploads](https://cloud.ibm.com/docs/codeengine?topic=codeengine-eventing-cosevent-producer#obstorage_ev_app) or [Kafka messages](https://cloud.ibm.com/docs/codeengine?topic=codeengine-working-kafkaevent-producer).

After your app is deployed, you can [update your deployed app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app) and its referenced code by using *any* of the following ways, independent of how you created or previously updated your app:

* If you have a container image, per the [Open Container Initiative (OCI) standard](https://opencontainers.org/){: external}, then you need to provide only a reference to the image, which points to the location of your container registry when you deploy your app. You can deploy your app with an image in a [public registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app) or [private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

    If you created your app by using the **`app create`** command and you specified the `--build-source` option to build the container image from local or repository source, and you want to change your app to point to a different container image, you must first remove the association of the build from your app. For example, run `ibmcloud ce application update -n APP_NAME --build-clear`. After you remove the association of the build from your app, you can update the app to reference a different image.
    {: important}

* If you are starting with source code that resides in a Git repository, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** operation. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

* If you are starting with source code that resides on a local workstation, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** CLI command. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from local source code with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

    For example, you might choose to let Code Engine handle the build of your local source while you evolve the development of your source for the app. Then, after the image is matured, you can update the deployed app to reference the specific image that you want. You can repeat this process as needed.

When you deploy your updated app, the latest version of your referenced container image is downloaded and deployed, unless a tag is specified for the image. If a tag is specified for the image, then the tagged image is used for the deployment.

================================

---

name: codeengine-appdeploy-localsource
title: Deploying your app from local source code with the CLI
description: You can deploy your application directly from source code on your local workstation with the IBM Cloud&reg; Code Engine CLI. Use the **`app create`** command to both build an image from your local source, and deploy your application to reference this built image.
last-updated: 2025-07-18
---

# Deploying your app from local source code with the CLI

{: #app-local-source-code}

You can deploy your application directly from source code on your local workstation with the IBM Cloud&reg; Code Engine CLI. Use the **`app create`** command to both build an image from your local source, and deploy your application to reference this built image.
{: shortdesc}

When you submit a build that pulls code from a local directory, your source code is packed into an archive file. Code Engine automatically uploads the image to an IBM Cloud&reg; Container Registry namespace in your account, and then creates and deploys your app to reference this built image. Note that you can only target IBM Cloud Container Registry for your local builds. The source image is created in the same namespace as your build image. For this scenario, you need to provide only a name for the app and the path to the local source. For a complete listing of options, see the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.  

For information about required permissions for accessing image registries, see [Setting up authorities for image registries](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#authorities-registry).

You can choose to ignore certain file patterns from within your source code by using the `.ceignore` file, which behaves similarly to a `.gitignore` file. For example, entries for a `.ceignore` file for a node.js application might include `node_modules` and `.npm`. For more sample file patterns to ignore, see the [GitHub .gitignore repository](https://github.com/github/gitignore){: external}.

The IBM Cloud&reg; Container Registry is required for this scenario.
{: important}

Before you begin

* Set up your [Code Engine CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-install-cli) environment.
* [Create and work with a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-manage-project).

Before you work with local source, make sure that your source is in an accessible location on your local workstation.  

This example uses the `https://github.com/IBM/CodeEngine` samples; in particular, the `helloworld` sample.

1. Download the `https://github.com/IBM/CodeEngine` sample source to your local workstation with the following command.

    ```txt
    git clone https://github.com/IBM/CodeEngine
    ```

    {: pre}

2. Change to the `CodeEngine\helloworld` directory.

3. From the `CodeEngine\helloworld` directory, create and deploy the `myapp-local` app, which uses an image that is built from the `CodeEngine\helloworld` source on your local workstation. This command automatically builds and pushes the image to a Container Registry namespace in your account. If you do not have an existing Container Registry namespace, Code Engine automatically creates one for you.

    ```txt
    ibmcloud ce application create --name myapp-local --build-source .
    ```

    {: pre}

    The `.` indicates the build source is located in your current working directory.
    {: note}

    Example output

    ```txt
    Creating application 'myapp-local'...
    Packaging files to upload from source path '.'...
    Submitting build run 'myapp-local-run-220414-171750199'...
    Creating image 'private.us.icr.io/ce--abcde-glxo4kabcde/app-myapp-local:220414-2117-rdaga'...
    Waiting for build run to complete...
    Build run status: 'Running'
    Build run completed successfully.
    Run 'ibmcloud ce buildrun get -n myapp-local-run-220414-171750199' to check the build run status.
    Waiting for application 'myapp-local' to become ready.
    Configuration 'myapp-local' is waiting for a Revision to become ready.
    Ingress has not yet been reconciled.
    Waiting for load balancer to be ready.
    Run 'ibmcloud ce application get -n myapp-local' to check the application status.
    OK

    https://myapp-local.glxo4kabcde.us-south.codeengine.appdomain.cloud
    ```

    {: screen}

    Notice the output of the **`application create`** command provides information on the progression of the build run before the app is created and deployed.
    {: tip}

    In this example, the built image is uploaded to the `ce--abcde-glxo4kabcde` namespace in Container Registry.

    The following table summarizes the options that are used with the **`app create`** command in this example. For more information about the command and its options, see the [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.

    | Option           | Description                                                                                                                                                                                                                                                                                                          |
    | ---------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
    | `--name`         | The name of the application. Use a name that is unique within the project. This value is required. \n - The name must begin with a lowercase letter. \n - The name must end with a lowercase alphanumeric character. \n - The name must be 63 characters or fewer and can contain letters, numbers, and hyphens (-). |
    | `--build-source` | The path to the local source.                                                                                                                                                                                                                                                                                        |
    {: caption="Command description" caption-side="bottom"}

4. Use the **`application get`** command to display information about your app, including information about the build.

    ```txt
    ibmcloud ce application get --name myapp-local
    ```

    {: pre}

    Example output

    ```txt
    [...]
    Name:          myapp-local
    ID:            abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f  
    Project Name:  myproject  
    Project ID:    01234567-abcd-abcd-abcd-abcdabcd1111 
    Age:           2d15h
    Created:       2022-04-14T16:10:11-04:00
    URL:                https://myapp-local.Sta.us-south.codeengine.appdomain.cloud
    Cluster Local URL:  http://myapp-local.glxo4kabcde.svc.cluster.local
    Console URL:        https://cloud.ibm.com/codeengine/project/us-south/01234567-abcd-abcd-abcd-abcdabcd1111/application/myapp-local/configuration
    Status Summary:  Application deployed successfully

    Environment Variables:    
        Type     Name             Value  
        Literal  CE_API_BASE_URL  https://api.private.us-south.codeengine.cloud.ibm.com
        Literal  CE_APP           myapp  
        Literal  CE_DOMAIN        us-south.codeengine.appdomain.cloud  
        Literal  CE_PROJECT_ID    abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f
        Literal  CE_REGION        us-south  
        Literal  CE_SUBDOMAIN     abcdabcdab
    Image:                  private.us.icr.io/ce--abcde-glxo4kabcde/app-myapp-local:220414-2010-sqsoj
    Resource Allocation:
      CPU:                1
      Ephemeral Storage:  400M
      Memory:             4G
    Registry Secrets:
      ce-auto-icr-private-us-south

    Revisions:
      myapp-local-00001:
        Age:                23m
        Latest:             true
        Traffic:            100%
        Image:              private.us.icr.io/ce--abcde-glxo4kabcde/app-myapp-local:220414-2010-sqsoj (pinned to 86944c)  
        Running Instances:  0

    Runtime:
      Concurrency:    100
      Maximum Scale:  10
      Minimum Scale:  0
      Timeout:        300

    Build Information:
      Build Run Name:     myapp-local-run-220414-161009244
      Build Type:         git
      Build Strategy:     dockerfile-medium
      Timeout:            600
      Source:             https://github.com/IBM/CodeEngine
      Context Directory:  helloworld
      Dockerfile:         Dockerfile

      Build Run Summary:  Succeeded
      Build Run Status:   Succeeded
      Build Run Reason:   All Steps have completed executing
      Run 'ibmcloud ce buildrun get -n myapp-local-run-220414-161009244' for details.
    [...]
    ```

    {: screen}

Now that your app is created and deployed from local source code, you can update the app to meet your needs by using the [**`ibmcloud ce app update`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-update) command. For more information about updating apps, see [Updating your app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app). If you want to update your source to use with your app, you must provide the `--build-source` option on the **`application update`** command.

Instead of building your image from local source and deploying your app with a single command, you can choose to build from local source first *before* you deploy your app. See [Creating a build configuration that pulls source from a local workstation](https://cloud.ibm.com/docs/codeengine?topic=codeengine-build-config-local).

When your app is deployed from local source or from [repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code) from the CLI, the resulting build run is not based on a build configuration. Build runs that complete are ultimately automatically deleted.  Build runs that are not based on a build configuration are deleted after 1 hour if the build run is successful. If the build run is not successful, this build run is deleted after 24 hours. You can only display information about this build run with the CLI. You cannot view this build run in the console.  
{: note}

## Next steps

{: #nextsteps-app-localdeploysource}

* After your app deploys, [access your app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-access-service) through a URL.

* You can create a [custom domain mapping](https://cloud.ibm.com/docs/codeengine?topic=codeengine-domain-mappings) and assign it to your app. For more information about deploying apps across multiple regions with a custom domain name, see [Configuring a highly available application](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-multiple-regions).

* Now that your app is deployed, consider making your apps event-driven. By using event subscriptions, you can trigger your apps by [periodic schedules](https://cloud.ibm.com/docs/codeengine?topic=codeengine-subscribe-cron#eventing-cron-existing-app) or set your app to react to events such as [file uploads](https://cloud.ibm.com/docs/codeengine?topic=codeengine-eventing-cosevent-producer#obstorage_ev_app) or [Kafka messages](https://cloud.ibm.com/docs/codeengine?topic=codeengine-working-kafkaevent-producer).

After your app is deployed, you can [update your deployed app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app) and its referenced code by using *any* of the following ways, independent of how you created or previously updated your app:

* If you have a container image, per the [Open Container Initiative (OCI) standard](https://opencontainers.org/){: external}, then you need to provide only a reference to the image, which points to the location of your container registry when you deploy your app. You can deploy your app with an image in a [public registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app) or [private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

    If you created your app by using the **`app create`** command and you specified the `--build-source` option to build the container image from local or repository source, and you want to change your app to point to a different container image, you must first remove the association of the build from your app. For example, run `ibmcloud ce application update -n APP_NAME --build-clear`. After you remove the association of the build from your app, you can update the app to reference a different image.
    {: important}

* If you are starting with source code that resides in a Git repository, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** operation. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

* If you are starting with source code that resides on a local workstation, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** CLI command. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from local source code with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

    For example, you might choose to let Code Engine handle the build of your local source while you evolve the development of your source for the app. Then, after the image is matured, you can update the deployed app to reference the specific image that you want. You can repeat this process as needed.

When you deploy your updated app, the latest version of your referenced container image is downloaded and deployed, unless a tag is specified for the image. If a tag is specified for the image, then the tagged image is used for the deployment.

================================

---

name: codeengine-appdeploy-access
title: Accessing your app
description: After your app deploys, you can access it through a URL.
last-updated: 2025-07-18
---

# Accessing your app

{: #access-service}

After your app deploys, you can access it through a URL.
{: shortdesc}

From the console, your application URL is available from the components page and on the application details page.

From the CLI, run the [**`ibmcloud ce app get`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-get) command to find the URL of your app. To have the command output only the URL of the app, specify the `--output url` option with the **`app get`** command.

## Access details about your app

{: #access-app-details}

Find details about your app from the console or with the CLI.
{: shortdesc}

Code Engine has quotas for apps and revisions of the apps within a project and app limits, such as memory and CPU. For more information about Code Engine limits, see [Limits and quotas for Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-limits).
{: important}

### Accessing app details from the console

{: #access-appdetails-ui}

Details about your app are available in the console from the app page by clicking the name of your app from the list of applications within your project. You can view information about the running instances of your application and its revisions, configuration details, and endpoint settings of the app.

### Accessing app details with the CLI

{: #access-appdetails-cli}

To view details of your app with the CLI, use the **`app get`** command. For a complete listing of options, see the [**`ibmcloud ce app get`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-get) command.
{: shortdesc}

For example, the following **`app get`** command displays details about the `myapp` app.

```txt
ibmcloud ce app get --name myapp
```

{: pre}

Example output

```txt
[...]
OK

Name:               myapp
ID:                 abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f
Project Name:       myproject
Project ID:         01234567-abcd-abcd-abcd-abcdabcd1111
Age:                2m4s
Created:            2021-09-09T14:01:02-04:00
URL:                https://myapp.abcdabcdabc.us-south.codeengine.appdomain.cloud
Cluster Local URL:  http://myapp.abcdabcdabc.svc.cluster.local
Console URL:        https://cloud.ibm.com/codeengine/project/us-south/01234567-abcd-abcd-abcd-abcdabcd1111/application/myapp/configuration
Status Summary:     Application deployed successfully

Environment Variables:    
    Type     Name             Value  
    Literal  CE_API_BASE_URL  https://api.private.us-south.codeengine.cloud.ibm.com
    Literal  CE_APP           myapp  
    Literal  CE_DOMAIN        us-south.codeengine.appdomain.cloud  
    Literal  CE_PROJECT_ID    abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f
    Literal  CE_REGION        us-south  
    Literal  CE_SUBDOMAIN     abcdabcdab

Image:                icr.io/codeengine/hello
Resource Allocation:
    CPU:                1
    Ephemeral Storage:  400M
    Memory:             4G

Revisions:
    myapp-00001:
        Age:                100s
    Latest:             true
    Traffic:            100%
    Image:              icr.io/codeengine/hello (pinned to d6fd55)
    Running Instances:  1

Runtime:
    Concurrency:    100
    Maximum Scale:  10
    Minimum Scale:  0
    Timeout:        300

Conditions:
    Type                 OK    Age  Reason
    ConfigurationsReady  true  86s
    Ready                true  60s
    RoutesReady          true  60s

Events:
    Type    Reason   Age   Source              Messages
    Normal  Created  102s  service-controller  Created Configuration "myapp"
    Normal  Created  102s  service-controller  Created Route "myapp"

Instances:
    Name                                    Revision     Running  Status       Restarts  Age
    myapp-00001-deployment-699c45ddd-c25rm  myapp-00001  1/2      Terminating  0         102s
```

{: screen}

## Application status

{: #app-status}

The following table shows the possible status that your application might have.

| Status                | Description                                                                                                                                                              |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Deploying             | The application is deploying. Deployment time includes the time before the app is scheduled as well as time to download images over the network, which can take a while. |
| Ready                 | The application is deployed and ready to use.                                                                                                                            |
| Ready (with warnings) | The deployment of a new application revision failed, but the original deployment is available.                                                                           |
| Failed                | The application deployment terminated, and at least one instance terminated in failure. The instance either exited with nonzero status or was terminated by the system.  |
| Unknown               | For some reason, the state of the application cannot not be obtained, typically due to an error in communicating with the host.                                          |
{: caption="Application status" caption-side="bottom"}

---

name: codeengine-appdeploy-update
title: Updating your app
description: An application contains one or more *revisions*. A revision represents an immutable version of the configuration properties of the application. Each update of an application configuration property creates a new revision of the application.
last-updated: 2025-07-18
---

# Updating your app

{: #update-app}

An application contains one or more *revisions*. A revision represents an immutable version of the configuration properties of the application. Each update of an application configuration property creates a new revision of the application.
{: shortdesc}

When you modify an application and deploy the application with the changes, or [redeploy the application without changes to its configuration settings](#update-app-nochange), these actions deploy a new revision of the application. When you deploy (or redeploy) an application revision, Code Engine uses any changed configuration settings, and gets any updated container image, secret, or configmap that is referenced by the application.

For more information about deploying applications, such as specifying [valid vCPU and memory combinations](https://cloud.ibm.com/docs/codeengine?topic=codeengine-mem-cpu-combo), defining commands and arguments, environment variables, secrets, or configmaps, see [Options for deploying an app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#optionsdeploy).

Code Engine has a quota for the number of apps and app revisions in a project. For more information about limits for projects, see [Project quotas](https://cloud.ibm.com/docs/codeengine?topic=codeengine-limits#project_quotas). Code Engine retains only the latest inactive revision of your application in addition to your active app revision. Older revisions are deleted.
{: important}

You can [update your deployed app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-update-app) and its referenced code by using *any* of the following ways, independent of how you created or previously updated your app:

* If you have a container image, per the [Open Container Initiative (OCI) standard](https://opencontainers.org/){: external}, then you need to provide only a reference to the image, which points to the location of your container registry when you deploy your app. You can deploy your app with an image in a [public registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app) or [private registry](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-private).

    If you created your app by using the **`app create`** command and you specified the `--build-source` option to build the container image from local or repository source, and you want to change your app to point to a different container image, you must first remove the association of the build from your app. For example, run `ibmcloud ce application update -n APP_NAME --build-clear`. After you remove the association of the build from your app, you can update the app to reference a different image.
    {: important}

* If you are starting with source code that resides in a Git repository, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** operation. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from repository source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

* If you are starting with source code that resides on a local workstation, you can choose to let Code Engine take care of building the image from your source and deploying the app with a **single** CLI command. In this scenario, Code Engine uploads your image to IBM Cloud&reg; Container Registry. To learn more, see [Deploying your app from local source code with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-local-source-code). If you want more control over the build of your image, then you can choose to [build the image](https://cloud.ibm.com/docs/codeengine?topic=codeengine-plan-build) with Code Engine before you deploy your app.

For example, you might choose to let Code Engine handle the build of your local source while you evolve the development of your source for the app. Then, after the image is matured, you can update the deployed app to reference the specific image that you want. You can repeat this process as needed.

When you deploy your updated app, the latest version of your referenced container image is downloaded and deployed, unless a tag is specified for the image. If a tag is specified for the image, then the tagged image is used for the deployment.

## What if I want to redeploy my application without changing configuration settings?

{: #update-app-nochange}

You can always deploy your application with configuration changes by changing a configuration value and deploying the application.

However, you might want to redeploy an application revision without changing your application configuration settings. Perhaps your referenced container image is changed, and you want your application revision to use the updated container image. Or, perhaps you want your application to reference a secret or configmap, which contains updated content values.

For these scenarios, from the console, you can click **Redeploy** from the **Configuration** tab of your application page, without changing your app configuration. With the CLI, use the [**`ibmcloud ce app update`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-update) command.

## Updating your app from the console

{: #update-app-console}

Update the application that you created in [Deploying an application from a public registry from the console](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app&interface=ui#deploy-app-console) to add an environment variable.

1. Navigate to your application page. One way to navigate to your application page is to
    * Locate the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}.
    * Click the name of your project to open the Overview page.
    * Click **Applications** to open a list of your applications. Click the name of your application to open its application page.
2. From the application page, you can view information about the running instances of your application and its revisions, configuration details, and endpoint settings of the app. Click the name of the application revision that you want to work with to open the configuration summary for that revision. Or, you can click the **Configuration** tab to open the configuration summary for the latest application revision.
3. From the **Configuration** tab, click the **Environment variables** tab.
4. Click **Add environment variable**. Define this environment variable as a literal value. Enter `TARGET` for name and `Stranger` for value. Click **Add**.
5. Click **Deploy** to save your change and deploy the application revision.
6. After the application status changes to **Ready**, you can test the application revision. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**. For this app, `Hello Stranger` is displayed.

In this example, you updated environment variables for an app. You can also update other configuration settings for your app, including referencing a [different image](#update-app-crimage-console) or [different image build](#update-app-source-console) from the **Code** tab. From the **Resources & scaling** tab, you can update [memory](https://cloud.ibm.com/docs/codeengine?topic=codeengine-mem-cpu-combo) and [application scaling](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-scale) settings for your app. From the **Environment variables** tab, you can add or update [environment variables](https://cloud.ibm.com/docs/codeengine?topic=codeengine-envvar) for your app. From the **Image start options** tab, you can add or update [command and arguments](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cmd-args) to override settings within your container image, or [work with liveness and readiness probes](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-probes).

## Updating your app to use project-only endpoints from the console

{: #update-app-console-projendpt}

By default, when you deploy an app, the app deploys such that it can receive requests from the public internet, from a private network, or from components within the project. Let's change the visibility of this app such that it is accessed only by other Code Engine resources that are running in the same Code Engine environment. Use the **Domain mappings** tab to change the visibility of an app.

1. Navigate to your application page. One way to navigate to your application page is to
    * Locate the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}.
    * Click the name of your project to open the Overview page.
    * Click **Applications** to open a list of your applications. Click the name of your application to open its application page.
2. From the application page, you can view information about the running instances of your application and its revisions, configuration details, and endpoint settings of the app. Click the **Domain mappings** tab to open the endpoint visibility settings for the application.  
3. From the **Domain mappings** tab, notice the available URLs for your application. When `Public` is selected, you can view the public and the internal system domain mapping URL for the application. When **No external system domain mapping** is selected, this application is no longer accessible from the public internet and network access is only possible from components within this project.

    When you change the visibility of your app, the change is effective immediately. It is important to consider the impact of the change for your active users or integrations as well as any security implications. You can change the visibility setting as needed.
    {: important}  

## Updating your app to use private endpoints from the console

{: #update-app-console-privateendpt}

By default, when you deploy an app, the app deploys such that it can receive requests from the public internet, from a private network, or from components within the project. Let's change the visibility of this app such that it is accessed only by other Code Engine resources that are running in the same project and from the private network by using Virtual Private Endpoints. Use the **Domain mappings** tab to change the visibility of an app.

1. Navigate to your application page. One way to navigate to your application page is to
    * Locate the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}.
    * Click the name of your project to open the Overview page.
    * Click **Applications** to open a list of your applications. Click the name of your application to open its application page.
2. From the application page, you can view information about the running instances of your application and its revisions, configuration details, and endpoint settings of the app. Click the **Domain mappings** tab to open the endpoint visibility settings for the application.  
3. From the **Domain mappings** tab, notice the available URLs for your application. When `Private` is selected, this application is no longer accessible from the public internet and network access is only possible from components within this project (cluster-local) and from the private network.

    Click **Private** to change the endpoint visibility of the app. The available URLs for your endpoint definition are displayed for the private and project-only URLs.

4. To access your app securely by using a Virtual Private Endpoint (VPE), follow the instructions for [Using your VPE to access an app](https://cloud.ibm.com/docs/codeengine?topic=codeengine-vpe#using-vpes-app) to set up the VPE to access your app.

If you set your application for `visibility = private`, then you can only test your application through the [virtual private endpoint from within your Virtual Private Cloud (VPC)](https://cloud.ibm.com/docs/codeengine?topic=codeengine-vpe).

By changing the visibility of your app, the change is effective immediately. It is important to consider the impact of the change for your active users or integrations as well as any security implications. You can change the visibility setting as needed.
{: important}  

## Updating your app with the CLI

{: #update-app-cli}

To update your app with the CLI, use the **`app update`** command. This command requires the name of the app that you want to update and also allows other optional arguments. For a complete listing of options, see the [**`ibmcloud ce app update`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-update) command.
{: shortdesc}

Update the application that you created in [Deploying an application with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app&interface=cli#deploy-app-cli) to add an environment variable.

The sample `icr.io/codeengine/hello` image reads the environment variable `TARGET`, and prints `Hello ${TARGET}`. If this environment variable is empty, `Hello World` is returned. The following example updates the app to modify the value of the `TARGET` environment variable to `Stranger`. For more information about the code that is used for this example, see [`hello`](https://github.com/IBM/CodeEngine/tree/main/hello){: external}.

1. Run the **`application update`** command. For example,

    ```txt
    ibmcloud ce application update -n myapp --env TARGET=Stranger
    ```

    {: pre}

    Example output

    ```txt
    Updating application 'myapp' to latest revision.
    [...]
    Run 'ibmcloud ce application get -n myapp' to check the application status.
    OK

    https://myapp.4svg40kna19.us-south.codeengine.appdomain.cloud    
    ```

    {: screen}

2. Run the **`application get`** command to display the status of your app, including the latest revision information.

    ```txt
    ibmcloud ce application get --name myapp  
    ```

    {: pre}

    Example output

    ```txt
    [...]
    Name:          myapp
    [...]
    URL:           https://myapp.4svg40kna19.us-south.codeengine.appdomain.cloud
    Cluster Local URL:  http://myapp.4svg40kna19.svc.cluster.local
    Console URL:   https://cloud.ibm.com/codeengine/project/us-south/01234567-abcd-abcd-abcd-abcdabcd1111/application/myapp/configuration

    Environment Variables:
    Type     Name    Value
    Literal  TARGET  Stranger
    Image:                  icr.io/codeengine/hello
    Resource Allocation:
    CPU:                1
    Ephemeral Storage:  400M
    Memory:             4G

    Revisions:
    myapp-hc3u8-2:
        Age:                82s
        Traffic:            100%
        Image:              icr.io/codeengine/hello (pinned to f0dc03)
        Running Instances:  1

    Runtime:
    Concurrency:    100
    Maximum Scale:  10
    Minimum Scale:  0
    Timeout:        300

    Conditions:
    Type                 OK    Age  Reason
    ConfigurationsReady  true  75s
    Ready                true  62s
    RoutesReady          true  62s

    Events:
    Type    Reason   Age    Source              Messages
    Normal  Created  2m11s  service-controller  Created Configuration "myapp"
    Normal  Created  2m11s  service-controller  Created Route "myapp"

    Instances:
    Name                                       Revision       Running  Status       Restarts  Age
    myapp-hc3u8-1-deployment-65cf8cd4f5-jx8b8  myapp-hc3u8-1  1/2      Terminating  0         2m10s
    myapp-hc3u8-2-deployment-7f98b679d5-2hskr  myapp-hc3u8-2  2/2      Terminating  0         85s
    ```

    {: screen}

    From the output in the **Revisions** section, you can see the latest application revision of the `myapp` service. Also, notice that 100% of the traffic to the application is running the latest revision of the app.

3. Call the application.

    ```txt
    curl https://myapp.4svg40kna19.us-south.codeengine.appdomain.cloud
    ```

    {: pre}

    Example output

    ```txt
    Hello Stranger
    ```

    {: screen}

    From the output of this command, you can see the updated app now returns `Hello Stranger`.

4. Use the [**`ibmcloud ce revision list`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-revision-list) command to display all your app revisions. Use this information to help you manage your app revisions as Code Engine has a [quota for the number of app revisions in a project](https://cloud.ibm.com/docs/codeengine?topic=codeengine-limits#project_quotas).

    In the following **`revision list`** output, notice that Code Engine retains only the latest inactive revision of your application in addition to your active app revision. Older revisions are deleted.

    ```txt
    ibmcloud ce revision list 
    ```

    {: pre}

    Example output

    ```txt
    Listing all application revisions...
    OK

    Name                   Application      Status  URL  Latest  Tag  Traffic  Age    Conditions  Reason
    myapp-hc3u8-4           myapp            Ready                            2d15h    3 OK / 4
    myapp-hc3u8-5           myapp            Ready        true         100%    2d8h    3 OK / 4  
    myapp2-vjfqt-1          myapp2           Ready        true         100%      3d    3 OK / 4
    myhelloapp-tv368-3      myhelloapp       Ready                              16d    3 OK / 4
    myhelloapp-tv368-4      myhelloapp       Ready        true         100%     16d    3 OK / 4
    newapp-mytest-00008     newapp-mytest    Ready                              4d17h  3 OK / 4
    newapp-mytest-00009     newapp-mytest    Ready        true         100%     2d20h  3 OK / 4
    ```

    {: screen}

You can manage your app revisions by using the [**`ibmcloud ce revision get`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-revision-get) command to display details of an app revision and the [**`ibmcloud ce revision delete`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-revision-delete) command to remove revisions that you don't want to keep. You can also use the  [**`ibmcloud ce revision logs`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-revision-logs) command to view logs of application revision instances. Use the [**`ibmcloud ce revision events`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-revision-events) command to display system events of application revision instances.

## Updating your app to use project-only endpoints with the CLI

{: #update-app-cli-projectonly}

By default, when you deploy an app, the app deploys such that it can receive requests from the public internet, from a private network, or from components within the project. To change the visibility of your app such that it is accessed only by other Code Engine resources that are running in the same project, use the `--visibility=project` option with the [**`ibmcloud ce app update`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-update) or [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.{: shortdesc}

In this scenario, update the application that you created in [Deploying an application with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app&interface=cli#deploy-app-cli) to change the visibility of the app to use a [project endpoint](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#app-endpoint-projectonly).  

1. Run the **`application update`** command. For example,

    ```txt
    ibmcloud ce application update -n myapp --visibility=project
    ```

    {: pre}

    Example output

    ```txt
    Updating application 'myapp' to latest revision.
    [...]
    Run 'ibmcloud ce application get -n myapp' to check the application status.
    OK

    http://myapp.4svg40kna19.svc.cluster.local   
    ```

    {: screen}

2. Run the **`application get`** command to display the status of your app, including the latest revision information.

    ```txt
    ibmcloud ce application get --name myapp  
    ```

    {: pre}

    Example output

    ```txt
    [...]
    Name:          myapp
    [...]
    URL:           http://myapp.4svg40kna19.svc.cluster.local
    Cluster Local URL:  http://myapp.4svg40kna19.svc.cluster.local
    Console URL:   https://cloud.ibm.com/codeengine/project/us-south/01234567-abcd-abcd-abcd-abcdabcd1111/application/myapp/configuration

    Environment Variables:
    Type     Name    Value
    Literal  TARGET  Stranger
    Image:                  icr.io/codeengine/hello
    Resource Allocation:
    CPU:                1
    Ephemeral Storage:  400M
    Memory:             4G

    Revisions:
    myapp-hc3u8-2:
        Age:                82s
        Traffic:            100%
        Image:              icr.io/codeengine/hello (pinned to f0dc03)
        Running Instances:  1

    Runtime:
    Concurrency:    100
    Maximum Scale:  10
    Minimum Scale:  0
    Timeout:        300

    Conditions:
    Type                 OK    Age  Reason
    ConfigurationsReady  true  75s
    Ready                true  62s
    RoutesReady          true  62s

    Events:
    Type    Reason   Age    Source              Messages
    Normal  Created  2m11s  service-controller  Created Configuration "myapp"
    Normal  Created  2m11s  service-controller  Created Route "myapp"

    Instances:
    Name                                       Revision       Running  Status       Restarts  Age
    myapp-hc3u8-1-deployment-65cf8cd4f5-jx8b8  myapp-hc3u8-1  1/2      Terminating  0         2m10s
    myapp-hc3u8-2-deployment-7f98b679d5-2hskr  myapp-hc3u8-2  2/2      Terminating  0         85s
    ```

    {: screen}

    From the output in the **Revisions** section, you can see the latest application revision of the `myapp` service. Also, notice that 100% of the traffic to the application is running the latest revision of the app.

Now that you set `--visibility=project` on your application, this application is no longer accessible from the public internet and network access is only possible from components within this project (cluster-local).

## Updating your app to use private endpoints with the CLI

{: #update-app-cli-privateendpt}

By default, when you deploy an app, the app deploys such that it can receive requests from the public internet, from a private network, or from components within the project. You can set the endpoint visibility for your app such that it is deployed with a private endpoint. Setting a private endpoint means that your app is not accessible from the public internet and network access is only possible from other IBM Cloud services from virtual private endpoints (VPC) or Code Engine components that are running in the same project (cluster-local).
{: shortdesc}

 To change the visibility of your app such that it is accessed only with a private endpoint, use the `--visibility=private` option with the [**`ibmcloud ce app update`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-update) or [**`ibmcloud ce app create`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-application-create) command.{: shortdesc}

 You can only use your VPE to access your app with a private endpoint if your selected project supports [application private visibility](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#app-endpoint-private). To confirm if the project supports application private visibility, use the  [**`ibmcloud ce project get`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-project-get) command to verify the output for `Application Private Visibility Supported` is set to `true`.
{: important}

In this scenario, update the application that you created in [Deploying an application with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app&interface=cli#deploy-app-cli) to change the visibility of the app to use a [private endpoint](https://cloud.ibm.com/docs/codeengine?topic=codeengine-application-workloads#app-endpoint-private).

1. Confirm that the existing project supports applications with private visibility. Use the  [**`ibmcloud ce project get`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-project-get) command to verify the output for `Application Private Visibility Supported` is set to `true`. If the value is `false`, [contact IBM support](https://cloud.ibm.com/docs/codeengine?topic=codeengine-get-support) to enable this capability within your existing project.

    ```txt
    ibmcloud ce project get -n myproject
    ```

    {: pre}

    Example output

    ```txt
    Getting project 'myproject'...
    OK

    Name:                                      myproject  
    ID:                         abcdabcd-abcd-abcd-abcd-f1de4aab5d5d
    Status:                                    active  
    Enabled:                                   true  
    Application Private Visibility Supported:  true  
    Selected:                                  true  
    Region:                                    us-south 
    Resource Group:             default
    Service Binding Service ID: ServiceId-1234abcd-abcd-abcd-1111-1a2b3c4d5e6f
    Age:                        52d 
    Created:                                   Tue, 28 Sep 2021 05:12:16 -0500  
    Updated:                                   Tue, 28 Sep 2021 05:12:19 -0500  

    Quotas:    
    Category                                  Used  Limit  
    App revisions                             1     60  
    Apps                                      1     20  
    Build runs                                1     100  
    Builds                                    2     100  
    Configmaps                                2     100  
    CPU                                       0     64  
    Ephemeral storage                         0     256G  
    Instances (active)                        0     250  
    Instances (total)                         0     2500  
    Job runs                                  0     100  
    Jobs                                      0     100  
    Memory                                    0     256G  
    Secrets                                   6     100  
    Subscriptions (cron)                      0     100  
    Subscriptions (IBM Cloud Object Storage)  0     100  
    Subscriptions (Kafka)                     0     100
    ```

    {: screen}

2. If `Application Private Visibility Supported` is `true`, then you can update your app to use private endpoints. Run the **`application update`** command. For example,

    ```txt
    ibmcloud ce application update -n myapp --visibility=private
    ```

    {: pre}

    Example output

    ```txt
    Updating application 'myapp' to latest revision.
    [...]
    Run 'ibmcloud ce application get -n myapp' to check the application status.
    OK

    https://myapp.4svg40kna19.private.us-south.codeengine.appdomain.cloud
    ```

    {: screen}

3. Run the **`application get`** command to display the status of your app, including the latest revision information.

    ```txt
    ibmcloud ce application get --name myapp  
    ```

    {: pre}

    Example output

    ```txt
    [...]
    Name:          myapp
    [...]
    URL:           https://myapp.4svg40kna19.private.us-south.codeengine.appdomain.cloud
    Cluster Local URL:  http://myapp.4svg40kna19.svc.cluster.local
    Console URL:   https://cloud.ibm.com/codeengine/project/us-south/01234567-abcd-abcd-abcd-abcdabcd1111/application/myapp/configuration

    Environment Variables:
    Type     Name    Value
    Literal  TARGET  Stranger
    Image:                  icr.io/codeengine/hello
    Resource Allocation:
    CPU:                1
    Ephemeral Storage:  400M
    Memory:             4G

    Revisions:
    myapp-hc3u8-2:
        Age:                82s
        Traffic:            100%
        Image:              icr.io/codeengine/hello (pinned to f0dc03)
        Running Instances:  1

    Runtime:
    Concurrency:    100
    Maximum Scale:  10
    Minimum Scale:  0
    Timeout:        300

    Conditions:
    Type                 OK    Age  Reason
    ConfigurationsReady  true  75s
    Ready                true  62s
    RoutesReady          true  62s

    Events:
    Type    Reason   Age    Source              Messages
    Normal  Created  2m11s  service-controller  Created Configuration "myapp"
    Normal  Created  2m11s  service-controller  Created Route "myapp"

    Instances:
    Name                                       Revision       Running  Status       Restarts  Age
    myapp-hc3u8-1-deployment-65cf8cd4f5-jx8b8  myapp-hc3u8-1  1/2      Terminating  0         2m10s
    myapp-hc3u8-2-deployment-7f98b679d5-2hskr  myapp-hc3u8-2  2/2      Terminating  0         85s
    ```

    {: screen}

    From the output in the **Revisions** section, you can see the latest application revision of the `myapp` service. Also, notice that 100% of the traffic to the application is running the latest revision of the app.

4. Set up your VPE to [access your app with a private endpoint](https://cloud.ibm.com/docs/codeengine?topic=codeengine-vpe#using-vpes-app).

## Updating an app to reference a different image

{: #update-app-diff-image}

You can update your app to reference a different image.

The image that is associated with your specific application revision has a unique container registry digest, and Code Engine uses this digest for the life of your application revision. If you create a newer version of an image with the same tag as the original image, the original image is overwritten in the container registry and becomes untagged. The newer image is tagged, and this newer image has a different digest. Your Code Engine application does not use this newer image, because the newer image has a different digest than the  image that is referenced by the application revision. Code Engine can still create new instances of the application revision as long as the untagged image, which was referenced originally, still exists. For more information, see [Why can't Code Engine pull an image?](https://cloud.ibm.com/docs/codeengine?topic=codeengine-image-cannot-pull)
{: important}

### Updating an app to reference a different image in Container Registry from the console

{: #update-app-crimage-console}

Update an application to reference a different image in a container registry by using the Code Engine console.
{: shortdesc}

For this example, let's update the `helloapp` that you created in [Deploying an application that references an image in a container registry from the console](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-crimage#deploy-app-crimage-console) to reference a different image. The updated app references the `helloworld_repo` image in the `mynamespace2` namespace in Container Registry. The following steps describe adding access to a registry during the update of an app.

For more information about adding an image to Container Registry, see [Getting started with IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-getting-started#getting-started).

1. Navigate to your application page. One way to navigate to your application page is to
    * Locate the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}.
    * Click the name of your project to open the Overview page.
    * Click **Applications** to open a list of your applications. Click the name of your application to open the application page.
2. Click the **Configuration** tab to open the configuration details for the latest application revision.
3. From the **Configuration** tab, click the **Code** tab.
4. For Image to run, click **Configure image** to open the configure image dialog. For this example, update the app to reference an existing `ibmcregistry` registry, select the `mynamespace2` namespace, select the `helloworld-repo` image, and select `1` as the value for `tag`. From the configure image page,
    * If the image you want to use resides in the same Container Registry account, select the access for the registry.
    * If the image that you want to use resides in a different container registry account, you can select the registry access for this registry. If the registry access does not exist, you must first [create your IAM API key](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#images-your-account-api-key) and then [Add registry access to Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#add-registry-access-ce).

    If you want to update only the registry access to your image, you can make this change without clicking **Configure image** to open the configure image dialog and use the Registry access menu to select an existing registry access or [create a registry access to Code Engine](https://cloud.ibm.com/docs/codeengine?topic=codeengine-add-registry#add-registry-access-ce) for the image that is referenced by your application.
    {: note}

5. Click **Done**. You selected your image in the registry to reference from your app.
6. Click **Deploy** to save your change and deploy the app revision.
7. After the application status changes to **Ready**, you can test the app revision. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**. For this app, `Hello World from Code Engine` is displayed.

### Updating an app to reference a different image in Container Registry with the CLI

{: #update-app-crimage-cli}

Update an application to reference a different image in Container Registry from the Code Engine CLI.
{: shortdesc}

For this example, update the `myhelloapp` that you created in [Deploying an application that references an image in a container registry with the CLI](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-crimage#deploy-app-crimage-cli) to reference a different image in a different namespace in the same account. Update the app to reference the `helloworld_repo` image in the `mynamespace2` namespace in Container Registry.

1. Add a different image to Container Registry. For this example, add the `helloworld_repo` image in the `mynamespace2` namespace in Container Registry. For more information about adding an image to Container Registry, see [Getting started with IBM Cloud Container Registry](https://cloud.ibm.com/docs/Registry?topic=Registry-getting-started#getting-started).

2. Add registry access to Code Engine. For this example, because the `helloworld_repo` image resides in the same account, use the previously defined `myregistry` registry access.

3. Update your app and reference the image in Container Registry by using the `myregistry` access. For example, update the `myhelloapp` app to reference the `us.icr.io/mynamespace2/helloworld_repo` by using the `myregistry` access information.

    ```txt
    ibmcloud ce app update --name myhelloapp --image us.icr.io/mynamespace2/helloworld_repo:1 --registry-secret myregistry
    ```

    {: pre}

    The format of the name of the image for this application is `REGISTRY/NAMESPACE/REPOSITORY:TAG` where `REGISTRY` and `TAG` are optional. If `REGISTRY` is not specified, the default is `docker.io`. If `TAG` is not specified, the default is `latest`.
    {: important}

4. After your app is updated, you can access the app. To obtain the URL of your app, run `ibmcloud ce app get --name myhelloapp --output url`. When you curl the `myhelloapp` app, the app returns `Hello World from Code Engine`, which demonstrates the app is now using the `helloworld_repo` image.

### Updating an app to reference an image that is built from source code from the console

{: #update-app-source-console}

Update an application to reference an image that is built from source code by using the Code Engine console.
{: shortdesc}

For this example, let's update the `helloapp` that you created in [Deploying an application that references an image in a container registry from the console](https://cloud.ibm.com/docs/codeengine?topic=codeengine-deploy-app-crimage#deploy-app-crimage-console) to reference an image that is built from your source code.

For more information about creating a build configuration from the console, see [create a build](https://cloud.ibm.com/docs/codeengine?topic=codeengine-build-create-config1).

1. Navigate to your application page. One way to navigate to your application page is to
    * Locate the [Code Engine Projects page](https://cloud.ibm.com/codeengine/projects){: external}.
    * Click the name of your project to open the Overview page.
    * Click **Applications** to open a list of your applications. Click the name of your application to open the application page.
2. Click the **Configuration** tab to open the configuration details for the latest application revision.
3. From the **Configuration** tab, click the **Code** tab.
4. From the **Code** tab, you can create an image build, or you can rerun an existing image build that is referenced by your application. To create an image build, click **Create image from source** to run an image build. The Specify build details page opens where you can enter the details of your build to [deploy your app from source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). Click **Done** when build detail updates are specified.
5. Click **Deploy** to save your changes, run the build, and deploy the app revision.
6. After the application status changes to **Ready**, you can test the app revision. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**.
7. To update this application again to reference an updated build image, click **Rerun build** from the **Code** tab, and specify a unique image tag for the updated build image. If you want to make more changes to the build details, click **Edit build details**. The Specify build details page opens where you can enter the details of your build to [deploy your app from source code](https://cloud.ibm.com/docs/codeengine?topic=codeengine-app-source-code). Click **Done** when build detail updates are specified.
8. Click **Deploy** to save your changes, run the build with your changes, and deploy the app revision.
9. After the application status changes to **Ready**, you can test the app revision. Click **Test application** and then click **Send request** in the Test application pane. To open the application in a web page, click **Application URL**.

### Updating an app to reference an image that is built from source code with the CLI

{: #update-app-source-cli}

Update an application to reference an image that is built from source code by using the Code Engine CLI.
{: shortdesc}

For this example, let's change the `myhelloapp` that you updated in [Updating an app to reference a different image in Container Registry with the CLI](#update-app-crimage-cli) to reference a different image that is built from your source code.

From the previous example, the `myhelloapp` app references the `us.icr.io/mynamespace2/helloworld_repo` by using the `myregistry` access information. Let's create a build configuration, run the build, and update the `myhelloapp` to reference the image that was built from source code.

1. Create the build configuration. For example, the following **`build create`** command creates a build configuration that is called `helloworld-build`. This configuration builds from the public Git repo `https://github.com/IBM/CodeEngine`, uses the `dockerfile` strategy and `medium` build size, and stores the image to `us.icr.io/mynamespace/codeengine-helloworld` by using the image registry secret that is defined in `myregistry`.

    ```txt
    ibmcloud ce build create --name helloworld-build --image us.icr.io/mynamespace/codeengine-helloworld --registry-secret myregistry --source https://github.com/IBM/CodeEngine --commit main --context-dir /hello --strategy dockerfile --size medium
    ```

    {: pre}

2. Run the build. This example runs a build that is called `helloworld-build-run` and uses the `helloworld-build` build configuration.

    ```txt
    ibmcloud ce buildrun submit --build helloworld-build --name helloworld-build-run 
    ```

    {: pre}

    The following output displays the details of the build run by using the  [**`ibmcloud ce buildrun get`**](https://cloud.ibm.com/docs/codeengine?topic=codeengine-cli#cli-buildrun-get) command.

    Example output

    ```txt
    Getting build run 'helloworld-build-run'...
    [...]
    OK

    Name:          helloworld-build-run  
    ID:            abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f 
    Project Name:  myproject  
    Project ID:    01234567-abcd-abcd-abcd-abcdabcd1111  
    Age:           21m  
    Created:       2021-09-30T14:50:13-05:00  

    Summary:  Succeeded  
    Status:   Succeeded  
    Reason:   All Steps have completed executing

    Image:  us.icr.io/mynamespace/codeengine-helloworld

    ```

    {: screen}

    For more information about creating a build configuration with the CLI, see [create a build](https://cloud.ibm.com/docs/codeengine?topic=codeengine-build-create-config1#build-create-cli).

3. Update the `myhelloapp` to reference the image that you built and uses the `myregistry` registry secret.

    ```txt
    ibmcloud ce app update --name myhelloapp --image us.icr.io/mynamespace/codeengine-helloworld --registry-secret myregistry
    ```

    {: pre}

4. Display information about the updated app to confirm the image that is referenced is the image that you built.

    ```txt
    ibmcloud ce app get --name myhelloapp 
    ```

    {: pre}

    Example output

    ```txt
    [...]
    OK

    Name:               myhelloapp
    ID:                 abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f
    Project Name:       myproject
    Project ID:         01234567-abcd-abcd-abcd-abcdabcd1111
    Age:                2m4s
    Created:            2021-09-09T14:01:02-04:00
    URL:                https://myhelloapp.abcdabcdabc.us-south.codeengine.appdomain.cloud
    Cluster Local URL:  http://myhelloapp.abcdabcdabc.svc.cluster.local
    Console URL:        https://cloud.ibm.com/codeengine/project/us-south/01234567-abcd-abcd-abcd-abcdabcd1111/application/myhelloapp/configuration
    Status Summary:     Application deployed successfully

    Environment Variables:    
        Type     Name             Value  
        Literal  CE_API_BASE_URL  https://api.private.us-south.codeengine.cloud.ibm.com
        Literal  CE_APP           myhelloapp  
        Literal  CE_DOMAIN        us-south.codeengine.appdomain.cloud  
        Literal  CE_PROJECT_ID    abcdefgh-abcd-abcd-abcd-1a2b3c4d5e6f
        Literal  CE_REGION        us-south  
        Literal  CE_SUBDOMAIN     abcdabcdab
    Image:                  us.icr.io/mynancesnamespace/codeengine-helloworld
    Resource Allocation:
    CPU:                1
    Ephemeral Storage:  400M
    Memory:             4G
    Registry Secrets:
    myregistry

    Revisions:
    helloapp-00003:
        Age:                2m46s
        Latest:             true
        Traffic:            100%
        Image:              us.icr.io/mysnamespace/codeengine-helloworld (pinned to eeca2b)
        Running Instances:  1
    [...]
    ```

    {: screen}

================================

================================

================================

================================

================================
