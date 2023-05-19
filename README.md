# Azure OpenAI Redis Deployment Template

 The terraform template automates the end-to-end deployment of Azure OpenAI applications using Redis Enterprise as a vector database.

![Azure OpenAI Redis](app/assets/diagram.png)

In a single terraform script it deploys:

- Azure OpenAI instance with `text-davinci-003` and `text-embedding-ada-002` models
- Azure Redis Enterprise as a vector Database
- Azure Storage bucket with all the files from the `./docs` folder
- Azure Web App

## Example application

An example application used in this repo allows you to use ChatGPT to analyze the documents, previously unknown to ChatGPT and/or internal to your organization.

There are two data flows in the app. First - batch generation of embedding from the document context. These embeddings are stored in Azure Redis Enterprise. Second - using these embeddings to generate the context-aware prompt to ChatGPT, so it answers questions, based on the context of the internal documents.

Questions you can try:

- What are the main differences between the three engine types available for the Chevy Colorado? Format the response as a table with the model as a first column

- What color options are available? Format as a list

App credits - https://github.com/RedisVentures/LLM-Document-Chat


## Deploying the app

Authenticate Azure CLI to your Azure account:

```
az login
```
Deploy terraform configuration:
```
terraform init
terraform apply
```

You can add your own documents to the `./docs` folder (PDF or plain text), so they can be uploaded to the bucket during the deployment.

It might take up to 20 minutes to provision all the required infrastructure.

At the end terraform script would output a bunch of the variables.
```
app-url = "redis-openai-83903-webapp.azurewebsites.net"
openai-endpoint = "https://redis-openai-83903.openai.azure.com/"
openai-key = <sensitive>
redis-endpoint = "redis-openai-83903-redisenterprise.southcentralus.redisenterprise.cache.azure.net"
redis-password = <sensitive>
redis-port = 10000
storage-account = "redisopenai83903bucket"
storage-account-connection-string = <sensitive>
storage-container = "data"
```

app-url can be used to immediately access the application.

## Configuration

Use `terraform.tfvars` or `terraform apply -var="name_prefix=my-deployment"` to override the default resource name prefix and container image to deploy with the webapp. 

To change the application, deployed as an Azure Web App - change `app_docker_image` and `app_docker_tag` values in the `terraform.tfvars`. The source code for the default application is included in this repo under the `./app` folder.

## Pererequisites and Limitations

Azure account, Azure CLI, Terraform CLI installed locally.

Azure Open AI currently (May 2023) is in the private preview. You need to [submit the request](https://customervoice.microsoft.com/Pages/ResponsePage.aspx?id=v4j5cvGGr0GRqy180BHbR7en2Ais5pxKtso_Pz4b1_xUOFA5Qk1UWDRBMjg0WFhPMkIzTzhKQ1dWNyQlQCN0PWcu) to Microsoft to enable it for your account.

Azure OpenAI embedding API currently has strict limits on the request frequency, which might make it not feasible for a bulk embedding generation. Consider using local embedding such as:
```
  from langchain.embeddings import HuggingFaceEmbeddings
  embeddings = HuggingFaceEmbeddings(model_name="all-MiniLM-L6-v2")
```

## Testing locally

While Azure OpenAI and Azure Redis Enterprise can not be deployed locally, you can use your local machine for testing the application itself.

After running the `terraform apply` you can use the generated Azure services to test your application code locally. Use .env.template as an example and populate it with actual keys and URLs.

```
docker build -t llm-chat .  
docker run -it -p 80:80 --env-file=.env llm-chat
```

Building/pushing the multiplatform image (useful for local development on Mac/ARM):

```
docker buildx build --platform linux/amd64,linux/arm64 -t antonum/llmchat:latest --push  .
```

## Troubleshooting

- **Problem:** `azurerm_cognitive_account.openai` stuck in `creating` phase. 

At the time of writing (May 2023) Azure occasionally experiencing problems deploying OpenAI services. Try deploying the stack in another region. For instance set `azure_region = "southcentralus"` instead of `eastus`. 

- **Problem**: Deployment fails with an error: `SpecialFeatureOrQuotaIdRequired: The subscription does not have QuotaId/Feature required by SKU 'S0' from kind 'OpenAI'`

Your Azure account does not have Azure OpenAI enabled. At the time of writing (May 2023) Azure OpenAI is in private preview. You need to [submit the request](https://customervoice.microsoft.com/Pages/ResponsePage.aspx?id=v4j5cvGGr0GRqy180BHbR7en2Ais5pxKtso_Pz4b1_xUOFA5Qk1UWDRBMjg0WFhPMkIzTzhKQ1dWNyQlQCN0PWcu) to Microsoft to enable it for your subscription.

## Cleanup

To destroy all the resources deployed run:
```
terraform destroy
```
