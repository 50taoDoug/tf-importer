#!/usr/bin/env python3
"""
Generates module calls (main.tf) and imports (imports_generated.tf) for a
downstream IaC project, based on already-validated tf-importer output.

Usage:
  generate_module_calls.py <source_main.tf> <source_imports.tf> \
      <type_config.json> <output_dir> <environment> <cost_center> \
      <tags_module_source> <project_name> [category|unified]
"""
import json
import os
import re
import sys


SUPPORTED_CONTRACT_SCHEMA = 2


def load_module_contracts(path):
    with open(path) as f:
        raw = json.load(f)

    if "schema_version" not in raw:
        return 1, {
            resource_type: {
                "module_source": config["module_source"],
                "import_target": f"{resource_type}.this",
                "name_fields": ["name", "description"],
                "variables": {
                    destination: {"source": source}
                    for source, destination in config["variable_fields"].items()
                },
            }
            for resource_type, config in raw.items()
        }

    schema_version = raw.get("schema_version")
    if schema_version != SUPPORTED_CONTRACT_SCHEMA:
        raise ValueError(
            f"Unsupported module contract schema {schema_version}; "
            f"expected {SUPPORTED_CONTRACT_SCHEMA}"
        )

    resource_types = raw.get("resource_types")
    if not isinstance(resource_types, dict):
        raise ValueError("Module contract must contain a resource_types object")

    required_fields = {"module_source", "import_target", "variables"}
    for resource_type, contract in resource_types.items():
        missing = sorted(required_fields - set(contract))
        if missing:
            raise ValueError(
                f"{resource_type} module contract is missing: {', '.join(missing)}"
            )
        if not isinstance(contract["variables"], dict):
            raise ValueError(f"{resource_type}.variables must be an object")
        for alias in contract.get("identity_aliases", []):
            if alias.get("matcher") not in (
                "arn_suffix",
                "import_arn_suffix",
            ):
                raise ValueError(
                    f"{resource_type} has unsupported identity alias matcher"
                )
            if alias.get("output") not in contract.get("outputs", []):
                raise ValueError(
                    f"{resource_type} identity alias requests undeclared output"
                )
        for rule in contract.get("preserve_native_when", []):
            if (
                not isinstance(rule.get("field"), str)
                or not isinstance(rule.get("in"), list)
                or not rule["in"]
                or not isinstance(rule.get("reason"), str)
                or not rule["reason"].strip()
            ):
                raise ValueError(
                    f"{resource_type} has invalid preserve_native_when rule"
                )
        enabled_environments = contract.get("enabled_environments")
        if enabled_environments is not None and (
            not isinstance(enabled_environments, list)
            or not enabled_environments
            or not all(
                isinstance(environment, str) and environment
                for environment in enabled_environments
            )
        ):
            raise ValueError(
                f"{resource_type}.enabled_environments must be a non-empty list"
            )
        if contract.get("latest_revision_per_family") not in (None, True):
            raise ValueError(
                f"{resource_type}.latest_revision_per_family must be true"
            )

    return schema_version, resource_types


def extract_top_level_attrs(body):
    attrs = {}
    i = 0
    n = len(body)
    while i < n:
        m = re.match(r'[ \t]*([a-zA-Z0-9_]+)[ \t]*=[ \t]*', body[i:])
        if not m:
            i += 1
            continue
        name = m.group(1)
        start_val = i + m.end()
        j = start_val
        depth = 0
        opened = False
        while j < n:
            c = body[j]
            if c in '({[':
                depth += 1
                opened = True
            elif c in ')}]':
                depth -= 1
            elif c == '\n' and depth <= 0 and opened:
                break
            elif c == '\n' and depth == 0 and not opened:
                break
            j += 1
        raw = body[start_val:j].strip()
        # The raw resource body also contains nested blocks. Keep the first
        # unqualified occurrence so an inner attribute such as setting.name
        # cannot overwrite the resource-level name. Nested attributes are
        # collected separately with their qualified block prefix.
        attrs.setdefault(name, raw)
        i = j + 1
    return attrs


