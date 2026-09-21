.DEFAULT_GOAL := help
.PHONY: help init fmt validate test lint scan check plan apply destroy output

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-10s %s\n", $$1, $$2}'

init: ## Init with the remote backend in backend.hcl
	terraform init -backend-config=backend.hcl

fmt: ## Format all Terraform files
	terraform fmt -recursive

validate: ## Validate without touching the backend
	terraform init -backend=false -input=false >/dev/null
	terraform validate

test: ## Run the mocked tests (no AWS credentials needed)
	terraform init -backend=false -input=false >/dev/null
	terraform test

lint: ## Run tflint
	tflint --init
	tflint --recursive

scan: ## Run the checkov security scan
	checkov -d . --framework terraform --quiet --compact

check: validate test lint scan ## Everything CI runs

plan: ## Plan against real AWS
	terraform plan

apply: ## Apply against real AWS
	terraform apply

destroy: ## Tear the lab down
	terraform destroy

output: ## Print the verification commands
	terraform output -raw try_it
