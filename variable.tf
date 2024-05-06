variable "project_id" {
  description = "The GCP project ID"
}

variable "region" {
  description = "The region where the resources will be provisioned"
  default     = "asia-south1"
}

variable "zone" {
  description = "The zone where the resources will be provisioned"
  default     = "asia-south1-a"
}


variable "postgres_version" {
  description = "The PostgreSQL version"
  default     = "13"
}

variable "primary_instance_name" {
  description = "The name of the primary instance"
}
variable "machine_tier" {
  description = "The tier of the instance"
}

variable "standby_instance_name" {
  description = "The name of the standby instance"
}

variable "postgres_user" {
  description = "The PostgreSQL user"
  default     = "postgres"
}

variable "postgres_password" {
  description = "The PostgreSQL password"
  sensitive   = true
}

variable "postgres_db" {
  description = "The PostgreSQL database name"
}

variable "backup_bucket_name" {
  description = "The name of the Cloud Storage bucket to store backups"
}


variable "backup_retention_period" {
  description = "The number of days to retain backups"
  default     = "15"
}

variable "notification_channel_name" {
  description = "The email notification channel name"
  default     = "Notification Channel"
}

variable "notification_channel_mail" {
  description = "The email notification channel mail address"
}

variable "vpc_network_name" {
  description = "vpc network name"
}

variable "vpc_subnet_name" {
  description = "vpc subnet name"
}

variable "vpc_subnet_range" {
  description = "vpc subnet range"
  sensitive   = true
}

variable "compute_instance_disk_size" {
  description = "disk size of compute instance"
}

variable "google_credentials" {
  description = "The path to the Google Cloud Platform credentials file"
}