def extract_nested_attrs(body):
    attrs = {}
    pattern = re.compile(r'(?m)^[ \t]*([a-zA-Z0-9_]+)[ \t]*\{')

    for match in pattern.finditer(body):
        block_name = match.group(1)
        start = match.end()
        depth = 1
        index = start
        while depth > 0 and index < len(body):
            if body[index] == '{':
                depth += 1
            elif body[index] == '}':
                depth -= 1
            index += 1
        block_body = body[start:index - 1]
        for attr_name, raw_value in extract_top_level_attrs(block_body).items():
            attrs[f"{block_name}.{attr_name}"] = raw_value

    return attrs


def extract_resources(tf_path):
    with open(tf_path) as f:
        content = f.read()

    resources = []
    pattern = re.compile(r'resource\s+"([a-zA-Z0-9_]+)"\s+"([a-zA-Z0-9_]+)"\s*\{')

    for m in pattern.finditer(content):
        rtype, rname = m.group(1), m.group(2)
        start = m.end()
        depth = 1
        i = start
        while depth > 0 and i < len(content):
            if content[i] == '{':
                depth += 1
            elif content[i] == '}':
                depth -= 1
            i += 1
        body = content[start:i - 1]
        attrs = extract_top_level_attrs(body)
        attrs.update(extract_nested_attrs(body))
        resources.append({
            "type": rtype,
            "label": rname,
            "address": f"{rtype}.{rname}",
            "attrs": attrs,
            "raw": content[m.start():i].strip(),
        })
    return resources


def extract_imports(imports_path):
    with open(imports_path) as f:
        content = f.read()

    imports = {}
    for block in re.finditer(r'import\s*\{([^}]*)\}', content, re.S):
        body = block.group(1)
        to_m = re.search(r'to\s*=\s*([a-zA-Z0-9_.]+)', body)
        id_m = re.search(r'id\s*=\s*"([^"]+)"', body)
        if to_m and id_m:
            imports[to_m.group(1)] = {
                "id": id_m.group(1),
                "raw": block.group(0).strip(),
            }
    return imports


def sanitize_name(raw):
    raw = raw.strip().strip('"')
    safe = re.sub(r'[^a-zA-Z0-9_]', '_', raw)
    safe = re.sub(r'_+', '_', safe).strip('_')
    if re.match(r'^[0-9]', safe):
        safe = f"r_{safe}"
    return safe.lower()


def resource_module_name(resource, contract, used_names):
    name_fields = contract.get("name_fields", ["name", "description"])
    name_source = next(
        (
            resource["attrs"][field]
            for field in name_fields
            if resource["attrs"].get(field)
        ),
        resource["label"],
    )
    base_name = sanitize_name(name_source)
    final_name = base_name
    suffix = 1
    while final_name in used_names:
        final_name = f"{base_name}_{suffix}"
        suffix += 1
    used_names.add(final_name)
    return final_name


