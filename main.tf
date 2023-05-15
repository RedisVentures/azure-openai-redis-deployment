provider "azurerm" {
   features {}
}

resource "azurerm_resource_group" "anton-tf-rg" {
  name     = "${var.name_prefix}rg"
  location = var.azure_region
}

resource "azurerm_cognitive_account" "anton-tf-openai" {
  name                = "${var.name_prefix}openai"
  location            = azurerm_resource_group.anton-tf-rg.location
  resource_group_name = azurerm_resource_group.anton-tf-rg.name
  kind                = "OpenAI"
  sku_name            = "S0"
  custom_subdomain_name = "${var.name_prefix}openai1"
}

resource "azurerm_cognitive_deployment" "text-davinci-003" {
  name                 = "text-davinci-003"
  cognitive_account_id = azurerm_cognitive_account.anton-tf-openai.id
  model {
    format  = "OpenAI"
    name    = "text-davinci-003"
    version = "1"
  }
  scale {
    type = "Standard"
  }
}
  resource "azurerm_cognitive_deployment" "text-embedding-ada-002" {
  name                 = "text-embedding-ada-002"
  cognitive_account_id = azurerm_cognitive_account.anton-tf-openai.id
  model {
    format  = "OpenAI"
    name    = "text-embedding-ada-002"
    version = "2"
  }

  scale {
    type = "Standard"
  }
}

resource "azurerm_redis_enterprise_cluster" "anton-tf-redisenterprise" {
  name                = "${var.name_prefix}redisenterprise"
  resource_group_name = azurerm_resource_group.anton-tf-rg.name
  location            = azurerm_resource_group.anton-tf-rg.location
  #version             = 6
  sku_name            = "Enterprise_E10-2"
}

resource "azurerm_redis_enterprise_database" "example" {
  name                = "default"
  cluster_id = azurerm_redis_enterprise_cluster.anton-tf-redisenterprise.id
  clustering_policy = "EnterpriseCluster"
  eviction_policy   = "NoEviction"
  //client_protocol =  "Plaintext"
  
  module {
    name = "RediSearch"
  }
}


resource "azurerm_storage_account" "anton-tf-storage" {
  name                     = "${replace(var.name_prefix,"-","")}bucket"
  resource_group_name      = azurerm_resource_group.anton-tf-rg.name
  location                 = azurerm_resource_group.anton-tf-rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
 
resource "azurerm_storage_container" "anton-tf-storage-container" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.anton-tf-storage.name
  container_access_type = "blob"
  
}

resource "azurerm_storage_blob" "tamopsblobs" {
  for_each = fileset(path.module, "docs/*")
 
  name                   = trim(each.key, "docs/")
  storage_account_name   = azurerm_storage_account.anton-tf-storage.name
  storage_container_name = azurerm_storage_container.anton-tf-storage-container.name
  type                   = "Block"
  source                 = each.key
}


resource "azurerm_service_plan" "example" {
  name                = "${var.name_prefix}serviceplan"
  location            = azurerm_resource_group.anton-tf-rg.location
  resource_group_name = azurerm_resource_group.anton-tf-rg.name
  os_type             = "Linux"
  sku_name            = "P1v2"
  

}


resource "azurerm_linux_web_app" "example" {
  name                = "${var.name_prefix}webapp"
  location            = azurerm_resource_group.anton-tf-rg.location
  resource_group_name = azurerm_resource_group.anton-tf-rg.name
  service_plan_id     = azurerm_service_plan.example.id
  https_only = true

  app_settings = {
    OPENAI_API_KEY=azurerm_cognitive_account.anton-tf-openai.primary_access_key
    OPENAI_API_BASE=azurerm_cognitive_account.anton-tf-openai.endpoint
    OPENAI_COMPLETIONS_ENGINE="text-davinci-003"
    OPENAI_EMBEDDINGS_ENGINE="text-embedding-ada-002"
    OPENAI_API_TYPE="azure"
    OPENAI_API_VERSION="2022-12-01"
    REDIS_HOST=azurerm_redis_enterprise_cluster.anton-tf-redisenterprise.hostname
    REDIS_PORT=azurerm_redis_enterprise_database.example.port
    REDIS_PASSWORD=azurerm_redis_enterprise_database.example.primary_access_key
    STORAGE_CONNECTION_STRING=azurerm_storage_account.anton-tf-storage.primary_connection_string
    CONTAINER_NAME=azurerm_storage_container.anton-tf-storage-container.name
  }

  site_config {
    application_stack {
      docker_image     = var.app_docker_image
      docker_image_tag = var.app_docker_tag
    }
  }
}

output "app-url" {
  value = azurerm_linux_web_app.example.default_hostname
}

output "storage-account" {
  value = azurerm_storage_account.anton-tf-storage.name
}

output "storage-container" {
  value = azurerm_storage_container.anton-tf-storage-container.name
}

output "storage-account-connection-string" {
  sensitive = true
  value = azurerm_storage_account.anton-tf-storage.primary_connection_string
}

output "openai-endpoint" {
  value = azurerm_cognitive_account.anton-tf-openai.endpoint
}

output "openai-key" {
  sensitive = true
  value = azurerm_cognitive_account.anton-tf-openai.primary_access_key
}

output "redis-password" {
    sensitive = true
    value=azurerm_redis_enterprise_database.example.primary_access_key
}
output "redis-port" {
    value=azurerm_redis_enterprise_database.example.port
}
output "redis-endpoint" {
    value=azurerm_redis_enterprise_cluster.anton-tf-redisenterprise.hostname
}