variable "name" {
  description = "Name used for the VPC and as a prefix for its resources."
  type        = string
}

variable "cidr_block" {
  description = "IPv4 CIDR for the VPC. Subnets are carved as /24s from it."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && tonumber(split("/", var.cidr_block)[1]) <= 16
    error_message = "cidr_block must be a valid IPv4 CIDR of /16 or larger."
  }
}

variable "az_ids" {
  description = "Availability Zone IDs (for example [\"use1-az1\", \"use1-az2\"]). One private subnet is created in each."
  type        = list(string)

  validation {
    condition     = length(var.az_ids) >= 2
    error_message = "Use at least two AZ IDs so the design survives a single AZ failure."
  }
}

variable "flow_log_retention_days" {
  description = "How long to keep VPC flow logs in CloudWatch Logs."
  type        = number
  default     = 7
}
