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