def render_variable_value(
    variable_contract,
    attrs,
    identity_targets,
    module_names,
    type_config,
):
    source_field = variable_contract["source"]
    source_value = attrs.get(source_field)
    tag_policy = variable_contract.get("tag_policy")

    # Lambda functions without an environment block have no variables.  The
    # reusable Lambda module still requires a map, so represent the observed
    # absence explicitly without inventing any secret or configuration value.
    if source_value is None and source_field == "environment.variables":
        return "{}", []
    if source_value is None and source_field == "default_action.order":
        # AWS may omit the provider-generated listener action order.  Null
        # lets the provider retain the imported value without inventing one.
        return "null", []
    if source_value is None and source_field == "name":
        # Some imported AWS names are rejected by the provider schema even
        # though the remote object exists.  Keep the import identity and let
        # the provider retain the remote name instead of fabricating one.
        return "null", []

    if tag_policy == "preserve_existing":
        return source_value, []
    if tag_policy == "shared_exact":
        if not source_value:
            return source_value, []
        return (
            f"merge({source_value}, "
            f"{{ for key, value in module.tags.tags : key => value "
            f"if lookup({source_value}, key, null) == value }})",
            [],
        )
    if tag_policy:
        raise ValueError(f"Unsupported tag policy: {tag_policy}")

    reference_contract = variable_contract.get("reference")
    if not reference_contract or not source_value:
        return source_value, []

    allowed_targets = reference_contract.get("target_types", {})
    for target_type, output in allowed_targets.items():
        declared_outputs = type_config.get(target_type, {}).get("outputs", [])
        if output not in declared_outputs:
            raise ValueError(
                f"{target_type} reference requests undeclared output {output}"
            )

    rendered = source_value
    rewrites = []
    quoted_literals = set(re.findall(r'"(?:\\.|[^"\\])*"', source_value))
    for quoted_identity in sorted(quoted_literals):
        try:
            identity = json.loads(quoted_identity)
        except json.JSONDecodeError:
            continue

        candidates = []
        for target_address in identity_targets.get(identity, []):
            target_type = target_address.split(".", 1)[0]
            if target_type in allowed_targets:
                candidates.append(
                    (target_address, allowed_targets[target_type])
                )

        if identity.startswith("arn:"):
            for import_identity, target_addresses in identity_targets.items():
                if not identity.endswith(f"/{import_identity}"):
                    continue
                for target_address in target_addresses:
                    target_type = target_address.split(".", 1)[0]
                    expected_output = allowed_targets.get(target_type)
                    if not expected_output:
                        continue
                    for alias in type_config[target_type].get(
                        "identity_aliases",
                        [],
                    ):
                        if (
                            alias["matcher"] == "arn_suffix"
                            and alias["output"] == expected_output
                        ):
                            candidates.append(
                                (target_address, expected_output)
                            )
        else:
            for import_identity, target_addresses in identity_targets.items():
                if (
                    not import_identity.startswith("arn:")
                    or not import_identity.endswith(f"/{identity}")
                ):
                    continue
                for target_address in target_addresses:
                    target_type = target_address.split(".", 1)[0]
                    expected_output = allowed_targets.get(target_type)
                    if not expected_output:
                        continue
                    for alias in type_config[target_type].get(
                        "identity_aliases",
                        [],
                    ):
                        if (
                            alias["matcher"] == "import_arn_suffix"
                            and alias["output"] == expected_output
                        ):
                            candidates.append(
                                (target_address, expected_output)
                            )

        eligible = sorted(
            {
                candidate
                for candidate in candidates
                if candidate[0] in module_names
            }
        )
        if len(eligible) != 1:
            continue

        target_address, output = eligible[0]
        reference = f"module.{module_names[target_address]}.{output}"
        occurrences = rendered.count(quoted_identity)
        rendered = rendered.replace(quoted_identity, reference)
        rewrites.append(
            {
                "source_field": source_field,
                "target": target_address,
                "identity": identity,
                "reference": reference,
                "occurrences": occurrences,
            }
        )

    return rendered, rewrites


def resolve_relative_module_source(source, output_dir):
    """Resolve repository-relative sources for both legacy and account roots.

    Legacy roots live at terraform/<environment>/<category>, while the
    generalized layout adds an account segment.  The module contract keeps
    the legacy relative path; when that path does not exist from the generated
    root, probe one additional parent so both layouts use the same contract.
    """
    if not source.startswith("."):
        return source

    candidate = source
    for _ in range(3):
        if os.path.isdir(os.path.realpath(os.path.join(output_dir, candidate))):
            return candidate
        candidate = os.path.join("..", candidate)
    return source


def module_source_for_layout(contract, layout, output_dir):
    if layout == "unified":
        source = contract.get("unified_module_source")
        if not source:
            raise ValueError(
                "unified layout requires unified_module_source in every "
                "mapped resource contract"
            )
        return resolve_relative_module_source(source, output_dir)
    if layout == "category":
        return resolve_relative_module_source(contract["module_source"], output_dir)
    raise ValueError(f"Unsupported destination layout: {layout}")


