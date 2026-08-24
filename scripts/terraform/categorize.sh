#!/usr/bin/env bash

CATEGORIES=(network ecs ssm lambda logs elb kms secretsmanager s3 events cloudformation iam sns ecr backup apigateway outros)

terraform_ensure_category_dirs() {
    for cat in "${CATEGORIES[@]}"; do
        mkdir -p "${TF_ENV_DIR}/${cat}"
        if [[ ! -f "${TF_ENV_DIR}/${cat}/provider.tf" ]]; then
            cat > "${TF_ENV_DIR}/${cat}/provider.tf" << PEOF
provider "aws" {
  region = "${TF_REGION}"
}
PEOF
        fi
    done
}
