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

To test the ChatAPI, you can run the following commands in the terminal:

> NOTE: The question you ask may take a few minutes to complete initially; therefore, it is advisable to show this from the terminal and show how you expect the chatbot to answer based on code in [src/ChatApi/Program.cs](src/ChatApi/Program.cs) before demoing the chat functionality in the eShop web application.

```bash
# get the ingress IP address of the Istio ingress gateway
INGRESS_IP=$(kubectl get svc -n aks-istio-ingress aks-istio-ingressgateway-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# ask a question
curl -v http://$INGRESS_IP/chat -H "Content-Type: application/json" -d '{"text": "do you sell mugs"}'
```

To demo the eShop application, you can use the following steps:

1. Open the Azure portal and navigate to the Azure App Configuration service
1. Click on the configuration store and navigate to the "Feature management" section
1. Click on the "Chat" feature flag and set the value to `true`
1. Navigate to the eShop application and refresh the page, after a few seconds you should see a chat icon in the upper right corner of the page
1. Ask a question in the chat window and you should see a response from the OpenAI service

To demo how Istio service mesh can help you launch new versions of the application, you can use the following steps:

1. Open [src/ChatApi/Program.cs](src/ChatApi/Program.cs) in VS Code and update the text `eShopBot v1.0` to `eShopBot v1.1`, save the changes, then use the `az acr build` command to build and publish the new version of the application to Azure Container Registry
1. Once the new version of the ChatAPI is published, you update the `kustomization.yaml` to use the various `chatapi-dark-launch.yaml` and `chatapi-weighted-launch.yaml` files and point to the new version of the image.

To test "dark" launch:

```bash
curl -v http://$INGRESS_IP/chat -H "x-istio-msbuild: brk225h"
```

To test "weighted" launch:

```bash
while true; do curl -s http://$INGRESS_IP/chat; echo; done
```

For Flagger demos, you can use the following steps to deploy the Flagger controller:

```bash
helm repo add flagger https://flagger.app

helm install flagger flagger/flagger \
     --namespace=aks-istio-system \
     --set meshProvider=istio \
     --set prometheus.install=true

kubectl get po -n aks-istio-system

helm install flagger-loadtester flagger/loadtester \
--namespace=eshop \
--set cmd.timeout=1h \
--set cmd.namespaceRegexp=''
```

To create a Canary deployment, delete the existing ChatApi resources in the cluster and add the `chatapi-canary-launch.yaml` file to the `kustomization.yaml` file.