def native_preservation_reason(resource, contract):
    for rule in contract.get("preserve_native_when", []):
        raw_value = resource["attrs"].get(rule["field"])
        if raw_value is None:
            continue
        try:
            value = json.loads(raw_value)
        except json.JSONDecodeError:
            value = raw_value
        if value in rule["in"]:
            return rule["reason"]
    return None


def environment_preservation_reason(
    resource,
    contract,
    environment,
    source_imports_by_address,
    latest_revision_addresses,
):
    enabled_environments = contract.get("enabled_environments")
    if enabled_environments and environment not in enabled_environments:
        return f"module contract disabled for environment {environment}"
    if (
        contract.get("latest_revision_per_family")
        and resource["address"] not in latest_revision_addresses
    ):
        return "historical revision preserved natively"
    return None


def latest_revision_resource_addresses(
    resources,
    source_imports_by_address,
    type_config,
):
    latest = {}
    for resource in resources:
        contract = type_config.get(resource["type"], {})
        if not contract.get("latest_revision_per_family"):
            continue
        import_block = source_imports_by_address.get(resource["address"])
        if not import_block:
            continue
        identity = import_block["id"]
        family, separator, revision = identity.rpartition(":")
        if not separator or not revision.isdigit():
            continue
        key = (resource["type"], family)
        candidate = (int(revision), resource["address"])
        if key not in latest or candidate > latest[key]:
            latest[key] = candidate
    return {candidate[1] for candidate in latest.values()}


def rewrite_native_references(
    resource,
    identity_targets,
    module_names,
    type_config,
):
    rendered = resource["raw"]
    if resource["type"] == "aws_instance":
        has_primary_network_interface = re.search(
            r"(?m)^[ \t]*primary_network_interface[ \t]*\{", rendered
        )
        if has_primary_network_interface:
            rendered = re.sub(
                r"(?m)^[ \t]*(?:associate_public_ip_address|private_ip|secondary_private_ips|security_groups|subnet_id|vpc_security_group_ids|source_dest_check)[ \t]*=.*\n",
                "",
                rendered,
            )

        def normalize_launch_template(match):
            block = match.group(0)
            if not re.search(r"(?m)^[ \t]*id[ \t]*=", block):
                return block
            return re.sub(r"(?m)^[ \t]*name[ \t]*=.*\n", "", block)

        rendered = re.sub(
            r"(?ms)^[ \t]*launch_template[ \t]*\{.*?^\s*\}",
            normalize_launch_template,
            rendered,
        )
    if (
        resource["type"] == "aws_backup_plan"
        and not re.search(r"(?m)^  lifecycle\s*\{", rendered)
    ):
        closing = rendered.rfind("}")
        if closing != -1:
            rendered = (
                rendered[:closing]
                + "  lifecycle {\n"
                + "    ignore_changes = [advanced_backup_setting]\n"
                + "  }\n"
                + rendered[closing:]
            )
    rewrites = []

    quoted_literals = set(
        re.findall(r'"(?:\\.|[^"\\])*"', resource["raw"])
    )
    for quoted_identity in sorted(quoted_literals):
        try:
            identity = json.loads(quoted_identity)
        except json.JSONDecodeError:
            continue

        candidates = []
        for target_address in identity_targets.get(identity, []):
            target_type = target_address.split(".", 1)[0]
            target_contract = type_config.get(target_type)
            if not target_contract:
                continue
            output = target_contract.get("identity_output")
            if output:
                candidates.append((target_address, output))

        if identity.startswith("arn:"):
            for import_identity, target_addresses in identity_targets.items():
                if not identity.endswith(f"/{import_identity}"):
                    continue
                for target_address in target_addresses:
                    target_type = target_address.split(".", 1)[0]
                    target_contract = type_config.get(target_type)
                    if not target_contract:
                        continue
                    for alias in target_contract.get("identity_aliases", []):
                        if alias["matcher"] == "arn_suffix":
                            candidates.append(
                                (target_address, alias["output"])
                            )
        else:
            for import_identity, target_addresses in identity_targets.items():
                if (
                    not import_identity.startswith("arn:")
                    or not import_identity.endswith(f"/{identity}")
                ):
                    continue
                for target_address in target_addresses:
                    target_type = target_address.split(".", 1)[0]
                    target_contract = type_config.get(target_type)
                    if not target_contract:
                        continue
                    for alias in target_contract.get("identity_aliases", []):
                        if alias["matcher"] == "import_arn_suffix":
                            candidates.append(
                                (target_address, alias["output"])
                            )

        eligible = []
        for target_address, output in candidates:
            target_type = target_address.split(".", 1)[0]
            target_contract = type_config[target_type]
            if target_address not in module_names:
                continue
            if resource["type"] not in target_contract.get(
                "reference_consumers",
                [],
            ):
                continue
            eligible.append((target_address, output))

        eligible = sorted(set(eligible))
        if len(eligible) != 1:
            continue

        target_address, output = eligible[0]
        reference = f"module.{module_names[target_address]}.{output}"
        occurrences = rendered.count(quoted_identity)
        rendered = rendered.replace(quoted_identity, reference)
        rewrites.append(
            {
                "source": resource["address"],
                "input": "native_exact_identity",
                "source_field": None,
                "target": target_address,
                "identity": identity,
                "reference": reference,
                "occurrences": occurrences,
            }
        )

    return rendered, rewrites


