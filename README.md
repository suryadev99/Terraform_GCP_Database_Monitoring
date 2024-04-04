## Terraform DBRE Task - Provisioning resources in GCP using Terraform
##### We will use Terraform to define the infrastructure as code in GCP. 
###### Here is an outline of the files in the repository:
- main.tf: This file contains the main Terraform code for provisioning the resources in GCP. 
(We could have used logical groupings of resources with its own files like instances.tf for all the instances information and grouping them together if provisioning is large. This makes the code easy to read and understand)
- variables.tf: This file contains the input variables that the Terraform code requires.
- outputs.tf: This file contains the output variables that the Terraform code generates.(If you are sharing this output with others, or in the case its publicly available because of automated deployment processes , its important to hide this data in the output.)
- There should be another file terraform.tfvars (Not attached with the mail) where you pass all the variable values.We can use a open source tool like pass to store the variables.(For highly secure environments we can make us of google key management service or any other secret managers)


### Primary Database

-  I chose a custom  db-custom-2-7680 machine type, which has 2 vCPUs, 7.5 GB of memory and is classified as a general-purpose machine type. I chose this machine type because it provides a good balance between cost and performance. (We could change this based on the specific usecase)
- Network Configuration -  A VPC network is defined using the google_compute_network resource, and a subnetwork are defined using the google_compute_subnetwork resource.
- enabled SSL (it provides a secure way to transmit data between the database client and the server over the network. SSL provides encryption of data in transit.)
- The backup_configuration is enabled, meaning that backups will be automatically created for the instance. 
- We initialize the pgbench schema by connecting to the primary PostgreSQL instance using the postgres user.
This will create a new database called pgbench and initialize it with the pgbench schema.(We could have defined the pgbench script separately inside a script file)

### Standby Database
- Machine Type: db-custom-2-7680 - We use the same machine type as the primary instance to ensure that the standby database has enough resources to replicate the primary database effectively.
- Network Configuration- We use the same network configuration as the primary instance.

## Virtual Private cloud
- google_compute_network: This resource creates a VPC network. In this case, the auto_create_subnetworks is set to false, meaning that no subnets will be created automatically. Instead, a separate resource is used to create the subnet.
- google_compute_subnetwork: This resource creates a subnet within the VPC network. It is associated with the VPC network created above, and its ip_cidr_range specifies the IP address range that the subnet will use.
- google_compute_global_address: This resource creates a global IP address that can be used for VPC peering. 
- google_service_networking_connection: This resource creates a VPC network peering connection 


### Cloud Storage
- Location: We choose a location closest to the instances to reduce latency and improve performance.     (Eg:asia-south1)
- Retention Period: 15 days - We set a retention period of 15 days to ensure that we have enough backups to recover from any failures, but we don't store backups indefinitely, which can be expensive.
- Boot Disk Size: 50 GB - This should be sufficient to store the data. (This could be less depending on the requirement) . The Debian 10 image is a popular and stable choice for Linux-based instances. 
- google_compute_instance: This resource creates a Compute Engine instance that will be used to generate a daily backup of the primary database and upload it to the Cloud Storage bucket. The machine_type is set to e2-micro, which is a small machine type suitable for simple tasks like this. The boot_disk is a Debian 10 image with a size of 50.
- metadata_startup_script  - This script creates a backup script under /var/backup and sets up a new cron job to execute it every day at midnight. The backup file is created with a timestamp in its name and compressed using gzip. The script then uploads the backup file to the Cloud Storage bucket using the gsutil command-line tool. (Ideally the script should be places in a different file in a separate /scripts folder, for simplicity Im not defining it in the code itself.We assume that the gsutil command-line tool is already installed on the instance. If it is not, we need to install it by adding the following line to the startup script:
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud init
gcloud components install gsutil)


### Monitoring
- Metric: cloudsql.googleapis.com/database/cpu/utilization - We use this metric to monitor CPU usage on the primary instance. We set a threshold of 90% to alert us when CPU usage is high.We calculate by taking the rolling mean of cpu usage for a duration of 1 minute and it is triggered when the value is greater than the threhold.
- Metric: cloudsql.googleapis.com/database/disk/utilization - We use this metric to monitor disk usage on the primary instance. We set a threshold of 85% to alert us when disk usage is high.
We calculate by taking the rolling mean of disk usage for a duration of 1 minute and it is triggered when the value is greater than the threhold
- We also specify a notification_channels array that includes the email notification channel.



To use Terraform to provision resources in GCP, we need to set up a project and credentials that Terraform can use to authenticate with GCP. Here are the steps:

- Take an existing GCp account or create a new GCP project in the GCP console.
- Create a service account for Terraform in the GCP project and download a JSON key file for the account.
- Enable the necessary GCP APIs for the resources we will be using (Compute Engine API, Sql Admin API, and Cloud Monitoring API, Service Networking API).
Note that we will not cover these steps in detail as they are outside the scope of this assignment.
- Grant the service account the necessary IAM roles for the APIs we will be using (Compute network admin, Compute Storage Admin, Monitoring Admin etc).
- Once we have set up a GCP project and downloaded a JSON key file for the service account, we can use it to authenticate with GCP in our Terraform code.
- Create the terraform code and configure resources using main.tf , variable.tf and output.tf as mentioned above.
- Once the code is comple we can initialize the terraform directory using 'terraform init' command,
- Terraform will generate a plan of the changes it will make and prompt you to confirm before making any changes using 'terrafom plan' and 'terraform validate'.
- Apply the configuration and run the Terraform apply command to create the resources.
- Test and modify the configuration: Once the resources are created, test that they are working as expected. 
You can modify the Terraform code to make changes to the resources and use the Terraform apply command to apply the changes.(We can even make use Automated tests for the terraform code using tools such as Terratest)


## Additional Points
- We can deploy the GCp infrastructure using terraform by using azure devops pipeline (also gitops) for better versioning and automation of the tasks.

