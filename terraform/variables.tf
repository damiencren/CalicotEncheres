variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

variable "code_identification" {
  description = "Code d'identification unique pour les ressources"
  default     = "team3"
}

variable "location" {
  description = "Région Azure pour les ressources"
  default     = "Canada Central"
}

variable "vnet_address_space" {
  description = "Plage d'adresses pour le Virtual Network"
  default     = ["10.0.0.0/16"]
}

variable "snet_web_address_prefix" {
  description = "Plage d'adresses pour le sous-réseau Web"
  default     = ["10.0.1.0/24"]
}

variable "snet_db_address_prefix" {
  description = "Plage d'adresses pour le sous-réseau Base de Données"
  default     = ["10.0.2.0/24"]
}
