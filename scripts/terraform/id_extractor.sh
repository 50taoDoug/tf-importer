#!/usr/bin/env bash

terraform_extract_id() {
    local arn="$1"
    local tf_type="$2"

    case "$tf_type" in
        aws_instance)                  echo "$arn" | sed -E 's#.*:instance/##' ;;
        aws_security_group)            echo "$arn" | sed -E 's#.*:security-group/##' ;;
        aws_vpc_endpoint)               echo "$arn" | sed -E 's#.*:vpc-endpoint/##' ;;
        aws_vpc)                        echo "$arn" | sed -E 's#.*:vpc/##' ;;
        aws_subnet)                     echo "$arn" | sed -E 's#.*:subnet/##' ;;
        aws_ebs_volume)                 echo "$arn" | sed -E 's#.*:volume/##' ;;
        aws_network_interface)          echo "$arn" | sed -E 's#.*:network-interface/##' ;;
        aws_nat_gateway)                echo "$arn" | sed -E 's#.*:natgateway/##' ;;
        aws_internet_gateway)           echo "$arn" | sed -E 's#.*:internet-gateway/##' ;;
        aws_route_table)                echo "$arn" | sed -E 's#.*:route-table/##' ;;
        aws_eip)                        echo "$arn" | sed -E 's#.*:elastic-ip/##' ;;
        aws_key_pair)                   echo "$arn" | sed -E 's#.*:key-pair/##' ;;
        aws_network_acl)                echo "$arn" | sed -E 's#.*:network-acl/##' ;;
        aws_default_network_acl)        echo "$arn" | sed -E 's#.*:network-acl/##' ;;
        aws_vpc_dhcp_options)           echo "$arn" | sed -E 's#.*:dhcp-options/##' ;;
        aws_ec2_transit_gateway_vpc_attachment) echo "$arn" | sed -E 's#.*:transit-gateway-attachment/##' ;;
        aws_ec2_transit_gateway)        echo "$arn" | sed -E 's#.*:transit-gateway/##' ;;
        aws_vpn_gateway)                echo "$arn" | sed -E 's#.*:vpn-gateway/##' ;;
        aws_customer_gateway)           echo "$arn" | sed -E 's#.*:customer-gateway/##' ;;
        aws_vpn_connection)             echo "$arn" | sed -E 's#.*:vpn-connection/##' ;;
        aws_vpc_endpoint_service)       echo "$arn" | sed -E 's#.*:vpc-endpoint-service/##' ;;
        aws_flow_log)                   echo "$arn" | sed -E 's#.*:vpc-flow-log/##' ;;

        aws_ecs_cluster)                echo "$arn" | sed -E 's#.*:cluster/##' ;;
        aws_ecs_service)                echo "$arn" | sed -E 's#.*:service/##' ;;
        aws_ecs_task_definition)        echo "$arn" ;;
        aws_ecs_capacity_provider)      echo "$arn" | sed -E 's#.*:capacity-provider/##' ;;

        aws_ssm_parameter)              echo "$arn" | sed -E 's#.*:parameter##' ;;
        aws_ssm_document)               echo "$arn" | sed -E 's#.*:document/##' ;;
        aws_ssm_maintenance_window)     echo "$arn" | sed -E 's#.*:maintenancewindow/##' ;;
        aws_ssm_association)            echo "$arn" | sed -E 's#.*:association/##' ;;
        aws_ssm_patch_baseline)         echo "$arn" | sed -E 's#.*:patchbaseline/##' ;;

        aws_lambda_function)            echo "$arn" | sed -E 's#.*:function:##' ;;
        aws_lambda_layer_version)       echo "$arn" | sed -E 's#.*:layer:##' ;;
        aws_lambda_event_source_mapping) echo "$arn" | sed -E 's#.*:event-source-mapping:##' ;;

        aws_cloudwatch_log_group)       echo "$arn" | sed -E 's#.*:log-group:##' ;;

        aws_lb)                         echo "$arn" ;;
        aws_elb)                        echo "$arn" | sed -E 's#.*:loadbalancer/##' ;;
        aws_lb_target_group)            echo "$arn" ;;
        aws_lb_listener)                echo "$arn" ;;

        aws_kms_key)                    echo "$arn" | sed -E 's#.*:key/##' ;;
        aws_kms_alias)                  echo "$arn" | sed -E 's#.*:(alias/.*)#\1#' ;;

        aws_secretsmanager_secret)      echo "$arn" ;;

        aws_s3_bucket)                  echo "$arn" | sed -E 's#^arn:aws:s3:::##' ;;

        aws_cloudwatch_event_rule)      echo "$arn" | sed -E 's#.*:rule/##' ;;
        aws_cloudwatch_event_bus)       echo "$arn" | sed -E 's#.*:event-bus/##' ;;

        aws_cloudformation_stack)       echo "$arn" | sed -E 's#.*:stack/([^/]+)/.*#\1#' ;;

        aws_iam_role)                   echo "$arn" | sed -E 's#.*:role/##' ;;
        aws_iam_policy)                 echo "$arn" ;;
        aws_iam_user)                   echo "$arn" | sed -E 's#.*:user/##' ;;
        aws_iam_group)                  echo "$arn" | sed -E 's#.*:group/##' ;;
        aws_iam_instance_profile)       echo "$arn" | sed -E 's#.*:instance-profile/##' ;;

        aws_sns_topic)                  echo "$arn" ;;
        aws_sns_topic_subscription)     echo "$arn" ;;

        aws_ecr_repository)             echo "$arn" | sed -E 's#.*:repository/##' ;;

        aws_backup_vault)               echo "$arn" | sed -E 's#.*:backup-vault:##' ;;
        aws_backup_plan)                echo "$arn" | sed -E 's#.*:backup-plan:##' ;;

        aws_api_gateway_method)         echo "$arn" | sed -E 's#.*::/restapis/([^/]+)/resources/([^/]+)/methods/([^/]+)$#\1/\2/\3#' ;;
        aws_api_gateway_integration)    echo "$arn" | sed -E 's#.*::/restapis/([^/]+)/resources/([^/]+)/methods/([^/]+)$#\1/\2/\3#' ;;
        aws_api_gateway_resource)       echo "$arn" | sed -E 's#.*::/restapis/([^/]+)/resources/([^/]+)$#\1/\2#' ;;
        aws_api_gateway_deployment)     echo "$arn" | sed -E 's#.*::/restapis/([^/]+)/deployments/([^/]+)$#\1/\2#' ;;
        aws_api_gateway_stage)          echo "$arn" | sed -E 's#.*::/restapis/([^/]+)/stages/([^/]+)$#\1/\2#' ;;
        aws_api_gateway_rest_api)       echo "$arn" | sed -E 's#.*::/restapis/([^/]+)$#\1#' ;;
        aws_api_gateway_vpc_link)       echo "$arn" | sed -E 's#.*::/vpclinks/([^/]+)$#\1#' ;;
        aws_api_gateway_domain_name)    echo "$arn" | sed -E 's#.*::/domainnames/([^/]+)$#\1#' ;;

        *)
            log_error "No ID extraction rule for type $tf_type; using the full ARN as fallback"
            echo "$arn"
            ;;
    esac
}
