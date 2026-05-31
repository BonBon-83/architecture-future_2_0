terraform {
  required_version = ">= 1.3.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.129.0"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone = "ru-central1-a"
}
#поиск самого свежего образа Ubuntu 22.04 LTS
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

#СЕТЕВАЯ ИНФРАСТРУКТУРА (VPC & SUBNETS)


resource "yandex_vpc_network" "main" {
  name        = "future-vpc-${var.environment}"
  description = "Основная сеть для ИТ-ландшафта Будущее 2.0"
}

#приватная подсеть для бэкенда и баз данных (Зона А)
resource "yandex_vpc_subnet" "private_a" {
  name           = "private-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.100.1.0/24"]
  route_table_id = yandex_vpc_route_table.private_rt.id
}

#публичная подсеть для портала самообслуживания и NAT (Зона B)
resource "yandex_vpc_subnet" "public_b" {
  name           = "public-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = ["10.100.2.0/24"]
}

#NAT Gateway для выхода приватных инстансов в интернет (для обновлений и API)
resource "yandex_vpc_gateway" "nat" {
  name = "egress-nat-gateway"
  shared_egress_gateway {}
}

#таблица маршрутизации для приватной сети через NAT
resource "yandex_vpc_route_table" "private_rt" {
  name       = "private-route-table"
  network_id = yandex_vpc_network.main.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}


#ГРУППЫ БЕЗОПАСНОСТИ (SECURITY GROUPS)


resource "yandex_vpc_security_group" "db_sg" {
  name        = "database-sg"
  network_id  = yandex_vpc_network.main.id
  description = "Правила доступа к базе данных"

  ingress {
    protocol       = "TCP"
    description    = "Доступ к PostgreSQL от серверов приложений"
    port           = 5432
    v4_cidr_blocks = ["10.100.1.0/24", "10.100.2.0/24"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "web_sg" {
  name        = "web-portal-sg"
  network_id  = yandex_vpc_network.main.id
  description = "Правила доступа к Порталу самообслуживания"

  ingress {
    protocol       = "TCP"
    description    = "HTTP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
    ingress {
    protocol       = "TCP"
    description    = "HTTPS"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}


#ВЫСОКООТКАЗОУСТОЙЧИВАЯ СУБД (POSTGRESQL)


resource "yandex_mdb_postgresql_cluster" "db_cluster" {
  name        = "clinical-fintech-db"
  environment = "PRESTABLE"
  network_id  = yandex_vpc_network.main.id

  config {
    version = 15
    resources {
      resource_preset_id = "s2.medium" # 4 vCPU, 16 GB RAM
      disk_type_id       = "network-ssd"
      disk_size          = 100 #100 ГБ SSD под транзакции клиники и финтеха
    }
  }

  database {
    name  = "clinical_db"
    owner = "app_admin"
  }

  user {
    name     = "app_admin"
    password = "SuperSecurePassword2026!"
  }

  #основной хост базы в приватной зоне А
  host {
    zone             = "ru-central1-a"
    subnet_id        = yandex_vpc_subnet.private_a.id
    assign_public_ip = false
  }

  security_group_ids = [yandex_vpc_security_group.db_sg.id]
}


#ВИРТУАЛЬНЫЕ МАШИНЫ (COMPUTE INSTANCES)


#сервер бэкенда Клиники (в приватной сети)
resource "yandex_compute_instance" "app_server" {
  name        = "clinical-api-server"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 4 #4 ГБ RAM для Go/Java бэкенда клиники
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 30
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.private_a.id
    nat                = false #приватный IP, доступа снаружи нет
        security_group_ids = [yandex_vpc_security_group.db_sg.id] #разрешен доступ к БД
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}

#система отчетов
resource "yandex_compute_instance" "portal_server" {
  name        = "self-service-portal"
  platform_id = "standard-v3"
  zone        = "ru-central1-b"

  resources {
    cores  = 4
    memory = 8 #8 ГБ RAM под Apache Superset / BI Engine
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 50
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.public_b.id
    nat                = true #внешний IP для подключения аналитиков
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${var.ssh_public_key}"
  }
}


#ХРАНИЛИЩЕ МЕДИЦИНСКИХ СНИМКОВ (S3)


#сервисный аккаунт для управления S3
resource "yandex_iam_service_account" "s3_sa" {
  name = "s3-bucket-manager"
}

#роль сервисному аккаунту для работы с Object Storage
resource "yandex_resourcemanager_folder_iam_member" "sa_editor" {
  folder_id = var.yc_folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.s3_sa.id}"
}

#статический ключ доступа для S3-совместимого API
resource "yandex_iam_service_account_static_access_key" "sa_static_key" {
  service_account_id = yandex_iam_service_account.s3_sa.id
  description        = "Ключи доступа к S3 для Clinical API"
}

#бакет S3 для хранения МРТ, КТ и тяжелых файлов исследований
resource "yandex_storage_bucket" "medical_images" {
  bucket     = "future-medical-images-storage"
  access_key = yandex_iam_service_account_static_access_key.sa_static_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_static_key.secret_key

  anonymous_access_flags {
    read = false
    list = false
  }
}
