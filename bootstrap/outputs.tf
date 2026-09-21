output "state_bucket" {
  description = "Name of the remote state bucket."
  value       = aws_s3_bucket.state.bucket
}

output "backend_hcl" {
  description = "Paste into ../backend.hcl."
  value       = <<-EOT
    bucket       = "${aws_s3_bucket.state.bucket}"
    key          = "${var.state_key_prefix}terraform.tfstate"
    region       = "${var.region}"
    encrypt      = true
    use_lockfile = true
  EOT
}

output "github_plan_role_arn" {
  description = "Set as the AWS_PLAN_ROLE_ARN repository variable in GitHub."
  value       = one(aws_iam_role.github_plan[*].arn)
}
