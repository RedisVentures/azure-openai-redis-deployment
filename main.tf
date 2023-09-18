provider "azurerm" {
  features {}
}

# Generate a random integer to create a globally unique name
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

resource "azurerm_resource_group" "rg" {
  name     = "${var.name_prefix}-${random_integer.ri.result}-rg"
  location = var.azure_region
}

resource "azurerm_cognitive_account" "openai" {
  name                  = "${var.name_prefix}-${random_integer.ri.result}-openai"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  kind                  = "OpenAI"
  sku_name              = "S0"
  custom_subdomain_name = "${var.name_prefix}-${random_integer.ri.result}"
  timeouts {
    create = "60m"
  }
}

resource "azurerm_cognitive_deployment" "gen-model" {
  name                 = var.generative_model
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = var.generative_model
    version = var.generative_model_version
  }
  scale {
    type = "Standard"
  }
}
resource "azurerm_cognitive_deployment" "embeddings_model" {
  name                 = var.embeddings_model
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = var.embeddings_model
    version = var.embeddings_model_version

  }
  scale {
    type = "Standard"
  }
  //depends_on = [ azurerm_cognitive_deployment.gen-model ]
}

resource "azurerm_redis_enterprise_cluster" "redisenterprise" {
  name                = "${var.name_prefix}-${random_integer.ri.result}-redisenterprise"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  #version             = 6
  sku_name = "Enterprise_E10-2"
}

resource "azurerm_redis_enterprise_database" "redis-db" {
  name              = "default"
  cluster_id        = azurerm_redis_enterprise_cluster.redisenterprise.id
  clustering_policy = "EnterpriseCluster"
  eviction_policy   = "NoEviction"
  #client_protocol =  "Plaintext"

  module {
    name = "RediSearch"
  }
}


resource "azurerm_storage_account" "storage-acct" {
  name                     = "${replace(var.name_prefix, "-", "")}${random_integer.ri.result}bucket"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "storage-acct-container" {
  name                  = "data"
  storage_account_name  = azurerm_storage_account.storage-acct.name
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "tamopsblobs" {
  for_each = fileset(path.module, "docs/*")

  name                   = trim(each.key, "docs/")
  storage_account_name   = azurerm_storage_account.storage-acct.name
  storage_container_name = azurerm_storage_container.storage-acct-container.name
  type                   = "Block"
  source                 = each.key
}


resource "azurerm_service_plan" "plan" {
  name                = "${var.name_prefix}-${random_integer.ri.result}-serviceplan"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "P1v2"
}

resource "azurerm_linux_web_app" "app" {
  name                = "${var.name_prefix}-${random_integer.ri.result}-webapp"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  app_settings = {
    OPENAI_API_KEY            = azurerm_cognitive_account.openai.primary_access_key
    OPENAI_API_BASE           = azurerm_cognitive_account.openai.endpoint
    OPENAI_COMPLETIONS_ENGINE = var.generative_model
    OPENAI_EMBEDDINGS_ENGINE  = var.embeddings_model
    OPENAI_API_TYPE           = "azure"
    OPENAI_API_VERSION        = "2023-05-15"
    REDIS_HOST                = azurerm_redis_enterprise_cluster.redisenterprise.hostname
    REDIS_PORT                = azurerm_redis_enterprise_database.redis-db.port
    REDIS_PASSWORD            = azurerm_redis_enterprise_database.redis-db.primary_access_key
    STORAGE_CONNECTION_STRING = azurerm_storage_account.storage-acct.primary_connection_string
    CONTAINER_NAME            = azurerm_storage_container.storage-acct-container.name
  }

  site_config {
    application_stack {
      docker_image     = var.app_docker_image
      docker_image_tag = var.app_docker_tag
    }
  }
}

output "app-url" {
  value = azurerm_linux_web_app.app.default_hostname
}

output "storage-account" {
  value = azurerm_storage_account.storage-acct.name
}

output "storage-container" {
  value = azurerm_storage_container.storage-acct-container.name
}

output "storage-account-connection-string" {
  sensitive = true
  value     = azurerm_storage_account.storage-acct.primary_connection_string
}

output "openai-endpoint" {
  value = azurerm_cognitive_account.openai.endpoint
}

output "openai-key" {
  sensitive = true
  value     = azurerm_cognitive_account.openai.primary_access_key
}

output "redis-password" {
  sensitive = true
  value     = azurerm_redis_enterprise_database.redis-db.primary_access_key
}
output "redis-port" {
  value = azurerm_redis_enterprise_database.redis-db.port
}
output "redis-endpoint" {
  value = azurerm_redis_enterprise_cluster.redisenterprise.hostname
}
