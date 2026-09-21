variable "region" {
  description = "Region for the state bucket."
  type        = string
  default     = "us-east-1"
}

variable "state_bucket_name" {
  description = "Globally unique bucket name. Null derives one from the account ID and region."
  type        = string
  default     = null
}

variable "state_key_prefix" {
  description = "Key prefix the CI role may read and lock."
  type        = string
  default     = "privatelink/"
}

variable "github_repository" {
  description = "owner/repo allowed to assume the plan role, for example \"your-user/aws-privatelink-multi-vpc-terraform\". Null skips the OIDC role."
  type        = string
  default     = null
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider. Set false if the account already has one (only one is allowed per account)."
  type        = bool
  default     = true
}
