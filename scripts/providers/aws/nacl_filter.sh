#!/usr/bin/env bash

aws_get_default_nacl_ids() {
    local region="${AWS_DISCOVER_REGION:?AWS_DISCOVER_REGION is not set}"
    aws ec2 describe-network-acls \
        --region "$region" \
        --filters Name=default,Values=true \
        --query 'NetworkAcls[].NetworkAclId' \
        --output text
}