def main():
    if len(sys.argv) not in (9, 10):
        print("Usage: generate_module_calls.py <source_main.tf> <source_imports.tf> "
              "<type_config.json> <output_dir> <environment> <cost_center> "
              "<tags_module_source> <project_name> [category|unified]")
        sys.exit(1)

    source_main, source_imports, type_config_path, output_dir, environment, cost_center, tags_source, project_name = sys.argv[1:9]
    layout = sys.argv[9] if len(sys.argv) == 10 else "category"

    try:
        contract_schema, type_config = load_module_contracts(type_config_path)
    except (OSError, json.JSONDecodeError, ValueError, KeyError) as exc:
        print(f"ERROR: invalid module contract: {exc}", file=sys.stderr)
        sys.exit(4)

    resources = sorted(
        extract_resources(source_main),
        key=lambda resource: resource["address"],
    )
    source_imports_by_address = extract_imports(source_imports)
    identity_targets = {}
    for address, source_import in source_imports_by_address.items():
        identity_targets.setdefault(source_import["id"], []).append(address)

    main_lines = []
    import_lines = []
    used_names = set()
    modularized = []
    preserved = []
    preserved_reasons = {}
    missing_imports = []
    shared_tag_consumers = []
    rewritten_references = []
    latest_revision_addresses = latest_revision_resource_addresses(
        resources,
        source_imports_by_address,
        type_config,
    )

    module_names = {}
    for resource in resources:
        contract = type_config.get(resource["type"])
        preservation_reason = (
            native_preservation_reason(resource, contract)
            or environment_preservation_reason(
                resource,
                contract,
                environment,
                source_imports_by_address,
                latest_revision_addresses,
            )
            if contract
            else None
        )
        if contract and not preservation_reason:
            module_names[resource["address"]] = resource_module_name(
                resource,
                contract,
                used_names,
            )

    for resource in resources:
        cfg = type_config.get(resource["type"])
        preservation_reason = (
            (
                native_preservation_reason(resource, cfg)
                or environment_preservation_reason(
                    resource,
                    cfg,
                    environment,
                    source_imports_by_address,
                    latest_revision_addresses,
                )
            )
            if cfg
            else None
        )
        if preservation_reason:
            preserved_reasons[resource["address"]] = preservation_reason
            cfg = None
        if not cfg:
            preserved.append(resource["address"])
            rendered, native_rewrites = rewrite_native_references(
                resource,
                identity_targets,
                module_names,
                type_config,
            )
            main_lines.append(rendered + "\n")
            rewritten_references.extend(native_rewrites)
            source_import = source_imports_by_address.get(resource["address"])
            if source_import:
                import_lines.append(source_import["raw"] + "\n")
            else:
                missing_imports.append(resource["address"])
            continue

        final_name = module_names[resource["address"]]

        try:
            module_source = module_source_for_layout(cfg, layout, output_dir)
        except ValueError as exc:
            print(f"ERROR: invalid module contract: {exc}", file=sys.stderr)
            sys.exit(4)
        lines = [f'module "{final_name}" {{', f'  source = "{module_source}"']
        for dest_field, variable_contract in cfg["variables"].items():
            try:
                value, variable_rewrites = render_variable_value(
                    variable_contract,
                    resource["attrs"],
                    identity_targets,
                    module_names,
                    type_config,
                )
            except ValueError as exc:
                print(f"ERROR: invalid module contract: {exc}", file=sys.stderr)
                sys.exit(4)
            if value is not None:
                lines.append(f'  {dest_field} = {value}')
                for rewrite in variable_rewrites:
                    rewritten_references.append(
                        {
                            "source": resource["address"],
                            "input": dest_field,
                            **rewrite,
                        }
                    )
                if variable_contract.get("tag_policy") == "shared_exact":
                    shared_tag_consumers.append(resource["address"])
        lines.append("}")
        lines.append("")
        main_lines.append("\n".join(lines))
        modularized.append(resource["address"])

        source_import = source_imports_by_address.get(resource["address"])
        if source_import:
            import_lines.append(
                f'import {{\n'
                f'  to = module.{final_name}.{cfg["import_target"]}\n'
                f'  id = "{source_import["id"]}"\n'
                f'}}\n'
            )
        else:
            missing_imports.append(resource["address"])

    resource_addresses = {resource["address"] for resource in resources}
    orphan_imports = sorted(set(source_imports_by_address) - resource_addresses)

    header = ""
    if shared_tag_consumers:
        header = (
            f'module "tags" {{\n'
            f'  source      = "{resolve_relative_module_source(tags_source, output_dir)}"\n'
            f'  environment = "{environment.upper()}"\n'
            f'  project     = "{project_name}"\n'
            f'  cost_center = "{cost_center}"\n'
            f'}}\n\n'
        )

    os.makedirs(output_dir, exist_ok=True)

    with open(os.path.join(output_dir, "main.tf"), "w") as f:
        f.write(header + "\n".join(main_lines))

    with open(os.path.join(output_dir, "imports_generated.tf"), "w") as f:
        f.write("\n".join(import_lines))

    report = {
        "module_contract_schema": contract_schema,
        "destination_layout": layout,
        "source_resources": len(resources),
        "source_imports": len(source_imports_by_address),
        "destination_resources": len(modularized) + len(preserved),
        "destination_imports": len(import_lines),
        "modularized": modularized,
        "preserved_native": preserved,
        "preserved_native_reasons": dict(sorted(preserved_reasons.items())),
        "missing_imports": sorted(missing_imports),
        "orphan_imports": orphan_imports,
        "shared_tag_consumers": sorted(shared_tag_consumers),
        "rewritten_references": sorted(
            rewritten_references,
            key=lambda item: (item["source"], item["input"], item["target"]),
        ),
    }
    report_path = os.path.join(output_dir, "modularization_report.json")
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2)
        f.write("\n")

    print(
        f"Generated {len(modularized)} module calls, "
        f"preserved {len(preserved)} native resources, "
        f"and wrote {len(import_lines)} imports"
    )
    print(f"Report saved to: {report_path}")

    if missing_imports or orphan_imports:
        print(f"ERROR: missing imports: {sorted(missing_imports)}")
        print(f"ERROR: orphan imports: {orphan_imports}")
        sys.exit(2)

    if len(resources) != len(import_lines):
        print(
            "ERROR: source resource and destination import counts do not match: "
            f"{len(resources)} != {len(import_lines)}"
        )
        sys.exit(3)


if __name__ == "__main__":
    main()
