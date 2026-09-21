terraform {
  # 1.10+ for native S3 state locking (use_lockfile), 1.7+ for mocked tests.
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Partial configuration. Values come from backend.hcl (see backend.hcl.example),
  # created by the bootstrap/ stack.
  backend "s3" {}
}
