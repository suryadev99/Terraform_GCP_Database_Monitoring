output "postgres_instance_ip" {
  value     = google_sql_database_instance.primary_instance.ip_address
  sensitive = true
}

output "backup_bucket_name" {
  value = google_storage_bucket.backup.name
}
