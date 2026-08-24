#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly STATE_DIR="${SCRIPT_DIR}/.demo-state"
readonly STATE_FILE="${STATE_DIR}/resources.tsv"
readonly PROJECT_PREFIX="${PROJECT_PREFIX:-tf-importer-demo}"
readonly OWNER="${DEMO_OWNER:-community-demo}"
ACTIVE_ACCOUNT=''
readonly TAGS=(
    "Key=Project,Value=${PROJECT_PREFIX}"
    "Key=Environment,Value=demo"
    "Key=ManagedBy,Value=aws-cli"
    "Key=Purpose,Value=tf-importer-public-demo"
    "Key=Owner,Value=${OWNER}"
)

log() { printf '[demo-create] %s\n' "$*"; }
die() { printf '[demo-create] ERROR: %s\n' "$*" >&2; exit 1; }
aws_demo() { aws --no-cli-pager --region "$AWS_REGION" "$@"; }
record() { printf '%s\t%s\n' "$1" "$2" >>"$STATE_FILE"; }

require_tools() {
    command -v aws >/dev/null || die "AWS CLI is required"
    command -v jq >/dev/null || die "jq is required"
    command -v od >/dev/null || die "od is required"
    [[ -n "${AWS_REGION:-}" ]] || die "Set AWS_REGION explicitly"
    [[ "$PROJECT_PREFIX" =~ ^[a-z0-9][a-z0-9-]{2,30}$ ]] || die "Invalid PROJECT_PREFIX"
}

tag_spec() {
    local item separator=''
    for item in "${TAGS[@]}"; do
        printf '%s{%s}' "$separator" "$item"
        separator=,
    done
}

confirm_scope() {
    local account principal answer
    account="$(aws_demo sts get-caller-identity --query Account --output text)"
    ACTIVE_ACCOUNT="$account"
    principal="$(aws_demo sts get-caller-identity --query Arn --output text)"
    printf 'AWS account: %s\nRegion: %s\nPrincipal: %s\nPrefix: %s\n' "$account" "$AWS_REGION" "$principal" "$PROJECT_PREFIX"
    printf '%s\n' 'Planned: VPC, 2 isolated subnets, IGW (no public route), route table,' \
        'custom network ACL, security group, S3 bucket, SSM String parameter,' \
        'CloudWatch log group, EventBridge bus + disabled rule, ECS empty cluster.' \
        'No EC2, NAT gateway, public endpoint, task, service, secret, or Terraform command.'
    read -r -p 'Type CREATE to continue: ' answer
    [[ "$answer" == CREATE ]] || die "Creation cancelled"
}

ensure_fresh_state() {
    [[ ! -e "$STATE_FILE" ]] || die "State already exists at $STATE_FILE; review and clean up first"
    mkdir -p "$STATE_DIR"
    : >"$STATE_FILE"
    record meta_account "$ACTIVE_ACCOUNT"
    record meta_region "$AWS_REGION"
    record meta_prefix "$PROJECT_PREFIX"
}

create_network() {
    local tags vpc subnet_a subnet_b igw route_table nacl security_group az_a az_b
    tags="$(tag_spec)"
    read -r az_a az_b < <(aws_demo ec2 describe-availability-zones \
        --filters Name=state,Values=available --query 'AvailabilityZones[:2].ZoneName' --output text)
    [[ -n "${az_a:-}" && -n "${az_b:-}" ]] || die "Two availability zones are required"

    vpc="$(aws_demo ec2 create-vpc --cidr-block 10.77.0.0/16 \
        --tag-specifications "ResourceType=vpc,Tags=[${tags}]" --query Vpc.VpcId --output text)"
    record vpc "$vpc"; aws_demo ec2 wait vpc-available --vpc-ids "$vpc"
    subnet_a="$(aws_demo ec2 create-subnet --vpc-id "$vpc" --cidr-block 10.77.1.0/24 --availability-zone "$az_a" \
        --tag-specifications "ResourceType=subnet,Tags=[${tags},{Key=Name,Value=${PROJECT_PREFIX}-a}]" --query Subnet.SubnetId --output text)"
    record subnet "$subnet_a"
    subnet_b="$(aws_demo ec2 create-subnet --vpc-id "$vpc" --cidr-block 10.77.2.0/24 --availability-zone "$az_b" \
        --tag-specifications "ResourceType=subnet,Tags=[${tags},{Key=Name,Value=${PROJECT_PREFIX}-b}]" --query Subnet.SubnetId --output text)"
    record subnet "$subnet_b"
    igw="$(aws_demo ec2 create-internet-gateway --tag-specifications "ResourceType=internet-gateway,Tags=[${tags}]" --query InternetGateway.InternetGatewayId --output text)"
    record internet_gateway "$igw"; aws_demo ec2 attach-internet-gateway --vpc-id "$vpc" --internet-gateway-id "$igw"
    route_table="$(aws_demo ec2 create-route-table --vpc-id "$vpc" --tag-specifications "ResourceType=route-table,Tags=[${tags}]" --query RouteTable.RouteTableId --output text)"
    record route_table "$route_table"
    record route_table_association "$(aws_demo ec2 associate-route-table --route-table-id "$route_table" --subnet-id "$subnet_a" --query AssociationId --output text)"
    record route_table_association "$(aws_demo ec2 associate-route-table --route-table-id "$route_table" --subnet-id "$subnet_b" --query AssociationId --output text)"
    nacl="$(aws_demo ec2 create-network-acl --vpc-id "$vpc" --tag-specifications "ResourceType=network-acl,Tags=[${tags}]" --query NetworkAcl.NetworkAclId --output text)"
    record network_acl "$nacl"
    security_group="$(aws_demo ec2 create-security-group --group-name "${PROJECT_PREFIX}-sg" --description 'tf-importer public demo; no ingress' --vpc-id "$vpc" \
        --tag-specifications "ResourceType=security-group,Tags=[${tags}]" --query GroupId --output text)"
    record security_group "$security_group"
}

