# Build - BRK225H

## Overview

This repo contains the source code for the [BRK225H](https://www.youtube.com/watch?v=LhJODembils&list=PLtabQVGAhVijNH-2VKhcWt9dmBpMLiDJg) session presented at Microsoft Build 2023.

## Prerequisites

- [Visual Studio Code](https://code.visualstudio.com/)
- [Azure Account](https://azure.microsoft.com/free/)
- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
- [Terraform CLI](https://www.terraform.io/downloads.html)
- [Helm CLI](https://helm.sh/docs/intro/install/)
- [Access to Azure OpenAI services](https://azure.microsoft.com/products/cognitive-services/openai-service/)
- [Access to GitHub Copilot](https://copilot.github.com/)
- [Permissions to create Azure app registrations](https://learn.microsoft.com/azure/active-directory/develop/howto-create-service-principal-portal#permissions-required-for-registering-an-app)

Before you get started you should also ensure the following features are enabled in your Azure subscription:

```
az feature register \
  --namespace "Microsoft.ContainerService" \
  --name "EnableWorkloadIdentityPreview"

az feature register \
  --namespace "Microsoft.ContainerService" \
  --name "AzureServiceMeshPreview"

az feature register \
  --namespace "Microsoft.ContainerService" \
  --name "AKS-KedaPreview"

az feature register \
  --namespace "Microsoft.ContainerService" \
  --name "AKS-PrometheusAddonPreview"
```

Also make sure you have the following extension installed for Azure CLI:

```
az extension add --name aks-preview
```

## Getting Started

Here is a quick guide to get you started.

1. Fork and clone this repo
1. On GitHub, make sure you've enabled GitHub Actions for your fork of this repo
1. Open the repo in VS Code
1. Open the integrated terminal
1. Checkout the `build/brk225h` branch
1. Run the `az login` command to log into your Azure account
1. Run the `cd demos/build/brk225h/terraform` command to change to the `terraform` directory
1. Create a new file called `terraform.tfvars` in the `terraform` directory and add values for `gh_token` and `gh_organization`. See the `terraform.tfvars.example` file for an example. The `gh_token` value should be a GitHub personal access token with the `repo` and `workflow` scopes. The `gh_organization` value should be the name of the GitHub organization you want to deploy the resources to
1. Run the `terraform init` command to initialize the Terraform modules
1. Run the `terraform apply` to run a Terraform plan and confirm the changes

## What's in the box?

This Terraform script will deploy the following resources to Azure, GitHub, and Kubernetes:

- Azure App Registration, Service Principal, and Federated Identity Credential
    - This service principal is given the "owner" role on your subscription and is used to authenticate to Azure and deploy resources the GitHub Action workflow.
- Azure OpenAI service with the following models deployed:
    - `text-davinci-003`
    - `text-embedding-ada-002`
    - `gpt-35-turbo`
- Azure Container Registry
- Azure Managed Grafana with role assignments to allow you to manage the Grafana instance and "Istio workload dashboard" imported into Grafana
- Azure Monitor managed workspace for Prometheus with role assignments to allow you and Azure Managed Grafana to read metrics from the workspace
- Azure Log Analytics workspace
- Azure Kubernetes Service with `AcrPull` permissions to the ACR and the following addons:
    - Key Vault secrets provider
    - Istio service mesh with external ingress gateway enabled
    - Workload Identity
    - KEDA
- Azure App Configuration Service with a feature flag called "Chat" to enable/disable the chat feature on the eShop application (by default the chat feature is disabled)
- Azure SQL database with databases called `eShopOnWeb.CatalogDb` and `eShopOnWeb.Identity`, and a server-level firewall rule to allow access from the AKS cluster
- Azure Key Vault to store secrets for the eShop application
- GitHub Action secrets for building and publishing the eShop application to Azure Container Registry
- Kubernetes namespace called `eshop` with a label of `istio.io/rev=asm-1-17` to allow Istio to inject the sidecar proxy into the pods
- Kubernetes config map to enable scraping of Istio metrics by Prometheus
- Kubernetes config map to store eShop application settings
- Kubernetes secret to store eShop application secrets

## How to demo

Once the Terraform script has completed, you will have a fully functional eShop application running in Azure Kubernetes Service. The eShop application is a sample ASP.NET Core application that has been modified to use the OpenAI service to enable chat functionality. The chat functionality is disabled by default and can be enabled by setting the `Chat` feature flag in Azure App Configuration to `true`.

To perform the demo that was presented in the [BRK225H](https://www.youtube.com/watch?v=LhJODembils&list=PLtabQVGAhVijNH-2VKhcWt9dmBpMLiDJg) session @ MSBuild, you can use the following steps:

### Start with v1.0 of eShop

Since the GitHub Action workflow deploys a fully functional eShop application, you can start by showing the v1.0 of the eShop application running in Azure Kubernetes Service.

Open the [src/Web/Views/Shared/_Layout.cshtml](src/Web/Views/Shared/_Layout.cshtml) file and comment out the following block starting on line 39:

```html
<feature name="Chat">
    <partial name="_ChatPartial" />
</feature>
```

Save the file and use the `az acr build` command to build and publish the eShop application to Azure Container Registry:

```bash
# get the RG name
RG_NAME=<YOUR_RG_NAME>

# get the ACR name
ACR_NAME=$(az resource list \       
  --resource-group $RG_NAME \
  --resource-type Microsoft.ContainerRegistry/registries \
  --query "[0].name" -o tsv)

# get the ACR server
ACR_SERVER=$(az acr show \   
  --name $ACR_NAME \
  --resource-group $RG_NAME \
  --query loginServer \
  --output tsv)

# be sure you are in the root of the repo before running the next command
# build and push the v1.0 of the eShop application
az acr build -r $ACR_NAME --image $ACR_SERVER/build23/web:v1.0 -f src/Web/Dockerfile . --no-wait

# do the same for v1.0 of the chat microservice
az acr build -r $ACR_NAME --image $ACR_SERVER/build23/chatapi:v1.0 -f src/ChatApi/Dockerfile . --no-wait
```

Undo your change on the [src/Web/Views/Shared/_Layout.cshtml](src/Web/Views/Shared/_Layout.cshtml) file, save changes and publish the another version eShop application to Azure Container Registry:

```bash
# build and push the v1.1 of the eShop application
az acr build -r $ACR_NAME --image $ACR_SERVER/build23/web:v1.1 -f src/Web/Dockerfile . --no-wait
```

In your terminal, change directory to `demos/build/brk225h/k8s` and run the following command to update your image tags:


```bash
kustomize edit set image chatapi=$ACR_SERVER/build23/chatapi:v1.0
kustomize edit set image web=$ACR_SERVER/build23/web:v1.1
```


Un-deploy the eShop application:

```bash
kubectl delete -n eshop -k .
```

Open [demos/build/brk225h/k8s/kustomization.yaml](demos/build/brk225h/k8s/kustomization.yaml) file and remove the line `- chatapi.yaml` from the `resources:` list. Then run the following command to re-deploy the eShop application:

```bash
kubectl apply -n eshop -k .
```

This is your starting point. You can now show the eShop application running in Azure Kubernetes Service.

To easily pull out the URL, run the following command:

```bash
# get the ingress IP address of the Istio ingress gateway
INGRESS_IP=$(kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "http://$INGRESS_IP"
```

### Add Chat to v1.1 of eShop

Open [demos/build/brk225h/k8s/kustomization.yaml](demos/build/brk225h/k8s/kustomization.yaml) file and add the line `- chatapi.yaml` to the `resources:` list. Also, update the version of the web image to `v1.1`, then run the following command to re-deploy the eShop application with chat:

```bash
kubectl apply -n eshop -k .
```

To test the ChatAPI, you can run the following commands in the terminal:

> NOTE: The question you ask may take a few minutes to complete initially; therefore, it is advisable to show this from the terminal and show how you expect the chatbot to answer based on code in [src/ChatApi/Program.cs](src/ChatApi/Program.cs) before demoing the chat functionality in the eShop web application.

```bash
# check the version of chat
curl -v http://$INGRESS_IP/chat

# ask a question
curl -v http://$INGRESS_IP/chat -H "Content-Type: application/json" -d '{"text": "do you sell mugs"}'
```

To demo chat capabilities from the eShop application, do the following:

1. Open the Azure portal and navigate to the Azure App Configuration service
1. Click on the configuration store and navigate to the "Feature management" section
1. Click on the "Chat" feature flag and set the value to `true`
1. Navigate to the eShop application and refresh the page, after a few seconds you should see a chat icon in the upper right corner of the page
1. Ask a question in the chat window and you should see a response from the OpenAI service

### Deploy v1.1 of Chat

To demo how Istio service mesh can help you launch new versions of the application, you can use the following steps:

Open [src/ChatApi/Program.cs](src/ChatApi/Program.cs) in VS Code and search for the text `eShopBot v1.0` and update it to `eShopBot v1.1`. Save the changes then use the `az acr build` command again to build and publish the new version of the application to Azure Container Registry

```bash
# be sure you are in the root of the repo before running the next command
# build and push the v1.1 of the chat microservice
az acr build -r $ACR_NAME --image $ACR_SERVER/build23/chatapi:v1.1 -f src/ChatApi/Dockerfile . --no-wait
```

> NOTE: This should be done ahead of time (before the demo) as it does take a few minutes to complete.

With the new version of the ChatAPI is published, update the `kustomization.yaml` and replace the `- chatapi.yaml` with `- chatapi-dark-launch.yaml` in the `resources:` list, then point to the new `v1.1` version of the `chat` image.

Deploy the new version of the chat microservice with the following command:

```bash
kubectl apply -n eshop -k .
```

To test "dark" launch:

```bash
curl -v http://$INGRESS_IP/chat -H "x-istio-msbuild: brk225h"
```

To test "weighted" launch, update the `kustomization.yaml` and replace the `- chatapi-dark-launch.yaml` with `- chatapi-weighted-launch.yaml` in the `resources:` list, redeploy the manifests and run the following command to test:

```bash
while true; do curl -s http://$INGRESS_IP/chat; echo; done
```

### Progressive deployments using Flagger

To test progressive deployments using Flagger, you will need to uninstall the existing chat microservice deployment, then reploy using the `chatapi-canary-launch.yaml` file.

Before you deploy the canary resource, you will need to use the following steps to deploy the Flagger controller:

```bash
# add the Flagger Helm repository
helm repo add flagger https://flagger.app

# install Flagger
helm install flagger flagger/flagger \
     --namespace=aks-istio-system \
     --set meshProvider=istio \
     --set prometheus.install=true

# wait for the flagger pod to be ready
kubectl get po -n aks-istio-system

# install the load tester
helm install flagger-loadtester flagger/loadtester \
--namespace=eshop \
--set cmd.timeout=1h \
--set cmd.namespaceRegexp=''
```

To create a Canary deployment, delete the existing ChatApi resources in the cluster, replace the `- chatapi-weighted-launch.yaml` with `- chatapi-canary-launch.yaml` in the `resources:` section of the `kustomization.yaml` file, and set the chat image version to `v1.0`.

Wait for the canary deployment to complete, then run the following command to test the canary deployment:

```bash
kubectl set image -n eshop deployment/chatapi chatapi=$ACR_SERVER/build23/chatapi:v1.1
```

This will trigger a canary deployment. To monitor the canary deployment, run the following command:

```bash
kubectl get canary -n eshop chatapi -w
```

You can also watch the chat requests getting routing to different versions of the chat microservice by running the following command in a separate terminal window:

```bash
INGRESS_IP=$(kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
while true; do curl -s http://$INGRESS_IP/chat; echo; done
```

Eventually, you should see the canary deployment complete and all traffic routed to the new version of the chat microservice.