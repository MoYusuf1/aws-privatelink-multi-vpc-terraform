variable "region" {
  description = "AWS region for every team's resources."
  type        = string
  default     = "us-east-1"
}

variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
  default     = "fintech-lab"
}

variable "account_role_arns" {
  description = "Optional IAM role per team for multi-account deploys. Null means use the caller's own credentials."
  type = object({
    shared    = optional(string)
    payments  = optional(string)
    analytics = optional(string)
  })
  default = {}
}

variable "vpc_cidrs" {
  description = "VPC CIDR per team. They must not overlap, because the NLB security group filters on consumer CIDRs."
  type = object({
    shared    = string
    payments  = string
    analytics = string
  })
  default = {
    shared    = "10.10.0.0/16"
    payments  = "10.20.0.0/16"
    analytics = "10.30.0.0/16"
  }

  # Two CIDRs overlap when their network addresses match at the shorter of the two prefixes.
  validation {
    condition = alltrue(flatten([
      for i, a in values(var.vpc_cidrs) : [
        for j, b in values(var.vpc_cidrs) : (
          i >= j || (
            cidrhost("${cidrhost(a, 0)}/${min(tonumber(split("/", a)[1]), tonumber(split("/", b)[1]))}", 0) !=
            cidrhost("${cidrhost(b, 0)}/${min(tonumber(split("/", a)[1]), tonumber(split("/", b)[1]))}", 0)
          )
        )
      ]
    ]))
    error_message = "VPC CIDRs must not overlap. The NLB security group can only tell consumers apart if their ranges are distinct."
  }
}

variable "az_ids" {
  description = "AZ IDs to use, for example [\"use1-az1\", \"use1-az2\"]. Empty means the first two available in the region."
  type        = list(string)
  default     = []
}

variable "service_port" {
  description = "TCP port for the shared service, end to end."
  type        = number
  default     = 443
}

variable "service_hostname" {
  description = "Private hostname consumers use for the shared service."
  type        = string
  default     = "app.shared.internal"
}

variable "app_instance_type" {
  description = "Instance type for the shared application."
  type        = string
  default     = "t3.micro"
}

variable "app_instance_count" {
  description = "Number of application instances, spread across the AZs."
  type        = number
  default     = 2
}

variable "create_test_clients" {
  description = "Create a test client and EC2 Instance Connect Endpoint in each consumer VPC."
  type        = bool
  default     = true
}

variable "flow_log_retention_days" {
  description = "Retention for VPC flow logs."
  type        = number
  default     = 7
}

variable "alarm_actions" {
  description = "ARNs (for example an SNS topic) for the healthy host alarm."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default = {
    Project   = "privatelink-multi-vpc"
    ManagedBy = "terraform"
  }
}
