variable "yc_token" {
  description = "OAuth-токен для авторизации в Yandex Cloud"
  type        = string
  sensitive   = true
}

variable "yc_cloud_id" {
  description = "Идентификатор облака (Cloud ID)"
  type        = string
}

variable "yc_folder_id" {
  description = "Идентификатор каталога (Folder ID)"
  type        = string
}

variable "environment" {
  description = "Окружение развертывания (prod, stage, dev)"
  type        = string
  default     = "prod"
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ для доступа к виртуальным машинам"
  type        = string
}
