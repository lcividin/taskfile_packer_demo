# Base variables
variable "environment" {
  type        = string
  description = "Environment (dev/staging/prod)"
  default     = "dev"
}

variable "image_prefix" {
  type        = string
  description = "Prefix for image names"
  default     = "php-node-composer"
}

variable "base_image_version" {
  type        = string
  description = "Version tag for the images"
  default     = "latest"
}

# Artifactory variables
variable "artifactory_url" {
  type        = string
  description = "JFrog Artifactory URL (e.g., artifactory.company.com)"
}

variable "artifactory_username" {
  type        = string
  description = "Artifactory username"
  sensitive   = true
}

variable "artifactory_password" {
  type        = string
  description = "Artifactory password"
  sensitive   = true
}

variable "artifactory_base_ami" {
  type        = string
  description = "AMI ID from Artifactory for AWS builds"
}

variable "artifactory_base_image_name" {
  type        = string
  description = "Base image name from Artifactory for Azure builds"
}

variable "artifactory_base_image_resource_group" {
  type        = string
  description = "Resource group containing the base image in Azure"
}

# AWS variables
variable "aws_region" {
  type        = string
  description = "AWS region for building AMI"
  default     = "us-west-2"
}

variable "instance_type" {
  type        = string
  description = "AWS EC2 instance type"
  default     = "t3.micro"
}

# Azure variables
variable "azure_subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "azure_resource_group" {
  type        = string
  description = "Azure resource group name"
  default     = "packer-resource-group"
}
