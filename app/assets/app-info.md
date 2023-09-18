# Redis Azure OpenAI Template

![Azure OpenAI Redis](https://github.com/redisventures/azure-openai-redis-deployment/blob/main/app/assets/diagram-small.png?raw=true)

Example application allows you to use ChatGPT to analyze the documents, previoslyy unknown to ChatGPT and/or internal to your organization.

There are two data flows in the app. First - batch generation of embedding from the document context. Resulted embedding are stored in Azure Redis Enterprise. Second - using these embeddings to generate the context aware prompt to ChatGPT, so it answers questions, based on the context of the internal documents.

Questions you can try:

- What are the main differences between the three engine types available for the Chevy Colorado? Format response as a table with model as a first column

- What  color options are available? Format as a list