create_services() {
    local tags_json s3_tags_json ecs_tags_json bucket suffix parameter log_group bus rule cluster
    tags_json="$(printf '%s\n' "${TAGS[@]}" | jq -R 'capture("Key=(?<key>[^,]+),Value=(?<value>.*)")' | jq -s 'map({(.key): .value}) | add')"
    s3_tags_json="$(printf '%s\n' "${TAGS[@]}" |
        jq -R 'capture("Key=(?<Key>[^,]+),Value=(?<Value>.*)")' |
        jq -s -c '{TagSet: .}')"
    ecs_tags_json="$(printf '%s\n' "${TAGS[@]}" |
        jq -R 'capture("Key=(?<key>[^,]+),Value=(?<value>.*)")' |
        jq -s -c '.')"
    suffix="$(LC_ALL=C od -An -N5 -tx1 /dev/urandom | tr -d '[:space:]')"
    [[ "$suffix" =~ ^[a-f0-9]{10}$ ]] || die "Unable to generate a safe bucket suffix"
    bucket="${PROJECT_PREFIX}-${suffix}"
    if [[ "$AWS_REGION" == us-east-1 ]]; then
        aws_demo s3api create-bucket --bucket "$bucket" >/dev/null
    else
        aws_demo s3api create-bucket --bucket "$bucket" --create-bucket-configuration "LocationConstraint=${AWS_REGION}" >/dev/null
    fi
    record s3_bucket "$bucket"
    aws_demo s3api put-public-access-block --bucket "$bucket" --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
    if ! aws_demo s3api put-bucket-tagging --bucket "$bucket" --tagging "$s3_tags_json"; then
        log "Bucket tagging failed; deleting the newly created empty bucket"
        aws_demo s3api delete-bucket --bucket "$bucket" ||
            log "Immediate bucket rollback failed; retained exact ID in $STATE_FILE"
        return 1
    fi

    parameter="/${PROJECT_PREFIX}/message"
    aws_demo ssm put-parameter --name "$parameter" --type String --value demo-value \
        --tags "${TAGS[@]}" >/dev/null
    record ssm_parameter "$parameter"
    log_group="/${PROJECT_PREFIX}/logs"; aws_demo logs create-log-group --log-group-name "$log_group" --tags "$tags_json"
    record log_group "$log_group"; aws_demo logs put-retention-policy --log-group-name "$log_group" --retention-in-days 1
    bus="${PROJECT_PREFIX}-bus"; aws_demo events create-event-bus --name "$bus" --tags "${TAGS[@]}" >/dev/null
    record event_bus "$bus"
    rule="${PROJECT_PREFIX}-disabled"; aws_demo events put-rule --name "$rule" --event-bus-name "$bus" --state DISABLED \
        --event-pattern '{"source":["tf-importer.demo"]}' --tags "${TAGS[@]}" >/dev/null
    record event_rule "${bus}/${rule}"
    cluster="${PROJECT_PREFIX}-cluster"; aws_demo ecs create-cluster --cluster-name "$cluster" --tags "$ecs_tags_json" >/dev/null
    record ecs_cluster "$cluster"
}

main() {
    require_tools; confirm_scope; ensure_fresh_state
    trap 'log "Creation stopped. Retained state: '"$STATE_FILE"'. Run the cleanup script after review."' ERR
    create_network; create_services
    trap - ERR
    log "Creation complete. State: $STATE_FILE"
    log "Review resources, run the read-only demo, then delete them promptly. AWS charges may apply."
}
main "$@"
