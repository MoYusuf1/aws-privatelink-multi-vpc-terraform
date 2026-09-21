config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "all"
}

# The AWS ruleset adds checks such as invalid instance types. Pin the latest release from
# https://github.com/terraform-linters/tflint-ruleset-aws/releases to enable it:
#
# plugin "aws" {
#   enabled = true
#   version = "x.y.z"
#   source  = "github.com/terraform-linters/tflint-ruleset-aws"
# }
