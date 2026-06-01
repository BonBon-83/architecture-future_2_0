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

variable "pg_version" {
  description = "Версия PostgreSQL"
  type        = string
  default     = "15"
}

variable "pg_disk_size" {
  description = "Размер диска для БД(Гб)"
  type        = number
  default     = 100
}

variable "pg_disk_type" {
  description = "Тип диска для БД"
  type        = string
  default     = "network-ssd"
}

variable "pg_resource_preset" {
  description = "Класс ресурсов для БД (процессор/память)"
  type        = string
  default     = "s2.medium"
}

variable "vm_disk_type" {
  description = "Тип диска для виртуальных машин"
  type        = string
  default     = "network-ssd"
}

variable "vm_image_family" {
  description = "Семейство образа ОС"
  type        = string
  default     = "ubuntu-2204-lts"
}