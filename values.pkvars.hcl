# values.pkrvars.hcl
aws_region           = ""
azure_resource_group = ""
azure_subscription_id = ""
azure_location       = ""
image_prefix         = "php-node-prod"
environment          = "Production"
base_image_version   = "1.0.0"
instance_type        = "t3.small"
azure_vm_size        = "Standard_B2s"
environment = "development"
image_prefix = "php-node-dev"
base_image_version = "dev"
artifactory_url = ""
artifactory_base_ami = "ami-"
artifactory_base_image_name = "base-ubuntu-dev"
artifactory_base_image_resource_group = "base-images-rg"