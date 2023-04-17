provider "google" {
  credentials = file(var.google_credentials)
  project     = var.project_id
}

# Create VPC network
resource "google_compute_network" "vpc" {
  name                    = var.vpc_network_name
  auto_create_subnetworks = false
}

# Create VPC subnet
resource "google_compute_subnetwork" "primary_sub" {
  name          = var.vpc_subnet_name
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.vpc_subnet_range
  region        = var.region

}

# To create a  IP address that can be used for VPC peering
resource "google_compute_global_address" "private_ip_address" {
  name          = google_compute_network.vpc.name
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc.name
}

# To creates a VPC network peering connection 
resource "google_service_networking_connection" "vpc_connection" {
  network = google_compute_network.vpc.self_link
  service = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [
    google_compute_network.vpc.name
  ]
  depends_on = [
  google_compute_network.vpc, google_compute_subnetwork.primary_sub]
}

# To creata a PostgreSQL database instance 
resource "google_sql_database_instance" "primary_instance" {
  name             = var.primary_instance_name
  database_version = var.postgres_version
  region           = var.region

  depends_on = [google_compute_subnetwork.primary_sub,
  google_service_networking_connection.vpc_connection]

  settings {
    tier = var.machine_tier
    backup_configuration {
      enabled = true
    }


    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.vpc.self_link
      require_ssl     = true
    }

  }

}

#Create sql database for the primary instance
resource "google_sql_database" "postgres_db" {
  name     = var.postgres_db
  instance = google_sql_database_instance.primary_instance.name
  depends_on = [
    google_sql_database_instance.primary_instance
  ]
}

#Create sql database user for the primary instance
resource "google_sql_user" "postgres_user" {
  name     = var.postgres_user
  instance = google_sql_database_instance.primary_instance.name
  password = var.postgres_password
  depends_on = [
    google_sql_database_instance.primary_instance
  ]
}

#To initiate the pgbench schema and generate test data
resource "null_resource" "pgbench" {
  triggers = {
    always_run = timestamp()
  }
  provisioner "local-exec" {
    command = "sudo apt-get update && sudo apt-get install -y postgresql-client && sleep 10 && pgbench -i -h ${google_sql_database_instance.primary_instance.first_ip_address} -U ${google_sql_user.postgres_user.name} ${google_sql_database.postgres_db.name}"
  }

  depends_on = [
    google_sql_database_instance.primary_instance,
    google_sql_database.postgres_db,
    google_sql_user.postgres_user
  ]
}


# Create the standby PostgreSQL instance
resource "google_sql_database_instance" "standby_replica" {
  name                 = "standby-postgres-instance"
  database_version     = var.postgres_version
  master_instance_name = google_sql_database_instance.primary_instance.name
  region               = var.region

  settings {
    tier      = var.machine_tier
    disk_size = "100"

    ip_configuration {
      ipv4_enabled    = true
      private_network = google_compute_network.vpc.self_link
      require_ssl     = true
    }

  }

  replica_configuration {
    failover_target = false
  }
  depends_on = [
    google_sql_database_instance.primary_instance,
    google_sql_database.postgres_db,
    google_sql_user.postgres_user
  ]
}


# Create a Cloud Storage bucket for backups
resource "google_storage_bucket" "backup" {
  name          = var.backup_bucket_name
  location      = var.region
  force_destroy = true
  lifecycle_rule {
    condition {
      age = var.backup_retention_period
    }
    action {
      type = "Delete"
    }
  }
}


# Create a cron job to generate a daily backup of the primary database and upload to Cloud Storage
resource "google_compute_instance" "backup" {
  name         = "backup-instance"
  machine_type = "e2-micro"
  zone         = var.zone
  depends_on   = [google_storage_bucket.backup]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
      size  = var.compute_instance_disk_size
    }
  }


  metadata_startup_script = <<EOF
#!/bin/bash
sudo apt-get update
sudo apt-get install -y postgresql-client
gsutil mb gs://${var.backup_bucket_name}
crontab -l > backup_cron
echo "0 0 * * * pg_dump -Fc --no-acl --no-owner -h ${google_sql_database_instance.standby_replica.first_ip_address} -U ${var.postgres_user} ${var.postgres_db} | gsutil cp - gs://${var.backup_bucket_name}/backup-\$(date +\%Y\%m\%d_\%H\%M)" >> backup_cron
crontab backup_cron
EOF

  network_interface {
    network    = google_compute_network.vpc.self_link
    subnetwork = google_compute_subnetwork.primary_sub.self_link
  }
}

# Create a email notification channel for monitoring
resource "google_monitoring_notification_channel" "email" {
  display_name = var.notification_channel_name
  type         = "email"

  labels = {
    email_address = var.notification_channel_mail
  }
}

# Create google monitoring policy for CPU usage
resource "google_monitoring_alert_policy" "cpu_usage_policy" {
  display_name = "CPU Usage Alert Policy"

  combiner = "OR"

  conditions {
    display_name = "High CPU Usage"

    condition_threshold {
      aggregations {
        alignment_period     = "60s"
        cross_series_reducer = "REDUCE_NONE"
        per_series_aligner   = "ALIGN_MEAN"
      }

      filter          = "metric.type=\"cloudsql.googleapis.com/database/cpu/utilization\" AND resource.type=\"cloudsql_database\" AND metadata.system_labels.name=\"${var.primary_instance_name}\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.9

      trigger {
        count = 1
      }
    }
  }
  depends_on = [
    google_monitoring_notification_channel.email,
    google_sql_database_instance.primary_instance
  ]

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]
}

# Create google monitoring policy for disk usage
resource "google_monitoring_alert_policy" "disk_usage_policy" {
  display_name = "Disk Usage Alert Policy"

  combiner = "OR"

  conditions {
    display_name = "High Disk Usage"

    condition_threshold {
      aggregations {
        alignment_period     = "60s"
        cross_series_reducer = "REDUCE_NONE"
        per_series_aligner   = "ALIGN_MEAN"
      }
      filter          = "metric.type=\"cloudsql.googleapis.com/database/disk/utilization\" AND resource.type=\"cloudsql_database\" AND metadata.system_labels.name=\"${var.primary_instance_name}\""
      duration        = "60s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0.85

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [
    google_monitoring_notification_channel.email.id
  ]
  depends_on = [
    google_monitoring_alert_policy.cpu_usage_policy
  ]
}
