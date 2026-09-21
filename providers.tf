# One provider per team. Each one is its own AWS account in production.
#
# Left at the defaults, all three use whatever credentials you run Terraform with, so the
# whole lab fits in a single account. Set the *_role_arn variables and the same code
# deploys across three accounts without any other change.

provider "aws" {
  alias  = "shared"
  region = var.region

  dynamic "assume_role" {
    for_each = var.account_role_arns.shared == null ? [] : [var.account_role_arns.shared]
    content {
      role_arn     = assume_role.value
      session_name = "terraform-shared-services"
    }
  }

  default_tags {
    tags = merge(var.tags, { Team = "shared-services" })
  }
}

provider "aws" {
  alias  = "payments"
  region = var.region

  dynamic "assume_role" {
    for_each = var.account_role_arns.payments == null ? [] : [var.account_role_arns.payments]
    content {
      role_arn     = assume_role.value
      session_name = "terraform-payments"
    }
  }

  default_tags {
    tags = merge(var.tags, { Team = "payments" })
  }
}

provider "aws" {
  alias  = "analytics"
  region = var.region

  dynamic "assume_role" {
    for_each = var.account_role_arns.analytics == null ? [] : [var.account_role_arns.analytics]
    content {
      role_arn     = assume_role.value
      session_name = "terraform-analytics"
    }
  }

  default_tags {
    tags = merge(var.tags, { Team = "analytics" })
  }
}
