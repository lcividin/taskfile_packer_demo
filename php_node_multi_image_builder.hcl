packer {
  required_plugins {
    docker = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/docker"
    }
    amazon = {
      version = ">= 1.2.6"
      source  = "github.com/hashicorp/amazon"
    }
    azure = {
      version = ">= 1.0.8"
      source  = "github.com/hashicorp/azure"
    }
  }
}

locals {
  timestamp = formatdate("YYYY-MM-DD-hhmmss", timestamp())
  docker_registry = "${var.artifactory_url}/docker-local"
  vm_registry     = "${var.artifactory_url}/vm-local"
  repo_base_url   = "${var.artifactory_url}/repo"
}

# Docker source configuration using Artifactory
source "docker-image" "php_node_dev" {
  image  = "${local.docker_registry}/amazonlinux:2023"
  commit = true
  login = true
  login_server = local.docker_registry
  login_username = var.artifactory_username
  login_password = var.artifactory_password

  build_args = {
    ENVIRONMENT = var.environment
    ARTIFACTORY_URL = var.artifactory_url
    ARTIFACTORY_USERNAME = var.artifactory_username
    ARTIFACTORY_PASSWORD = var.artifactory_password
  }
  changes = [
    "EXPOSE 80",
    "CMD [\"php\", \"-S\", \"0.0.0.0:80\"]"
  ]
  tag = ["${var.image_prefix}:${var.base_image_version}"]
}

# AWS source configuration using Artifactory
source "amazon-ebs" "php_node" {
  ami_name      = "${var.image_prefix}-${local.timestamp}"
  instance_type = var.instance_type
  region        = var.aws_region

  source_ami_filter {
    filters = {
      image-id = var.artifactory_base_ami
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["self"]
  }

  ssh_username = "ec2-user"

  tags = {
    Name        = var.image_prefix
    Environment = var.environment
    Created     = formatdate("YYYY-MM-DD", timestamp())
    Source      = "Artifactory"
    Version     = var.base_image_version
  }
}

# Azure source configuration using Artifactory
source "azure-arm" "php_node" {
  subscription_id = var.azure_subscription_id
  
  managed_image_resource_group_name = var.azure_resource_group
  managed_image_name               = "${var.image_prefix}-${local.timestamp}"

  custom_managed_image_name = var.artifactory_base_image_name
  custom_managed_image_resource_group_name = var.artifactory_base_image_resource_group

  location = var.azure_location
  vm_size  = var.azure_vm_size

  azure_tags = {
    Environment = var.environment
    Created     = formatdate("YYYY-MM-DD", timestamp())
    Source      = "Artifactory"
    Version     = var.base_image_version
  }
}

build {
  sources = [
    "source.docker-image.php_node_dev",
    "source.amazon-ebs.php_node",
    "source.azure-arm.php_node"
  ]

  provisioner "shell" {
    environment_vars = [
      "ARTIFACTORY_URL=${var.artifactory_url}",
      "ARTIFACTORY_USERNAME=${var.artifactory_username}",
      "ARTIFACTORY_PASSWORD=${var.artifactory_password}",
      "ENVIRONMENT=${var.environment}"
    ]

    inline = [
      "#!/bin/bash",
      "set -e",
      
      # Configure package manager to use Artifactory
      "echo \"Setting up Artifactory repository configurations...\"",
      
      # Configure yum/apt to use Artifactory
      "if command -v yum &> /dev/null; then",
      "    # Create a backup of the original repo files",
      "    mkdir -p /etc/yum.repos.d/backup",
      "    mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/backup/",
      "",
      "    # Create new repo file for Artifactory",
      "    cat > /etc/yum.repos.d/artifactory.repo << EOF",
      "[artifactory-base]",
      "name=Artifactory Repository Base",
      "baseurl=${local.repo_base_url}/yum-local/\$basearch",
      "enabled=1",
      "gpgcheck=0",
      "username=${var.artifactory_username}",
      "password=${var.artifactory_password}",
      "EOF",
      "elif command -v apt-get &> /dev/null; then",
      "    # Configure apt to use Artifactory",
      "    echo \"deb ${local.repo_base_url}/debian-local stable main\" > /etc/apt/sources.list.d/artifactory.list",
      "    echo \"machine ${var.artifactory_url}\" > /etc/apt/auth.conf",
      "    echo \"login ${var.artifactory_username}\" >> /etc/apt/auth.conf",
      "    echo \"password ${var.artifactory_password}\" >> /etc/apt/auth.conf",
      "    chmod 600 /etc/apt/auth.conf",
      "fi",
      
      # Install base packages
      "if command -v yum &> /dev/null; then",
      "    yum update -y",
      "    yum install -y gcc make curl wget zip unzip git",
      "elif command -v apt-get &> /dev/null; then",
      "    export DEBIAN_FRONTEND=noninteractive",
      "    apt-get update",
      "    apt-get upgrade -y",
      "    apt-get install -y gcc make curl wget zip unzip git",
      "fi",
      
      # Install PHP and extensions from Artifactory
      "if command -v yum &> /dev/null; then",
      "    yum install -y php php-cli php-common php-json php-xml php-mbstring php-pdo php-mysqlnd php-curl",
      "else",
      "    apt-get install -y php php-cli php-common php-json php-xml php-mbstring php-pdo php-mysql php-curl",
      "fi",
      
      # Install Composer from Artifactory
      "curl -u ${var.artifactory_username}:${var.artifactory_password} ${local.repo_base_url}/composer-local/composer-setup.php -o composer-setup.php",
      "php composer-setup.php",
      "mv composer.phar /usr/local/bin/composer",
      "chmod +x /usr/local/bin/composer",
      "rm composer-setup.php",
      
      # Configure Composer to use Artifactory
      "composer config -g repositories.artifactory composer ${local.repo_base_url}/composer-local",
      
      # Install Node.js and npm from Artifactory
      "if command -v yum &> /dev/null; then",
      "    curl -u ${var.artifactory_username}:${var.artifactory_password} ${local.repo_base_url}/nodejs-local/setup_18.x -o setup_18.x",
      "    bash setup_18.x",
      "    rm setup_18.x",
      "    yum install -y nodejs",
      "else",
      "    curl -u ${var.artifactory_username}:${var.artifactory_password} ${local.repo_base_url}/nodejs-local/setup_18.x -o setup_18.x",
      "    bash setup_18.x",
      "    rm setup_18.x",
      "    apt-get install -y nodejs",
      "fi",
      
      # Configure npm to use Artifactory
      "npm config set registry ${local.repo_base_url}/npm-local/",
      "npm config set _auth $(echo -n \"${var.artifactory_username}:${var.artifactory_password}\" | base64)",
      "npm config set always-auth true",
      
      # Verify
      "php --version",
      "composer --version",
      "node --version",
      "npm --version",
      
      # Clean up
      "if command -v yum &> /dev/null; then",
      "    yum clean all",
      "    rm -rf /var/cache/yum",
      "else",
      "    apt-get clean",
      "    rm -rf /var/lib/apt/lists/*",
      "fi"
    ]
  }

  # Post-processors for Docker
  post-processor "docker-tag" {
    repository = "${local.docker_registry}/${var.image_prefix}"
    tags       = [var.base_image_version, "latest"]
    only       = ["docker-image.php_node_dev"]
  }

  post-processor "docker-push" {
    login = true
    login_server = local.docker_registry
    login_username = var.artifactory_username
    login_password = var.artifactory_password
    only       = ["docker-image.php_node_dev"]
  }
}