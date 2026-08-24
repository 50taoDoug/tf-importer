#!/usr/bin/env bash

aws_get_account() {
    aws sts get-caller-identity \
        --query Account \
        --output text
}
