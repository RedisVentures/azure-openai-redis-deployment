variable "azure_region" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "name_prefix" {
  description = "common prefix for naming Azure resources"
  type        = string
  default     = "anton-tf-"
}
variable "generative_model" {
  description = "Generative model to use"
  type        = string
  default     = "gpt-35-turbo"
}
variable "embeddings_model" {
  description = "Embeddings model to use"
  type        = string
  default     = "text-embedding-ada-002"
}
variable "generative_model_version" {
  description = "Generative model version to use"
  type        = string
  default     = "0613"
}
variable "embeddings_model_version" {
  description = "Embeddings model version to use"
  type        = string
  default     = "2"
}
variable "app_docker_image" {
  description = "docker image to use for the web app. Image should expose port 80"
  type        = string
  default     = "antonum/llmchat"
}

variable "app_docker_tag" {
  description = "docker image tag to use for the web app."
  type        = string
  default     = "latest"
}
