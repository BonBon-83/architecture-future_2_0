output "vpc_network_id" {
  description = "ID созданной виртуальной сети VPC"
  value       = yandex_vpc_network.main.id
}

output "portal_public_ip" {
  description = "Внешний (публичный) IP-адрес системы отчетности"
  value       = yandex_compute_instance.portal_server.network_interface[0].nat_ip_address
}

output "clinical_api_private_ip" {
  description = "Внутренний IP-адрес бэкенда клиники"
  value       = yandex_compute_instance.app_server.network_interface[0].ip_address
}

output "postgres_cluster_id" {
  description = "ID управляемого кластера PostgreSQL"
  value       = yandex_mdb_postgresql_cluster.db_cluster.id
}

output "medical_s3_bucket_name" {
  description = "Имя созданного S3 бакета для медицинских снимков"
  value       = yandex_storage_bucket.medical_images.bucket
}
