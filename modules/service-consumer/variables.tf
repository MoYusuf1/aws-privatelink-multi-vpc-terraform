variable "name" {
  description = "Consumer name, used as a prefix (for example \"payments\")."
  type        = string
}

variable "vpc_id" {
  description = "Consumer VPC."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the interface endpoint, one per AZ. Must be in AZs the endpoint service supports."
  type        = list(string)
}

variable "service_name" {
  description = "Endpoint service name published by the provider (com.amazonaws.vpce.<region>.vpce-svc-...)."
  type        = string
}

variable "service_port" {
  description = "TCP port of the shared service."
  type        = number
  default     = 443
}

variable "service_hostname" {
  description = "Private hostname callers use, for example app.shared.internal. Needs at least three labels."
  type        = string

  validation {
    condition     = length(split(".", var.service_hostname)) >= 3
    error_message = "service_hostname needs at least three labels, for example app.shared.internal."
  }
}

variable "create_test_client" {
  description = "Create a small EC2 client plus an EC2 Instance Connect Endpoint for testing."
  type        = bool
  default     = true
}

variable "instance_type" {
  description = "Instance type for the test client."
  type        = string
  default     = "t3.micro"
}

variable "ami_ssm_parameter" {
  description = "Public SSM parameter holding the AMI ID for the test client."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}
