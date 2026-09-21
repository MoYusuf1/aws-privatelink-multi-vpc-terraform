variable "name" {
  description = "Prefix for resource names."
  type        = string
}

variable "vpc_id" {
  description = "VPC that hosts the service."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnets for the NLB and app instances, one per AZ. These AZs are the only ones consumers can use."
  type        = list(string)
}

variable "service_port" {
  description = "TCP port the service listens on end to end."
  type        = number
  default     = 443
}

variable "service_hostname" {
  description = "Hostname consumers use for the service. Written into the instance TLS certificate."
  type        = string
}

variable "consumer_cidrs" {
  description = "Map of consumer name to VPC CIDR allowed through the NLB security group."
  type        = map(string)
}

variable "allowed_principal_arns" {
  description = "IAM principals (normally account roots) allowed to request a connection to the endpoint service."
  type        = set(string)
}

variable "instance_type" {
  description = "Instance type for the app tier."
  type        = string
  default     = "t3.micro"
}

variable "instance_count" {
  description = "Number of app instances. Keep it at least the number of AZs so every AZ has a target."
  type        = number
  default     = 2

  validation {
    condition     = var.instance_count >= 1
    error_message = "instance_count must be at least 1."
  }
}

variable "ami_ssm_parameter" {
  description = "Public SSM parameter holding the AMI ID."
  type        = string
  default     = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

variable "deletion_protection" {
  description = "Enable NLB deletion protection."
  type        = bool
  default     = false
}

variable "alarm_actions" {
  description = "ARNs (for example an SNS topic) notified when the healthy host alarm changes state."
  type        = list(string)
  default     = []
}
