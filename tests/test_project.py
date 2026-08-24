from __future__ import annotations

import importlib.util
import io
import json
import re
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = PROJECT_ROOT.parents[1]
GENERATOR_PATH = (
    PROJECT_ROOT / "scripts" / "terraform" / "generate_destination_readme.py"
)

spec = importlib.util.spec_from_file_location("destination_readme", GENERATOR_PATH)
assert spec and spec.loader
destination_readme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(destination_readme)

inventory_summary_path = (
    PROJECT_ROOT / "scripts" / "terraform" / "generate_inventory_summary.py"
)
inventory_summary_spec = importlib.util.spec_from_file_location(
    "generate_inventory_summary", inventory_summary_path
)
assert inventory_summary_spec and inventory_summary_spec.loader
generate_inventory_summary = importlib.util.module_from_spec(
    inventory_summary_spec
)
inventory_summary_spec.loader.exec_module(generate_inventory_summary)

module_calls_path = PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
module_calls_spec = importlib.util.spec_from_file_location(
    "generate_module_calls", module_calls_path
)
assert module_calls_spec and module_calls_spec.loader
generate_module_calls = importlib.util.module_from_spec(module_calls_spec)
module_calls_spec.loader.exec_module(generate_module_calls)


def sample_report() -> dict:
    return {
        "project": "example",
        "environment": "prd",
        "region": "us-east-1",
        "account_id": "123456789012",
        "processed_categories": 1,
        "skipped_categories": 1,
        "source_resources": 2,
        "source_imports": 2,
        "destination_resources": 2,
        "destination_imports": 2,
        "modularized_resources": 1,
        "preserved_native_resources": 1,
        "categories": [
            {
                "category": "s3",
                "status": "validated",
                "modularization": {
                    "source_resources": 2,
                    "destination_imports": 2,
                    "modularized": ["aws_s3_bucket.example"],
                    "preserved_native": ["aws_s3_bucket.native"],
                },
            }
        ],
        "skipped_category_details": [
            {
                "category": "outros",
                "reason": "No importable resources were generated.",
            }
        ],
    }


class DestinationReadmeTests(unittest.TestCase):
    def test_render_contains_operational_summary(self) -> None:
        rendered = destination_readme.render(sample_report())

        self.assertIn("# example Infrastructure as Code", rendered)
        self.assertIn("| `s3` | validated | 2 | 2 | 1 | 1 |", rendered)
        self.assertIn(
            "Plan: 2 to import, 0 to add, 0 to change, 0 to destroy.",
            rendered,
        )
        self.assertIn("AWS account `123456789012`", rendered)

    def test_render_describes_independent_category_root(self) -> None:
        rendered = destination_readme.render(sample_report())

        self.assertIn("terraform/prd/<category>", rendered)
        self.assertIn("cd terraform/prd/<category>", rendered)
        self.assertIn("Each category has its own backend state", rendered)
        self.assertIn("docs/inventory/", rendered)

    def test_render_uses_account_scoped_paths(self) -> None:
        report = sample_report()
        report["account_key"] = "account-prod"

        rendered = destination_readme.render(report)

        self.assertIn("terraform/account-prod/prd/<category>", rendered)
        self.assertIn(
            "reports/example/account-prod/prd/modularization_pipeline.json",
            rendered,
        )
        self.assertIn("They are ignored by Git by default", rendered)
        self.assertIn("git add -f terraform/<reviewed-scope>", rendered)

    def test_load_report_rejects_missing_fields(self) -> None:
        with tempfile.TemporaryDirectory() as temp_dir:
            report_path = Path(temp_dir) / "report.json"
            report_path.write_text("{}", encoding="utf-8")

            with redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit):
                    destination_readme.load_report(report_path)


class InventorySummaryTests(unittest.TestCase):
    def test_render_uses_account_scoped_report_path(self) -> None:
        report = {
            "project": "example",
            "environment": "prd",
            "summary": {
                "discovered_resources": 0,
                "excluded_by_policy": 0,
                "skipped_non_importable": 0,
                "unmapped_resources": 0,
                "mapped_resources": 0,
                "generated_import_candidates": 0,
                "failed_remote_reads": 0,
                "orphan_imports": 0,
                "terraform_resources": 0,
                "modularized_resources": 0,
                "native_terraform_resources": 0,
            },
            "service_summary": [],
        }

        rendered = generate_inventory_summary.render_environment(
            report, "account-prod"
        )

        self.assertIn(
            "reports/example/account-prod/prd/inventory_coverage.json",
            rendered,
        )
        self.assertIn("| Controller-managed resources | 0 |", rendered)
        self.assertIn("| Resources represented by parent | 0 |", rendered)


class ProjectIntegrityTests(unittest.TestCase):
    def test_public_authorship_and_license_metadata_are_complete(self) -> None:
        expected_files = {
            "LICENSE": "Apache License",
            "NOTICE": "Copyright 2026 Douglas Fernandes",
            "AUTHORS.md": "Douglas Fernandes",
            "CITATION.cff": 'license: Apache-2.0',
        }

        for relative_path, expected_text in expected_files.items():
            content = (PROJECT_ROOT / relative_path).read_text(encoding="utf-8")
            self.assertIn(expected_text, content)

        citation = (PROJECT_ROOT / "CITATION.cff").read_text(encoding="utf-8")
        self.assertIn('family-names: "Fernandes"', citation)
        self.assertIn('given-names: "Douglas"', citation)
        self.assertIn(
            'repository-code: "https://github.com/50taoDoug/tf-importer"',
            citation,
        )

        for readme_name in ("README.md", "README-pt.md"):
            readme = (PROJECT_ROOT / readme_name).read_text(encoding="utf-8")
            for reference in ("LICENSE", "NOTICE", "CITATION.cff", "AUTHORS.md"):
                self.assertIn(f"]({reference})", readme)

    def test_readmes_set_explicit_aws_coverage_expectations(self) -> None:
        readme = (PROJECT_ROOT / "README.md").read_text(encoding="utf-8")
        readme_pt = (PROJECT_ROOT / "README-pt.md").read_text(encoding="utf-8")
        compatibility = (
            PROJECT_ROOT / "docs" / "COMPATIBILITY.md"
        ).read_text(encoding="utf-8")

        self.assertIn("does **not** claim to import every AWS resource", readme)
        self.assertIn("não** afirma importar todos os recursos da AWS", readme_pt)
        self.assertIn("31 Terraform resource types", compatibility)
        self.assertIn("recognizes 63 Terraform resource candidates", compatibility)
        for resource_type in (
            "aws_vpc",
            "aws_ecs_service",
            "aws_lambda_function",
            "aws_cloudformation_stack",
            "aws_backup_vault",
        ):
            self.assertIn(resource_type, compatibility)

    def test_public_roadmap_preserves_product_safety_boundary(self) -> None:
        roadmap_path = PROJECT_ROOT / "docs" / "ROADMAP.md"
        roadmap = roadmap_path.read_text(encoding="utf-8")

        for required_text in (
            "validated AWS resource coverage",
            "deterministic discovery",
            "import-only plan evidence",
            "private by default",
            "never runs",
            "terraform apply",
        ):
            self.assertIn(required_text, roadmap)

        for readme_name in ("README.md", "README-pt.md"):
            readme = (PROJECT_ROOT / readme_name).read_text(encoding="utf-8")
            self.assertIn("docs/ROADMAP.md", readme)

    def test_public_documentation_uses_only_fictitious_account_ids(self) -> None:
        documentation = [
            PROJECT_ROOT / "README.md",
            PROJECT_ROOT / "README-pt.md",
            *sorted((PROJECT_ROOT / "docs").rglob("*.md")),
        ]
        allowed_ids = {"111122223333", "444455556666"}
        observed_ids: set[str] = set()

        for path in documentation:
            observed_ids.update(
                re.findall(r"(?<!\d)\d{12}(?!\d)", path.read_text(encoding="utf-8"))
            )

        self.assertLessEqual(observed_ids, allowed_ids)

    def test_readmes_embed_reproducible_sanitized_demo(self) -> None:
        asset = PROJECT_ROOT / "docs" / "assets" / "tf-importer-demo.svg"
        tape = PROJECT_ROOT / "docs" / "assets" / "tf-importer-demo.tape"
        reference = 'src="docs/assets/tf-importer-demo.svg"'

        self.assertTrue(asset.is_file())
        self.assertTrue(tape.is_file())
        self.assertIn(reference, (PROJECT_ROOT / "README.md").read_text())
        self.assertIn(reference, (PROJECT_ROOT / "README-pt.md").read_text())
        self.assertIn("example-platform-prod", asset.read_text())
        self.assertIn("0 to add, 0 to change, 0 to destroy", asset.read_text())
        self.assertIn("Output docs/assets/tf-importer-demo.gif", tape.read_text())

    def test_primary_documentation_has_corresponding_languages(self) -> None:
        pairs = (
            ("README.md", "README-pt.md"),
            ("docs/README.md", "docs/README-pt.md"),
            ("docs/GETTING_STARTED.md", "docs/GETTING_STARTED-pt.md"),
            ("docs/COMMAND_REFERENCE.md", "docs/COMMAND_REFERENCE-pt.md"),
            ("docs/RELEASE_READINESS.md", "docs/RELEASE_READINESS-pt.md"),
            ("examples/demo/README.md", "examples/demo/README-pt.md"),
        )

        for english_name, portuguese_name in pairs:
            english_path = PROJECT_ROOT / english_name
            portuguese_path = PROJECT_ROOT / portuguese_name
            self.assertTrue(english_path.is_file())
            self.assertTrue(portuguese_path.is_file())

            english = english_path.read_text(encoding="utf-8")
            portuguese = portuguese_path.read_text(encoding="utf-8")
            self.assertIn(portuguese_path.name, english)
            self.assertIn(english_path.name, portuguese)
            self.assertEqual(
                len(re.findall(r"^## ", english, flags=re.MULTILINE)),
                len(re.findall(r"^## ", portuguese, flags=re.MULTILINE)),
            )

    def test_generated_destination_is_private_by_default(self) -> None:
        gitignore = (
            PROJECT_ROOT / "templates" / "destination" / ".gitignore"
        ).read_text(encoding="utf-8")

        self.assertIn("/terraform/", gitignore)
        self.assertIn("/docs/inventory/", gitignore)
        self.assertIn("/logs/", gitignore)
        self.assertNotIn("\nlogs/\n", gitignore)
        self.assertIn("git add -f <path>", gitignore)

    def test_lambda_without_environment_block_uses_empty_map(self) -> None:
        value, rewrites = generate_module_calls.render_variable_value(
            {"source": "environment.variables"},
            {},
            {},
            {},
            {},
        )

        self.assertEqual(value, "{}")
        self.assertEqual(rewrites, [])

    def test_listener_without_action_order_uses_null(self) -> None:
        value, rewrites = generate_module_calls.render_variable_value(
            {"source": "default_action.order"},
            {},
            {},
            {},
            {},
        )

        self.assertEqual(value, "null")
        self.assertEqual(rewrites, [])

    def test_missing_imported_name_uses_null(self) -> None:
        value, rewrites = generate_module_calls.render_variable_value(
            {"source": "name"},
            {},
            {},
            {},
            {},
        )

        self.assertEqual(value, "null")
        self.assertEqual(rewrites, [])

    def test_inventory_accountability_reconciles_every_discovery_outcome(
        self,
    ) -> None:
        import_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "import_blocks.sh"
        )
        exclude_script = (
            PROJECT_ROOT / "scripts" / "terraform" / "exclude.sh"
        )
        mapper_script = (
            PROJECT_ROOT / "scripts" / "terraform" / "mapper.sh"
        )
        id_script = (
            PROJECT_ROOT / "scripts" / "terraform" / "id_extractor.sh"
        )
        coverage_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "build_inventory_coverage.py"
        )
        summary_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "generate_inventory_summary.py"
        )

        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            config = temp / "config"
            output = temp / "output"
            work = temp / "work" / "example" / "prd"
            reports = temp / "reports"
            config.mkdir()
            output.mkdir()
            work.mkdir(parents=True)
            reports.mkdir()

            for filename in (
                "exclude_patterns.json",
                "resource_type_map.json",
            ):
                (config / filename).write_text(
                    (PROJECT_ROOT / "config" / filename).read_text(
                        encoding="utf-8"
                    ),
                    encoding="utf-8",
                )
            (config / "environments.conf").write_text(
                "PROJECT_NAME=example\n"
                "PROJECT_REGION=us-east-1\n"
                "PRD_ACCOUNT_ID=123456789012\n",
                encoding="utf-8",
            )
            discovery = [
                {
                    "arn": (
                        "arn:aws:config:us-east-1:123456789012:"
                        "config-rule/excluded"
                    ),
                    "region": "us-east-1",
                    "tags": {},
                },
                {
                    "arn": (
                        "arn:aws:ec2:us-east-1:123456789012:"
                        "network-interface/eni-bad"
                    ),
                    "region": "us-east-1",
                    "tags": {},
                },
                {
                    "arn": (
                        "arn:aws:ssm:us-east-1:123456789012:"
                        "opsitem/oi-unmapped"
                    ),
                    "region": "us-east-1",
                    "tags": {},
                },
                {
                    "arn": "arn:aws:s3:::example-bucket",
                    "region": "us-east-1",
                    "tags": {},
                },
                {
                    "arn": "arn:aws:s3:::failed-bucket",
                    "region": "us-east-1",
                    "tags": {},
                },
                {
                    "arn": "arn:aws:s3:::orphan-bucket",
                    "region": "us-east-1",
                    "tags": {},
                },
                {
                    "arn": "arn:aws:s3:::native-bucket",
                    "region": "us-east-1",
                    "tags": {},
                },
                {
                    "arn": (
                        "arn:aws:events:us-east-1:123456789012:"
                        "event-bus/default"
                    ),
                    "region": "us-east-1",
                    "tags": {},
                },
                {
                    "arn": (
                        "arn:aws:ec2:us-east-1:123456789012:"
                        "instance/i-karpenter"
                    ),
                    "region": "us-east-1",
                    "tags": {"karpenter.sh/nodepool": "default"},
                    "resource_type": "ec2:instance",
                },
                {
                    "arn": (
                        "arn:aws:ec2:us-east-1:123456789012:"
                        "security-group-rule/sgr-example"
                    ),
                    "region": "us-east-1",
                    "tags": {},
                    "resource_type": "ec2:security-group-rule",
                },
                {
                    "arn": (
                        "arn:aws:eks:us-east-1:123456789012:"
                        "pod/example/default/example/uuid"
                    ),
                    "region": "us-east-1",
                    "tags": {},
                    "resource_type": None,
                },
                {
                    "arn": (
                        "arn:aws:rds:us-east-1:123456789012:"
                        "snapshot:example"
                    ),
                    "region": "us-east-1",
                    "tags": {},
                    "resource_type": "rds:snapshot",
                },
                {
                    "arn": (
                        "arn:aws:elasticloadbalancing:us-east-1:"
                        "123456789012:loadbalancer/net/k8s-example/id"
                    ),
                    "region": "us-east-1",
                    "tags": {
                        "kubernetes.io/service-name": "default/example",
                        "kubernetes.io/cluster/example": "owned",
                    },
                    "resource_type": (
                        "elasticloadbalancing:loadbalancer/net"
                    ),
                },
                {
                    "arn": (
                        "arn:aws:ec2:us-east-1:123456789012:"
                        "network-interface/eni-vpc-cni"
                    ),
                    "region": "us-east-1",
                    "tags": {
                        "eks:eni:owner": "amazon-vpc-cni",
                        "eks:eks-cluster-name": "example",
                    },
                    "resource_type": "ec2:network-interface",
                },
            ]
            (output / "discovery.json").write_text(
                json.dumps(discovery),
                encoding="utf-8",
            )

            command = (
                "set -euo pipefail; "
                'PROJECT_ROOT="$1"; TF_OUTPUT_DIR="$2"; '
                'TF_ENV_DIR="$3"; TF_REPORTS_DIR="$4"; '
                "TF_REGION=us-east-1; "
                f"source {exclude_script}; "
                f"source {mapper_script}; "
                f"source {id_script}; "
                f"source {import_script}; "
                "log_info() { :; }; log_error() { :; }; "
                "aws_get_bad_eni_ids() { echo eni-bad; }; "
                "aws_get_default_nacl_ids() { :; }; "
                "terraform_get_project_name() { echo example; }; "
                "terraform_generate_import_blocks"
            )
            subprocess.run(
                [
                    "bash",
                    "-c",
                    command,
                    "bash",
                    str(temp),
                    str(output),
                    str(work),
                    str(reports),
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            classification = json.loads(
                (reports / "discovery_classification.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertEqual(
                classification["summary"],
                {
                    "discovered_resources": 14,
                    "classified_resources": 14,
                    "excluded_by_policy": 1,
                    "skipped_non_importable": 3,
                    "unmapped_resources": 1,
                    "represented_by_parent_resources": 1,
                    "controller_managed_resources": 4,
                    "mapped_resources": 4,
                    "generated_import_candidates": 4,
                },
            )

            (reports / "pruned_imports.json").write_text(
                '["aws_s3_bucket.failed_bucket"]\n',
                encoding="utf-8",
            )
            (reports / "orphan_imports.json").write_text(
                '["aws_s3_bucket.orphan_bucket"]\n',
                encoding="utf-8",
            )
            modularization = {
                "project": "example",
                "environment": "prd",
                "region": "us-east-1",
                "account_id": "123456789012",
                "categories": [
                    {
                        "category": "s3",
                        "modularization": {
                            "modularized": [
                                "aws_s3_bucket.example_bucket"
                            ],
                            "preserved_native": [
                                "aws_s3_bucket.native_bucket"
                            ],
                            "preserved_native_reasons": {
                                "aws_s3_bucket.native_bucket": (
                                    "fixture remains native"
                                )
                            },
                        },
                    }
                ],
            }
            modularization_path = reports / "modularization_pipeline.json"
            modularization_path.write_text(
                json.dumps(modularization),
                encoding="utf-8",
            )
            coverage_path = reports / "inventory_coverage.json"
            subprocess.run(
                [
                    "python3",
                    str(coverage_script),
                    str(reports / "discovery_classification.json"),
                    str(reports / "pruned_imports.json"),
                    str(reports / "orphan_imports.json"),
                    str(modularization_path),
                    str(coverage_path),
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            coverage = json.loads(
                coverage_path.read_text(encoding="utf-8")
            )
            self.assertTrue(coverage["reconciliation"]["complete"])
            self.assertEqual(coverage["summary"]["terraform_resources"], 2)
            self.assertEqual(coverage["summary"]["modularized_resources"], 1)
            self.assertEqual(
                coverage["summary"]["native_terraform_resources"], 1
            )
            self.assertEqual(coverage["summary"]["failed_remote_reads"], 1)
            self.assertEqual(coverage["summary"]["orphan_imports"], 1)
            resources_by_arn = {
                item["arn"]: item for item in coverage["resources"]
            }
            failed_target = resources_by_arn[
                "arn:aws:s3:::failed-bucket"
            ]["terraform_targets"][0]
            self.assertEqual(failed_target["outcome"], "failed_remote_read")
            self.assertIn("does not exist", failed_target["outcome_reason"])
            self.assertEqual(
                resources_by_arn["arn:aws:ssm:us-east-1:123456789012:opsitem/oi-unmapped"][
                    "action"
                ],
                "left_unmapped",
            )
            self.assertEqual(
                resources_by_arn[
                    "arn:aws:ec2:us-east-1:123456789012:instance/i-karpenter"
                ]["action"],
                "managed_by_controller",
            )
            self.assertEqual(
                resources_by_arn[
                    "arn:aws:ec2:us-east-1:123456789012:"
                    "security-group-rule/sgr-example"
                ]["classification"],
                "represented_by_parent",
            )
            self.assertEqual(
                resources_by_arn[
                    "arn:aws:eks:us-east-1:123456789012:"
                    "pod/example/default/example/uuid"
                ]["action"],
                "managed_by_controller",
            )
            self.assertEqual(
                resources_by_arn[
                    "arn:aws:rds:us-east-1:123456789012:snapshot:example"
                ]["classification"],
                "skipped_non_importable",
            )
            self.assertEqual(
                resources_by_arn[
                    "arn:aws:elasticloadbalancing:us-east-1:"
                    "123456789012:loadbalancer/net/k8s-example/id"
                ]["action"],
                "managed_by_controller",
            )
            self.assertEqual(
                resources_by_arn[
                    "arn:aws:ec2:us-east-1:123456789012:"
                    "network-interface/eni-vpc-cni"
                ]["action"],
                "managed_by_controller",
            )
            modularized_target = resources_by_arn[
                "arn:aws:s3:::example-bucket"
            ]["terraform_targets"][0]
            self.assertEqual(modularized_target["category"], "s3")
            native_target = resources_by_arn[
                "arn:aws:s3:::native-bucket"
            ]["terraform_targets"][0]
            self.assertEqual(native_target["outcome"], "native_terraform")
            self.assertEqual(
                native_target["outcome_reason"],
                "fixture remains native",
            )

            destination = temp / "destination"
            subprocess.run(
                [
                    "python3",
                    str(summary_script),
                    str(coverage_path),
                    str(destination),
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            rendered = (
                destination / "docs" / "inventory" / "prd.md"
            ).read_text(encoding="utf-8")
            self.assertIn("Reconciliation status: **complete**", rendered)
            self.assertNotIn("arn:aws", rendered)
            self.assertNotIn("123456789012", rendered)
            detailed = (reports / "inventory_coverage.md").read_text(
                encoding="utf-8"
            )
            self.assertIn("Detailed Inventory Accountability", detailed)
            self.assertIn("left_unmapped", detailed)
            self.assertIn("aws_s3_bucket.example_bucket", detailed)

    def test_category_backend_has_environment_and_category_segments(self) -> None:
        backend_script = (
            PROJECT_ROOT
            / "scripts"
            / "commands"
            / "terraform"
            / "generate_backend.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            command = (
                "log_info() { :; }; log_error() { :; }; "
                "terraform_get_project_region() { echo us-east-1; }; "
                f"source {backend_script}; "
                "terraform_generate_backend "
                f"dev network example-state {temp_dir} example-prefix"
            )
            subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            backend = (Path(temp_dir) / "backend.tf").read_text(
                encoding="utf-8"
            )

            self.assertIn(
                'key          = "example-prefix/dev/network/terraform.tfstate"',
                backend,
            )

    def test_category_backend_includes_account_scope_when_selected(self) -> None:
        backend_script = (
            PROJECT_ROOT
            / "scripts"
            / "commands"
            / "terraform"
            / "generate_backend.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            command = (
                "log_info() { :; }; log_error() { :; }; "
                "terraform_get_project_region() { echo us-east-1; }; "
                "TF_ACCOUNT_KEY=account-a; export TF_ACCOUNT_KEY; "
                f"source {backend_script}; "
                "terraform_generate_backend "
                f"prd network example-state {temp_dir} example-prefix"
            )
            subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            backend = (Path(temp_dir) / "backend.tf").read_text(
                encoding="utf-8"
            )

            self.assertIn(
                'key          = "example-prefix/account-a/prd/network/terraform.tfstate"',
                backend,
            )

    def test_dependency_report_contains_auditable_edges(self) -> None:
        analyzer = (
            PROJECT_ROOT / "scripts" / "terraform" / "analyze_dependencies.py"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            resources = temp / "main.tf"
            imports = temp / "imports.tf"
            report = temp / "dependencies.json"
            resources.write_text(
                'resource "aws_kms_key" "key" {\n'
                '  description = "example"\n'
                "}\n\n"
                'resource "aws_sns_topic" "topic" {\n'
                '  kms_master_key_id = "key-123456"\n'
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_kms_key.key\n"
                '  id = "key-123456"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_sns_topic.topic\n"
                '  id = "arn:aws:sns:us-east-1:123456789012:example"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(analyzer),
                    str(resources),
                    str(imports),
                    str(report),
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            dependencies = json.loads(report.read_text(encoding="utf-8"))

            self.assertEqual(dependencies["summary"]["total_edges"], 1)
            self.assertEqual(
                dependencies["edges"],
                [
                    {
                        "source": "aws_sns_topic.topic",
                        "target": "aws_kms_key.key",
                        "identity": "key-123456",
                        "match": "exact_quoted_identity",
                    }
                ],
            )

    def test_cross_account_report_is_reconciled_and_deterministic(self) -> None:
        analyzer = (
            PROJECT_ROOT / "scripts" / "terraform" / "analyze_cross_account.py"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            terraform_root = temp / "terraform"
            category = terraform_root / "lambda"
            category.mkdir(parents=True)
            (category / "main.tf").write_text(
                """
resource "aws_lambda_function" "example" {
  function_name = "example"
  kms_key_arn   = "arn:aws:kms:us-east-1:444455556666:key/example"
  environment {
    variables = {
      TARGET_ROLE = "arn:aws:iam::444455556666:role/example"
      OWNER_ID    = "444455556666"
      IGNORED_ID  = "123456789012"
    }
  }
}

module "external" {
  source       = "./module"
  external_arn = "arn:aws:sqs:us-east-1:444455556666:example"
}
""".lstrip(),
                encoding="utf-8",
            )
            registry = temp / "environments.conf"
            registry.write_text(
                """
ACCOUNT_1_KEY=consumer
ACCOUNT_1_ID=111122223333
ACCOUNT_1_ENVIRONMENTS=prd
ACCOUNT_2_KEY=owner
ACCOUNT_2_ID=444455556666
ACCOUNT_2_ENVIRONMENTS=prd
""".lstrip(),
                encoding="utf-8",
            )
            first = temp / "first.json"
            second = temp / "second.json"
            command = [
                sys.executable,
                str(analyzer),
                str(terraform_root),
                str(registry),
                "consumer",
                "prd",
            ]
            subprocess.run([*command, str(first)], check=True)
            subprocess.run([*command, str(second)], check=True)

            self.assertEqual(first.read_bytes(), second.read_bytes())
            report = json.loads(first.read_text(encoding="utf-8"))
            self.assertTrue(report["reconciliation"]["complete"])
            self.assertEqual(report["summary"]["observed_candidates"], 4)
            self.assertEqual(report["summary"]["unique_relationships"], 4)
            self.assertEqual(
                report["summary"]["by_service"],
                {"account": 1, "iam": 1, "kms": 1, "sqs": 1},
            )
            self.assertEqual(
                {item["target_account_key"] for item in report["relationships"]},
                {"owner"},
            )
            self.assertNotIn(
                "arn:aws",
                json.dumps(report["relationships"]),
            )

            destination = temp / "destination"
            subprocess.run(
                [
                    sys.executable,
                    str(
                        PROJECT_ROOT
                        / "scripts"
                        / "terraform"
                        / "generate_cross_account_summary.py"
                    ),
                    str(first),
                    str(destination),
                    "consumer",
                    "prd",
                ],
                check=True,
            )
            summary = (
                destination
                / "docs"
                / "inventory"
                / "consumer"
                / "prd-cross-account.md"
            ).read_text(encoding="utf-8")
            self.assertIn("| Observed candidates | 4 |", summary)
            self.assertIn("| `user_review_required` | 3 |", summary)
            self.assertNotIn("111122223333", summary)
            self.assertNotIn("444455556666", summary)

    def test_cross_account_analysis_is_part_of_final_publication(self) -> None:
        command = (
            PROJECT_ROOT
            / "scripts"
            / "commands"
            / "terraform"
            / "modularize_all.sh"
        ).read_text(encoding="utf-8")

        self.assertIn("analyze_cross_account.py", command)
        self.assertIn("cross_account_relationships.json", command)
        self.assertIn("generate_cross_account_summary.py", command)
        self.assertIn(".reconciliation.complete == true", command)

    def test_version_comparison_enforces_minimum(self) -> None:
        common_script = PROJECT_ROOT / "scripts" / "core" / "common.sh"
        command = (
            f"source {common_script}; "
            "version_at_least 1.15.7 1.5.0; "
            "! version_at_least 1.4.9 1.5.0"
        )
        subprocess.run(
            ["bash", "-c", command],
            cwd=PROJECT_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )

    def test_doctor_propagates_runtime_failure(self) -> None:
        doctor_script = (
            PROJECT_ROOT / "scripts" / "commands" / "environment" / "doctor.sh"
        )
        command = (
            "log_info() { :; }; log_success() { :; }; log_error() { :; }; "
            f"source {doctor_script}; "
            "doctor_check_runtime_commands() { return 1; }; "
            "doctor_check_runtime_versions() { return 0; }; "
            "doctor_check_aws() { return 0; }; "
            "doctor_check_connectivity() { return 0; }; "
            "doctor_check_development_tools() { return 0; }; "
            "cmd_doctor"
        )
        result = subprocess.run(
            ["bash", "-c", command],
            cwd=PROJECT_ROOT,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.returncode, 1)

    def test_existing_destination_is_preserved(self) -> None:
        environment_script = PROJECT_ROOT / "scripts" / "core" / "environment.sh"
        logger_script = PROJECT_ROOT / "scripts" / "core" / "logger.sh"
        with tempfile.TemporaryDirectory() as temp_dir:
            destination = Path(temp_dir) / "destination"
            destination.mkdir()
            marker = destination / "existing.txt"
            marker.write_text("preserve", encoding="utf-8")
            command = (
                f"PROJECT_ROOT={PROJECT_ROOT}; "
                f"LOG_FILE={temp_dir}/test.log; "
                f"source {logger_script}; "
                f"source {environment_script}; "
                f"terraform_get_destination_project_dir() {{ echo {destination}; }}; "
                "terraform_get_modularization_value() { "
                '[[ "$1" == DESTINATION_TEMPLATE_DIR ]] && '
                "echo templates/destination; "
                "}; "
                "terraform_prepare_destination_project"
            )
            subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertEqual(marker.read_text(encoding="utf-8"), "preserve")
            gitignore = (destination / ".gitignore").read_text(encoding="utf-8")
            self.assertIn("/terraform/", gitignore)
            self.assertIn("/docs/inventory/", gitignore)

    def test_ci_workflow_is_static_and_read_only(self) -> None:
        standalone_workflow = (
            PROJECT_ROOT / ".github" / "workflows" / "tf-importer-ci.yml"
        )
        monorepo_workflow = (
            REPOSITORY_ROOT / ".github" / "workflows" / "tf-importer-ci.yml"
        )
        workflow_path = (
            standalone_workflow
            if standalone_workflow.is_file()
            else monorepo_workflow
        )
        workflow = workflow_path.read_text(encoding="utf-8")

        self.assertIn("contents: read", workflow)
        self.assertIn("timeout-minutes: 20", workflow)
        self.assertIn(
            "actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6",
            workflow,
        )
        self.assertIn(
            "actions/setup-python@ece7cb06caefa5fff74198d8649806c4678c61a1 # v6",
            workflow,
        )
        self.assertIn(
            "hashicorp/setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e # v4",
            workflow,
        )
        self.assertIn('AWS_EC2_METADATA_DISABLED: "true"', workflow)
        self.assertIn("persist-credentials: false", workflow)
        self.assertNotIn("aws-access-key-id", workflow)
        self.assertNotIn("terraform apply", workflow)

    def test_standalone_sync_excludes_git_bundles(self) -> None:
        sync_path = PROJECT_ROOT / "scripts" / "publication" / "sync_standalone.sh"
        if sync_path.is_file():
            sync_script = sync_path.read_text(encoding="utf-8")
            self.assertIn("--exclude='*.bundle'", sync_script)
        else:
            gitignore = (PROJECT_ROOT / ".gitignore").read_text(encoding="utf-8")
            self.assertIn("/*.bundle", gitignore)

    def test_publication_readiness_gates_pass(self) -> None:
        scripts = (
            "check_markdown_links.py",
            "check_release_metadata.py",
            "check_tracked_content.py",
        )
        for script in scripts:
            result = subprocess.run(
                ["python3", str(PROJECT_ROOT / "scripts" / "ci" / script)],
                cwd=PROJECT_ROOT,
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_release_metadata_rejects_mismatched_future_tag(self) -> None:
        result = subprocess.run(
            [
                "python3",
                str(PROJECT_ROOT / "scripts" / "ci" / "check_release_metadata.py"),
                "--tag",
                "v9.9.9",
            ],
            cwd=PROJECT_ROOT,
            check=False,
            capture_output=True,
            text=True,
        )

        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match VERSION", result.stdout)

    def test_ci_accepts_checkout_without_generated_destination(self) -> None:
        validation_script = (
            PROJECT_ROOT / "scripts" / "ci" / "validate.sh"
        ).read_text(encoding="utf-8")

        self.assertIn("if [[ -d ../example-iac/config ]]", validation_script)
        self.assertIn("if [[ -d ../example-iac ]]", validation_script)

    def test_cli_help_loads_all_commands(self) -> None:
        result = subprocess.run(
            [str(PROJECT_ROOT / "tf-importer"), "help"],
            cwd=PROJECT_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )

        self.assertIn("pipeline", result.stdout)
        self.assertIn("plan", result.stdout)
        self.assertNotIn("unified_preview", result.stdout)

    def test_destination_module_map_points_to_existing_modules(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )
        category_root = template / "terraform" / "prd" / "category"

        self.assertEqual(module_map["schema_version"], 2)
        for resource_type, config in module_map["resource_types"].items():
            module_path = (category_root / config["module_source"]).resolve()
            self.assertTrue(
                module_path.is_dir(),
                f"{resource_type} points to missing module {module_path}",
            )
            self.assertIn("import_target", config)
            self.assertIn("unified_module_source", config)
            self.assertIn("variables", config)

            outputs = {
                match.group(1)
                for match in re.finditer(
                    r'output\s+"([^"]+)"',
                    (module_path / "outputs.tf").read_text(encoding="utf-8"),
                )
            }
            self.assertTrue(
                set(config.get("outputs", [])) <= outputs,
                f"{resource_type} declares outputs not provided by {module_path}",
            )

    def test_foundation_module_contracts_preserve_sensitive_and_variable_fields(
        self,
    ) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]

        ssm = module_map["aws_ssm_parameter"]
        self.assertEqual(ssm["import_target"], "aws_ssm_parameter.this")
        self.assertEqual(ssm["identity_output"], "name")
        self.assertEqual(
            set(ssm["variables"]),
            {
                "name",
                "description",
                "type",
                "value",
                "tier",
                "data_type",
                "allowed_pattern",
                "overwrite",
                "tags",
            },
        )
        ssm_variables = (
            template / "modules" / "ssm" / "parameter" / "variables.tf"
        ).read_text(encoding="utf-8")
        self.assertRegex(
            ssm_variables,
            r'variable "value" \{[^}]*sensitive\s*=\s*true',
        )

        logs = module_map["aws_cloudwatch_log_group"]
        self.assertEqual(
            set(logs["variables"]),
            {
                "name",
                "retention_in_days",
                "kms_key_id",
                "log_group_class",
                "deletion_protection_enabled",
                "skip_destroy",
                "tags",
            },
        )
        self.assertEqual(
            set(logs["reference_consumers"]),
            {"aws_ecs_task_definition", "aws_lambda_function"},
        )

    def test_event_rule_contract_preserves_mutually_exclusive_expressions(
        self,
    ) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]

        event_rule = module_map["aws_cloudwatch_event_rule"]
        self.assertEqual(
            event_rule["import_target"],
            "aws_cloudwatch_event_rule.this",
        )
        self.assertEqual(event_rule["identity_output"], "name")
        self.assertEqual(
            set(event_rule["variables"]),
            {
                "name",
                "description",
                "event_bus_name",
                "event_pattern",
                "force_destroy",
                "role_arn",
                "schedule_expression",
                "state",
                "tags",
            },
        )

    def test_ecs_cluster_contract_isolated_from_service_resources(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]

        cluster = module_map["aws_ecs_cluster"]
        self.assertEqual(cluster["import_target"], "aws_ecs_cluster.this")
        self.assertEqual(cluster["identity_output"], "name")
        self.assertEqual(
            set(cluster["variables"]),
            {
                "name",
                "container_insights_name",
                "container_insights_value",
                "tags",
            },
        )
        self.assertEqual(
            cluster["reference_consumers"],
            ["aws_ecs_service"],
        )

    def test_ecs_service_contract_preserves_observed_nested_blocks(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        service = module_map["aws_ecs_service"]

        self.assertEqual(service["import_target"], "aws_ecs_service.this")
        self.assertEqual(
            service["variables"]["cluster"]["reference"]["target_types"],
            {"aws_ecs_cluster": "arn"},
        )
        self.assertEqual(
            service["variables"]["subnets"]["reference"]["target_types"],
            {"aws_subnet": "id"},
        )
        expected_nested_sources = {
            "deployment_circuit_breaker.enable",
            "deployment_circuit_breaker.rollback",
            "deployment_configuration.bake_time_in_minutes",
            "deployment_configuration.strategy",
            "deployment_controller.type",
            "load_balancer.container_name",
            "load_balancer.container_port",
            "load_balancer.elb_name",
            "load_balancer.target_group_arn",
            "network_configuration.assign_public_ip",
            "network_configuration.security_groups",
            "network_configuration.subnets",
        }
        self.assertTrue(
            expected_nested_sources
            <= {
                variable["source"]
                for variable in service["variables"].values()
            }
        )

    def test_target_group_contract_supports_all_observed_variants(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        target_group = module_map["aws_lb_target_group"]

        self.assertEqual(
            target_group["import_target"],
            "aws_lb_target_group.this",
        )
        self.assertEqual(target_group["identity_output"], "arn")
        self.assertNotIn("preserve_native_when", target_group)
        self.assertEqual(
            target_group["variables"]["vpc_id"]["reference"]["target_types"],
            {"aws_vpc": "id"},
        )
        self.assertEqual(
            module_map["aws_ecs_service"]["variables"][
                "load_balancer_target_group_arn"
            ]["reference"]["target_types"],
            {"aws_lb_target_group": "arn"},
        )

    def test_load_balancer_contract_supports_optional_log_blocks(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        load_balancer = module_map["aws_lb"]

        self.assertEqual(load_balancer["import_target"], "aws_lb.this")
        self.assertEqual(load_balancer["identity_output"], "arn")
        self.assertEqual(
            load_balancer["variables"]["subnets"]["reference"][
                "target_types"
            ],
            {"aws_subnet": "id"},
        )
        self.assertEqual(
            {
                load_balancer["variables"][name]["source"]
                for name in (
                    "access_logs_enabled",
                    "connection_logs_enabled",
                    "health_check_logs_enabled",
                )
            },
            {
                "access_logs.enabled",
                "connection_logs.enabled",
                "health_check_logs.enabled",
            },
        )

    def test_listener_contract_references_lb_and_target_group(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        listener = module_map["aws_lb_listener"]

        self.assertEqual(listener["import_target"], "aws_lb_listener.this")
        self.assertEqual(
            listener["variables"]["load_balancer_arn"]["reference"][
                "target_types"
            ],
            {"aws_lb": "arn"},
        )
        for variable in (
            "default_action_target_group_arn",
            "forward_target_group_arn",
        ):
            self.assertEqual(
                listener["variables"][variable]["reference"]["target_types"],
                {"aws_lb_target_group": "arn"},
            )
        self.assertEqual(
            listener["variables"]["forward_stickiness_duration"]["source"],
            "stickiness.duration",
        )

    def test_lambda_contract_preserves_observed_nested_blocks(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        function = module_map["aws_lambda_function"]

        self.assertEqual(
            function["import_target"],
            "aws_lambda_function.this",
        )
        self.assertEqual(function["name_fields"], ["function_name"])
        self.assertEqual(function["identity_output"], "id")
        self.assertEqual(
            {
                function["variables"][name]["source"]
                for name in (
                    "environment_variables",
                    "ephemeral_storage_size",
                    "application_log_level",
                    "log_format",
                    "log_group",
                    "system_log_level",
                    "tracing_mode",
                )
            },
            {
                "environment.variables",
                "ephemeral_storage.size",
                "logging_config.application_log_level",
                "logging_config.log_format",
                "logging_config.log_group",
                "logging_config.system_log_level",
                "tracing_config.mode",
            },
        )

    def test_backup_vault_contract_references_kms_arn_alias(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]

        self.assertEqual(
            module_map["aws_kms_key"]["identity_aliases"],
            [{"matcher": "arn_suffix", "output": "arn"}],
        )
        self.assertEqual(
            module_map["aws_backup_vault"]["variables"]["kms_key_arn"][
                "reference"
            ]["target_types"],
            {"aws_kms_key": "arn"},
        )

    def test_cloudformation_contract_rewrites_parameter_references(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        stack = module_map["aws_cloudformation_stack"]

        self.assertEqual(
            stack["import_target"],
            "aws_cloudformation_stack.this",
        )
        self.assertEqual(
            stack["variables"]["parameters"]["reference"]["target_types"],
            {
                "aws_s3_bucket": "id",
                "aws_ssm_parameter": "name",
            },
        )
        self.assertEqual(
            stack["variables"]["template_body"]["reference"]["target_types"],
            stack["variables"]["parameters"]["reference"]["target_types"],
        )
        self.assertNotIn("template_url", stack["variables"])

    def test_endpoint_service_contract_references_load_balancers(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        endpoint_service = module_map["aws_vpc_endpoint_service"]

        self.assertEqual(
            endpoint_service["variables"]["network_load_balancer_arns"][
                "reference"
            ]["target_types"],
            {"aws_lb": "arn"},
        )
        self.assertIn(
            "aws_vpc_endpoint_service",
            module_map["aws_lb"]["reference_consumers"],
        )

    def test_flow_log_contract_references_vpc_and_optional_destination(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        flow_log = module_map["aws_flow_log"]

        self.assertEqual(
            flow_log["variables"]["vpc_id"]["reference"]["target_types"],
            {"aws_vpc": "id"},
        )
        self.assertEqual(
            flow_log["variables"]["destination_file_format"]["source"],
            "destination_options.file_format",
        )
        self.assertNotIn("eni_id", flow_log["variables"])

    def test_transit_gateway_attachment_contract_references_network(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        attachment = module_map[
            "aws_ec2_transit_gateway_vpc_attachment"
        ]

        self.assertEqual(
            attachment["variables"]["subnet_ids"]["reference"][
                "target_types"
            ],
            {"aws_subnet": "id"},
        )
        self.assertEqual(
            attachment["variables"]["vpc_id"]["reference"]["target_types"],
            {"aws_vpc": "id"},
        )
        self.assertNotIn(
            "reference",
            attachment["variables"]["transit_gateway_id"],
        )

    def test_eip_contract_omits_null_association_modes(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        eip = module_map["aws_eip"]

        self.assertEqual(eip["import_target"], "aws_eip.this")
        self.assertEqual(eip["identity_output"], "id")
        self.assertNotIn("address", eip["variables"])
        self.assertNotIn("associate_with_private_ip", eip["variables"])

    def test_remaining_network_contracts_are_mapped(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]

        for resource_type in (
            "aws_route_table",
            "aws_security_group",
            "aws_vpc_endpoint",
            "aws_default_network_acl",
        ):
            self.assertIn(resource_type, module_map)
        self.assertEqual(
            module_map["aws_vpc_endpoint"]["variables"]["subnet_ids"][
                "reference"
            ]["target_types"],
            {"aws_subnet": "id"},
        )
        self.assertEqual(
            module_map["aws_security_group"]["variables"]["vpc_id"][
                "reference"
            ]["target_types"],
            {"aws_vpc": "id"},
        )

    def test_api_gateway_rest_resources_have_import_mappings(self) -> None:
        mapper = PROJECT_ROOT / "scripts" / "terraform" / "mapper.sh"
        extractor = (
            PROJECT_ROOT / "scripts" / "terraform" / "id_extractor.sh"
        )
        arn = (
            "arn:aws:apigateway:us-east-1::"
            "/restapis/api123/resources/res456/methods/GET"
        )
        command = (
            'PROJECT_ROOT="$1"; source "$2"; source "$3"; '
            'log_error() { :; }; '
            'terraform_map_arn_to_type "$4"; '
            'terraform_extract_id "$4" aws_api_gateway_method'
        )
        result = subprocess.run(
            [
                "bash",
                "-c",
                command,
                "bash",
                str(PROJECT_ROOT),
                str(mapper),
                str(extractor),
                arn,
            ],
            cwd=PROJECT_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )

        self.assertEqual(
            result.stdout.splitlines(),
            [
                "aws_api_gateway_method",
                "aws_api_gateway_integration",
                "api123/res456/GET",
            ],
        )

    def test_api_gateway_has_an_independent_category(self) -> None:
        categorizer = (
            PROJECT_ROOT / "scripts" / "terraform" / "categorize.sh"
        ).read_text(encoding="utf-8")
        splitter = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "split_generated_config.sh"
        ).read_text(encoding="utf-8")

        self.assertIn("apigateway outros", categorizer)
        self.assertEqual(
            splitter.count(
                'if (rtype ~ /^aws_api_gateway_/) return "apigateway"'
            ),
            2,
        )

    def test_task_definition_contract_is_prd_latest_revision_only(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        task_definition = module_map["aws_ecs_task_definition"]

        self.assertEqual(task_definition["enabled_environments"], ["prd"])
        self.assertTrue(task_definition["latest_revision_per_family"])
        self.assertEqual(task_definition["identity_output"], "family_revision")
        self.assertEqual(
            task_definition["identity_aliases"],
            [
                {
                    "matcher": "import_arn_suffix",
                    "output": "family_revision",
                }
            ],
        )
        self.assertEqual(
            module_map["aws_ecs_service"]["variables"]["task_definition"][
                "reference"
            ]["target_types"],
            {"aws_ecs_task_definition": "family_revision"},
        )

    def test_production_tag_contracts_use_shared_exact_policy(self) -> None:
        template = PROJECT_ROOT / "templates" / "destination"
        module_map = json.loads(
            (template / "config" / "resource_module_map.json").read_text(
                encoding="utf-8"
            )
        )["resource_types"]
        tag_variables = [
            contract["variables"]["tags"]
            for contract in module_map.values()
            if "tags" in contract["variables"]
        ]

        self.assertGreater(len(tag_variables), 0)
        self.assertTrue(
            all(
                variable.get("tag_policy") == "shared_exact"
                for variable in tag_variables
            )
        )

    def test_cleanup_preserves_disabled_stickiness_with_duration(self) -> None:
        cleanup_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "cleanup_generated_config.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            terraform_file = Path(temp_dir) / "main.tf"
            terraform_file.write_text(
                "forward {\n"
                "  stickiness {\n"
                "    duration = 3600\n"
                "    enabled  = false\n"
                "  }\n"
                "}\n",
                encoding="utf-8",
            )
            subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; _strip_disabled_block "$2" stickiness',
                    "bash",
                    str(cleanup_script),
                    str(terraform_file),
                ],
                check=True,
                cwd=PROJECT_ROOT,
            )
            rendered = terraform_file.read_text(encoding="utf-8")
            self.assertIn("stickiness {", rendered)
            self.assertIn("duration = 3600", rendered)

    def test_cleanup_ignores_imported_ssm_document_content_formatting(self) -> None:
        cleanup_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "cleanup_generated_config.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            terraform_file = Path(temp_dir) / "auto_generated.tf"
            terraform_file.write_text(
                'resource "aws_ssm_document" "example" {\n'
                '  content = jsonencode({ description = "example" })\n'
                '  name = "example"\n'
                '}\n',
                encoding="utf-8",
            )
            subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; _add_import_lifecycle "$2" aws_ssm_document "" content',
                    "bash",
                    str(cleanup_script),
                    str(terraform_file),
                ],
                check=True,
                cwd=PROJECT_ROOT,
            )
            rendered = terraform_file.read_text(encoding="utf-8")
            self.assertIn("lifecycle {", rendered)
            self.assertIn("ignore_changes = [content]", rendered)

    def test_cleanup_removes_invalid_imported_listener_and_secret_values(self) -> None:
        cleanup_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "cleanup_generated_config.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            terraform_file = Path(temp_dir) / "auto_generated.tf"
            terraform_file.write_text(
                'resource "aws_lb_listener" "listener" {\n'
                '  default_action {\n'
                '    order = 0\n'
                '    type = "forward"\n'
                '  }\n'
                '}\n\n'
                'resource "aws_secretsmanager_secret" "secret" {\n'
                '  name = "rds!db-example"\n'
                '}\n',
                encoding="utf-8",
            )
            subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; _strip_invalid_listener_order "$2"; '
                    '_strip_invalid_secretsmanager_names "$2"',
                    "bash",
                    str(cleanup_script),
                    str(terraform_file),
                ],
                check=True,
                cwd=PROJECT_ROOT,
            )
            rendered = terraform_file.read_text(encoding="utf-8")
            self.assertNotIn("order = 0", rendered)
            self.assertNotIn('name = "rds!db-example"', rendered)
            self.assertIn('type = "forward"', rendered)

    def test_cleanup_removes_invalid_backup_and_ebs_values(self) -> None:
        cleanup_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "cleanup_generated_config.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            terraform_file = Path(temp_dir) / "auto_generated.tf"
            terraform_file.write_text(
                'resource "aws_backup_plan" "plan" {\n'
                '  advanced_backup_setting {\n'
                '    backup_options = { BackupObjectTags = "enabled" }\n'
                '    resource_type = "S3"\n'
                '  }\n'
                '  rule {\n'
                '    lifecycle {\n'
                '      delete_after = 35\n'
                '    }\n'
                '  }\n'
                '}\n\n'
                'resource "aws_ebs_volume" "volume" {\n'
                '  volume_initialization_rate = 0\n'
                '  throughput = 0\n'
                '}\n\n'
                'resource "aws_api_gateway_rest_api" "api" {\n'
                '  endpoint_configuration {\n'
                '    types            = ["REGIONAL"]\n'
                '    vpc_endpoint_ids = []\n'
                '  }\n'
                '}\n\n'
                'resource "aws_cloudwatch_log_group" "logs" {\n'
                '  name              = "/aws/example"\n'
                '  retention_in_days = 3653\n'
                '}\n',
                encoding="utf-8",
            )
            subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; _strip_invalid_backup_advanced_setting "$2"; '
                    'sed -i -E "/^\\s*volume_initialization_rate\\s*=\\s*0\\s*$/d" "$2"; '
                    'sed -i -E "/^\\s*throughput\\s*=\\s*0\\s*$/d" "$2"; '
                    'sed -i -E "/^\\s*vpc_endpoint_ids\\s*=\\s*\\[\\]\\s*$/d" "$2"; '
                    '_add_import_lifecycle "$2" aws_backup_plan "" advanced_backup_setting; '
                    '_add_import_lifecycle "$2" aws_cloudwatch_log_group "" retention_in_days',
                    "bash",
                    str(cleanup_script),
                    str(terraform_file),
                ],
                check=True,
                cwd=PROJECT_ROOT,
            )
            rendered = terraform_file.read_text(encoding="utf-8")
            self.assertNotIn("advanced_backup_setting {", rendered)
            self.assertNotIn("volume_initialization_rate", rendered)
            self.assertNotIn("throughput", rendered)
            self.assertNotIn("vpc_endpoint_ids", rendered)
            self.assertIn("ignore_changes = [advanced_backup_setting]", rendered)
            self.assertIn("ignore_changes = [retention_in_days]", rendered)
            self.assertEqual(rendered.count("lifecycle {"), 3)

    def test_cleanup_removes_disabled_listener_mutual_auth_setting(self) -> None:
        cleanup_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "cleanup_generated_config.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            terraform_file = Path(temp_dir) / "auto_generated.tf"
            terraform_file.write_text(
                'resource "aws_lb_listener" "example" {\n'
                '  mutual_authentication {\n'
                '    ignore_client_certificate_expiry = false\n'
                '    mode = "off"\n'
                '    trust_store_arn = null\n'
                '  }\n'
                '}\n',
                encoding="utf-8",
            )
            subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; '
                    '_strip_disabled_mutual_authentication_settings "$2"',
                    "bash",
                    str(cleanup_script),
                    str(terraform_file),
                ],
                check=True,
                cwd=PROJECT_ROOT,
            )
            rendered = terraform_file.read_text(encoding="utf-8")

            self.assertNotIn(
                "ignore_client_certificate_expiry",
                rendered,
            )
            self.assertIn('mode = "off"', rendered)

    def test_pruning_reports_accumulate_across_build_retries(self) -> None:
        failed_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "prune_failed_imports.sh"
        )
        orphan_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "prune_orphan_imports.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            environment = temp / "environment"
            reports = temp / "reports"
            environment.mkdir()
            reports.mkdir()
            imports = environment / "imports_generated.tf"
            config = environment / "auto_generated.tf"
            plan_log = reports / "plan.log"

            imports.write_text(
                'import {\n'
                '  to = aws_s3_bucket.failed_new\n'
                '  id = "failed-new"\n'
                '}\n'
                'import {\n'
                '  to = aws_s3_bucket.orphan_new\n'
                '  id = "orphan-new"\n'
                '}\n',
                encoding="utf-8",
            )
            config.write_text(
                'resource "aws_s3_bucket" "failed_new" {\n'
                '  bucket = "failed-new"\n'
                '}\n',
                encoding="utf-8",
            )
            plan_log.write_text(
                "Cannot import non-existent remote object\n"
                'with "aws_s3_bucket.failed_new",\n',
                encoding="utf-8",
            )
            (reports / "pruned_imports.json").write_text(
                '["aws_s3_bucket.failed_old"]\n',
                encoding="utf-8",
            )
            (reports / "orphan_imports.json").write_text(
                '["aws_s3_bucket.orphan_old"]\n',
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "bash",
                    "-c",
                    'set -e; TF_ENV_DIR="$1"; TF_REPORTS_DIR="$2"; '
                    'source "$3"; source "$4"; log_info() { :; }; '
                    'terraform_prune_failed_imports "$5"; '
                    "terraform_prune_orphan_imports",
                    "bash",
                    str(environment),
                    str(reports),
                    str(failed_script),
                    str(orphan_script),
                    str(plan_log),
                ],
                check=True,
                cwd=PROJECT_ROOT,
            )

            self.assertEqual(
                json.loads(
                    (reports / "pruned_imports.json").read_text(
                        encoding="utf-8"
                    )
                ),
                [
                    "aws_s3_bucket.failed_new",
                    "aws_s3_bucket.failed_old",
                ],
            )
            self.assertEqual(
                json.loads(
                    (reports / "orphan_imports.json").read_text(
                        encoding="utf-8"
                    )
                ),
                [
                    "aws_s3_bucket.orphan_new",
                    "aws_s3_bucket.orphan_old",
                ],
            )

    def test_cleanup_removes_service_managed_network_interface_types(self) -> None:
        cleanup_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "cleanup_generated_config.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            terraform_file = Path(temp_dir) / "auto_generated.tf"
            terraform_file.write_text(
                'resource "aws_network_interface" "example" {\n'
                '  interface_type = "network_load_balancer"\n'
                '}\n\n'
                'resource "aws_network_interface" "efa" {\n'
                '  interface_type = "efa"\n'
                '}\n',
                encoding="utf-8",
            )
            subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; _strip_unsupported_network_interface_types "$2"',
                    "bash",
                    str(cleanup_script),
                    str(terraform_file),
                ],
                check=True,
                cwd=PROJECT_ROOT,
            )
            rendered = terraform_file.read_text(encoding="utf-8")
            self.assertNotIn('interface_type = "network_load_balancer"', rendered)
            self.assertIn('interface_type = "efa"', rendered)

    def test_cleanup_removes_instance_conflicts(self) -> None:
        cleanup_script = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "cleanup_generated_config.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            terraform_file = Path(temp_dir) / "auto_generated.tf"
            terraform_file.write_text(
                'resource "aws_instance" "primary" {\n'
                '  associate_public_ip_address = false\n'
                '  private_ip = "10.0.0.10"\n'
                '  secondary_private_ips = ["10.0.0.11"]\n'
                '  security_groups = []\n'
                '  subnet_id = "subnet-example"\n'
                '  vpc_security_group_ids = ["sg-example"]\n'
                '  source_dest_check = true\n'
                '  primary_network_interface {\n'
                '    network_interface_id = "eni-primary"\n'
                '  }\n'
                '}\n\n'
                'resource "aws_instance" "launch" {\n'
                '  launch_template {\n'
                '    id = "lt-example"\n'
                '    name = "example"\n'
                '    version = "1"\n'
                '  }\n'
                '}\n',
                encoding="utf-8",
            )
            subprocess.run(
                [
                    "bash",
                    "-c",
                    'source "$1"; _strip_instance_conflicts "$2"',
                    "bash",
                    str(cleanup_script),
                    str(terraform_file),
                ],
                check=True,
                cwd=PROJECT_ROOT,
            )
            rendered = terraform_file.read_text(encoding="utf-8")
            self.assertNotIn("associate_public_ip_address", rendered)
            self.assertNotIn("private_ip", rendered)
            self.assertNotIn("secondary_private_ips", rendered)
            self.assertNotIn("security_groups", rendered)
            self.assertNotIn("subnet_id", rendered)
            self.assertNotIn("vpc_security_group_ids", rendered)
            self.assertNotIn("source_dest_check", rendered)
            self.assertIn('network_interface_id = "eni-primary"', rendered)
            self.assertIn('id = "lt-example"', rendered)
            self.assertNotIn('name = "example"', rendered)
            self.assertIn('version = "1"', rendered)

    def test_module_generator_normalizes_stale_native_instance_conflicts(self) -> None:
        raw = (
            'resource "aws_instance" "example" {\n'
            '  private_ip = "10.0.0.10"\n'
            '  secondary_private_ips = ["10.0.0.11"]\n'
            '  security_groups = []\n'
            '  subnet_id = "subnet-example"\n'
            '  vpc_security_group_ids = ["sg-example"]\n'
            '  source_dest_check = true\n'
            '  primary_network_interface {\n'
            '    network_interface_id = "eni-example"\n'
            '  }\n'
            '  launch_template {\n'
            '    id = "lt-example"\n'
            '    name = "example"\n'
            '  }\n'
            '}\n'
        )
        rendered, rewrites = generate_module_calls.rewrite_native_references(
            {"type": "aws_instance", "raw": raw}, {}, {}, {}
        )

        self.assertEqual(rewrites, [])
        self.assertNotIn("private_ip", rendered)
        self.assertNotIn("secondary_private_ips", rendered)
        self.assertNotIn("security_groups", rendered)
        self.assertNotIn("subnet_id", rendered)
        self.assertNotIn("vpc_security_group_ids", rendered)
        self.assertNotIn("source_dest_check", rendered)
        self.assertNotIn('name = "example"', rendered)
        self.assertIn('network_interface_id = "eni-example"', rendered)
        self.assertIn('id = "lt-example"', rendered)

    def test_module_generator_preserves_backup_plan_advanced_settings(self) -> None:
        raw = (
            'resource "aws_backup_plan" "example" {\n'
            '  name = "example"\n'
            '  rule {\n'
            '    rule_name = "daily"\n'
            '    lifecycle {\n'
            '      delete_after = 35\n'
            '    }\n'
            '  }\n'
            '}\n'
        )
        rendered, rewrites = generate_module_calls.rewrite_native_references(
            {"type": "aws_backup_plan", "raw": raw}, {}, {}, {}
        )

        self.assertEqual(rewrites, [])
        self.assertIn("ignore_changes = [advanced_backup_setting]", rendered)
        self.assertEqual(rendered.count("lifecycle {"), 2)

    def test_build_rejects_interrupted_configuration_generation(self) -> None:
        build_script = (
            PROJECT_ROOT
            / "scripts"
            / "commands"
            / "terraform"
            / "build.sh"
        ).read_text(encoding="utf-8")

        self.assertIn(
            'if [[ $generate_exit_code -ge 128 ]]',
            build_script,
        )
        self.assertIn(
            'if [[ ! -s "${dir}/auto_generated.tf" ]]',
            build_script,
        )

    def test_latest_revision_selector_keeps_dev_native(self) -> None:
        generator_path = (
            PROJECT_ROOT
            / "scripts"
            / "terraform"
            / "generate_module_calls.py"
        )
        spec = importlib.util.spec_from_file_location(
            "module_call_generator",
            generator_path,
        )
        assert spec and spec.loader
        generator = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(generator)

        resources = [
            {"type": "aws_ecs_task_definition", "address": "task.old"},
            {"type": "aws_ecs_task_definition", "address": "task.current"},
        ]
        imports = {
            "task.old": {"id": "example:8"},
            "task.current": {"id": "example:10"},
        }
        contract = {
            "aws_ecs_task_definition": {
                "latest_revision_per_family": True,
            }
        }
        latest = generator.latest_revision_resource_addresses(
            resources,
            imports,
            contract,
        )

        self.assertEqual(latest, {"task.current"})
        self.assertEqual(
            generator.environment_preservation_reason(
                resources[1],
                {
                    "enabled_environments": ["prd"],
                    "latest_revision_per_family": True,
                },
                "dev",
                imports,
                latest,
            ),
            "module contract disabled for environment dev",
        )
        self.assertEqual(
            generator.environment_preservation_reason(
                resources[0],
                {
                    "enabled_environments": ["prd"],
                    "latest_revision_per_family": True,
                },
                "prd",
                imports,
                latest,
            ),
            "historical revision preserved natively",
        )

    def test_ecs_cluster_nested_name_does_not_replace_cluster_name(self) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            output = temp / "output"
            source.write_text(
                'resource "aws_ecs_cluster" "example" {\n'
                '  name = "example-cluster"\n'
                "  tags = {}\n"
                "  setting {\n"
                '    name  = "containerInsights"\n'
                '    value = "enabled"\n'
                "  }\n"
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_ecs_cluster.example\n"
                '  id = "example-cluster"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../tag",
                    "example",
                    "unified",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            generated = (output / "main.tf").read_text(encoding="utf-8")
            self.assertIn('module "example_cluster"', generated)
            self.assertIn('name = "example-cluster"', generated)
            self.assertIn(
                'container_insights_name = "containerInsights"',
                generated,
            )

    def test_native_ecs_service_rewrites_unique_cluster_arn_alias(self) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        cluster_arn = (
            "arn:aws:ecs:us-east-1:111122223333:cluster/example-cluster"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            output = temp / "output"
            source.write_text(
                'resource "aws_ecs_cluster" "example" {\n'
                '  name = "example-cluster"\n'
                "  tags = {}\n"
                "  setting {\n"
                '    name  = "containerInsights"\n'
                '    value = "enabled"\n'
                "  }\n"
                "}\n\n"
                'resource "aws_ecs_service" "example" {\n'
                f'  cluster = "{cluster_arn}"\n'
                '  name    = "example-service"\n'
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_ecs_cluster.example\n"
                '  id = "example-cluster"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_ecs_service.example\n"
                '  id = "example-cluster/example-service"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../tag",
                    "example",
                    "unified",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            generated = (output / "main.tf").read_text(encoding="utf-8")
            report = json.loads(
                (output / "modularization_report.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertIn("cluster = module.example_cluster.arn", generated)
            self.assertNotIn(f'cluster = "{cluster_arn}"', generated)
            self.assertEqual(len(report["rewritten_references"]), 1)
            self.assertEqual(
                report["rewritten_references"][0]["identity"],
                cluster_arn,
            )

    def test_native_ecs_service_preserves_ambiguous_cluster_arn_alias(
        self,
    ) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        cluster_arn = (
            "arn:aws:ecs:us-east-1:111122223333:cluster/shared-cluster"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            output = temp / "output"
            cluster_body = (
                '  name = "shared-cluster"\n'
                "  tags = {}\n"
                "  setting {\n"
                '    name  = "containerInsights"\n'
                '    value = "enabled"\n'
                "  }\n"
            )
            source.write_text(
                'resource "aws_ecs_cluster" "first" {\n'
                f"{cluster_body}"
                "}\n\n"
                'resource "aws_ecs_cluster" "second" {\n'
                f"{cluster_body}"
                "}\n\n"
                'resource "aws_ecs_service" "example" {\n'
                f'  cluster = "{cluster_arn}"\n'
                '  name    = "example-service"\n'
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_ecs_cluster.first\n"
                '  id = "shared-cluster"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_ecs_cluster.second\n"
                '  id = "shared-cluster"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_ecs_service.example\n"
                '  id = "shared-cluster/example-service"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../tag",
                    "example",
                    "unified",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            generated = (output / "main.tf").read_text(encoding="utf-8")
            report = json.loads(
                (output / "modularization_report.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertIn(f'cluster = "{cluster_arn}"', generated)
            self.assertEqual(report["rewritten_references"], [])

    def test_module_inputs_rewrite_arn_alias_and_list_elements(self) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        template_contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        cluster_arn = (
            "arn:aws:ecs:us-east-1:111122223333:cluster/example-cluster"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            contract = temp / "contract.json"
            output = temp / "output"
            contract_data = json.loads(
                template_contract.read_text(encoding="utf-8")
            )
            contract_data["resource_types"]["aws_ecs_service"] = {
                "module_source": "../../../modules/ecs/service",
                "unified_module_source": "../../modules/ecs/service",
                "import_target": "aws_ecs_service.this",
                "name_fields": ["name"],
                "variables": {
                    "name": {"source": "name"},
                    "cluster": {
                        "source": "cluster",
                        "reference": {
                            "target_types": {"aws_ecs_cluster": "arn"}
                        },
                    },
                    "subnets": {
                        "source": "subnets",
                        "reference": {
                            "target_types": {"aws_subnet": "id"}
                        },
                    },
                },
            }
            contract.write_text(
                json.dumps(contract_data),
                encoding="utf-8",
            )
            source.write_text(
                'resource "aws_ecs_cluster" "cluster" {\n'
                '  name = "example-cluster"\n'
                "  tags = {}\n"
                "  setting {\n"
                '    name  = "containerInsights"\n'
                '    value = "enabled"\n'
                "  }\n"
                "}\n\n"
                'resource "aws_subnet" "unique" {\n'
                '  cidr_block        = "10.0.1.0/24"\n'
                '  availability_zone = "us-east-1a"\n'
                '  vpc_id            = "vpc-example"\n'
                "  tags              = {}\n"
                "}\n\n"
                'resource "aws_subnet" "ambiguous_first" {\n'
                '  cidr_block        = "10.0.2.0/24"\n'
                '  availability_zone = "us-east-1a"\n'
                '  vpc_id            = "vpc-example"\n'
                "  tags              = {}\n"
                "}\n\n"
                'resource "aws_subnet" "ambiguous_second" {\n'
                '  cidr_block        = "10.0.3.0/24"\n'
                '  availability_zone = "us-east-1a"\n'
                '  vpc_id            = "vpc-example"\n'
                "  tags              = {}\n"
                "}\n\n"
                'resource "aws_ecs_service" "service" {\n'
                f'  cluster = "{cluster_arn}"\n'
                '  name     = "example-service"\n'
                '  subnets  = ["subnet-unique", "subnet-shared"]\n'
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_ecs_cluster.cluster\n"
                '  id = "example-cluster"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_subnet.unique\n"
                '  id = "subnet-unique"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_subnet.ambiguous_first\n"
                '  id = "subnet-shared"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_subnet.ambiguous_second\n"
                '  id = "subnet-shared"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_ecs_service.service\n"
                '  id = "example-cluster/example-service"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../tag",
                    "example",
                    "unified",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            generated = (output / "main.tf").read_text(encoding="utf-8")
            report = json.loads(
                (output / "modularization_report.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertIn("cluster = module.example_cluster.arn", generated)
            self.assertIn(
                "subnets = [module.r_10_0_1_0_24.id, "
                '"subnet-shared"]',
                generated,
            )
            service_rewrites = [
                rewrite
                for rewrite in report["rewritten_references"]
                if rewrite["source"] == "aws_ecs_service.service"
            ]
            self.assertEqual(len(service_rewrites), 2)

    def test_contract_condition_preserves_matching_variant_with_reason(
        self,
    ) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        template_contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            contract = temp / "contract.json"
            output = temp / "output"
            contract_data = json.loads(
                template_contract.read_text(encoding="utf-8")
            )
            contract_data["resource_types"]["aws_ecs_cluster"][
                "preserve_native_when"
            ] = [
                {
                    "field": "name",
                    "in": ["legacy-cluster"],
                    "reason": "legacy cluster exception",
                }
            ]
            contract.write_text(
                json.dumps(contract_data),
                encoding="utf-8",
            )
            cluster_body = (
                "  tags = {}\n"
                "  setting {\n"
                '    name  = "containerInsights"\n'
                '    value = "enabled"\n'
                "  }\n"
            )
            source.write_text(
                'resource "aws_ecs_cluster" "supported" {\n'
                '  name = "supported-cluster"\n'
                f"{cluster_body}"
                "}\n\n"
                'resource "aws_ecs_cluster" "legacy" {\n'
                '  name = "legacy-cluster"\n'
                f"{cluster_body}"
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_ecs_cluster.supported\n"
                '  id = "supported-cluster"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_ecs_cluster.legacy\n"
                '  id = "legacy-cluster"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../tag",
                    "example",
                    "unified",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            generated = (output / "main.tf").read_text(encoding="utf-8")
            report = json.loads(
                (output / "modularization_report.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertIn('module "supported_cluster"', generated)
            self.assertIn(
                'resource "aws_ecs_cluster" "legacy"',
                generated,
            )
            self.assertEqual(
                report["preserved_native_reasons"],
                {
                    "aws_ecs_cluster.legacy": "legacy cluster exception",
                },
            )

    def test_module_contract_v2_merges_shared_exact_tags_and_import(self) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            output = temp / "output"
            source.write_text(
                'resource "aws_s3_bucket" "example" {\n'
                '  bucket = "example-bucket"\n'
                '  tags = {\n'
                '    Owner = "application-team"\n'
                "  }\n"
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_s3_bucket.example\n"
                '  id = "example-bucket"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../../tag",
                    "example",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            generated = (output / "main.tf").read_text(encoding="utf-8")
            generated_imports = (
                output / "imports_generated.tf"
            ).read_text(encoding="utf-8")
            report = json.loads(
                (output / "modularization_report.json").read_text(
                    encoding="utf-8"
                )
            )

            self.assertIn("tags = merge({", generated)
            self.assertIn(
                "for key, value in module.tags.tags",
                generated,
            )
            self.assertIn('module "tags"', generated)
            self.assertIn(
                "to = module.example_bucket.aws_s3_bucket.this",
                generated_imports,
            )
            self.assertEqual(report["module_contract_schema"], 2)
            self.assertEqual(
                report["shared_tag_consumers"],
                ["aws_s3_bucket.example"],
            )

    def test_module_contract_rejects_unknown_schema(self) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            contract = temp / "contract.json"
            source.write_text("", encoding="utf-8")
            imports.write_text("", encoding="utf-8")
            contract.write_text(
                '{"schema_version": 999, "resource_types": {}}',
                encoding="utf-8",
            )

            result = subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(temp / "output"),
                    "dev",
                    "EXAMPLE",
                    "../../../tag",
                    "example",
                ],
                cwd=PROJECT_ROOT,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 4)
            self.assertIn("Unsupported module contract schema", result.stderr)

    def test_module_contract_generates_unified_root_sources(self) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            output = temp / "output"
            source.write_text(
                'resource "aws_kms_key" "example" {\n'
                '  description = "example key"\n'
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_kms_key.example\n"
                '  id = "key-123456"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../tag",
                    "example",
                    "unified",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            generated = (output / "main.tf").read_text(encoding="utf-8")
            report = json.loads(
                (output / "modularization_report.json").read_text(
                    encoding="utf-8"
                )
            )
            self.assertIn('source = "../../modules/kms/key"', generated)
            self.assertNotIn('module "tags"', generated)
            self.assertEqual(report["destination_layout"], "unified")

    def test_module_contract_rewrites_unique_exact_reference(self) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            output = temp / "output"
            source.write_text(
                'resource "aws_kms_key" "key" {\n'
                '  description = "topic key"\n'
                "}\n\n"
                'resource "aws_sns_topic" "topic" {\n'
                '  name              = "example-topic"\n'
                '  kms_master_key_id = "key-123456"\n'
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_kms_key.key\n"
                '  id = "key-123456"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_sns_topic.topic\n"
                '  id = "arn:aws:sns:us-east-1:123456789012:example-topic"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../tag",
                    "example",
                    "unified",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            generated = (output / "main.tf").read_text(encoding="utf-8")
            report = json.loads(
                (output / "modularization_report.json").read_text(
                    encoding="utf-8"
                )
            )

            self.assertIn(
                "kms_master_key_id = module.topic_key.id",
                generated,
            )
            self.assertEqual(len(report["rewritten_references"]), 1)
            self.assertEqual(
                report["rewritten_references"][0]["target"],
                "aws_kms_key.key",
            )

    def test_module_contract_rewrites_native_exact_reference(self) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            output = temp / "output"
            secret_arn = (
                "arn:aws:secretsmanager:us-east-1:123456789012:"
                "secret:example-AbCdEf"
            )
            source.write_text(
                'resource "aws_ecs_task_definition" "task" {\n'
                "  container_definitions = jsonencode({\n"
                f'    valueFrom = "{secret_arn}"\n'
                "  })\n"
                "}\n\n"
                'resource "aws_secretsmanager_secret" "secret" {\n'
                '  name = "example"\n'
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_ecs_task_definition.task\n"
                '  id = "example-task:1"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_secretsmanager_secret.secret\n"
                f'  id = "{secret_arn}"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../tag",
                    "example",
                    "unified",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            generated = (output / "main.tf").read_text(encoding="utf-8")
            report = json.loads(
                (output / "modularization_report.json").read_text(
                    encoding="utf-8"
                )
            )

            self.assertIn(
                "valueFrom = module.example.arn",
                generated,
            )
            self.assertNotIn(f'valueFrom = "{secret_arn}"', generated)
            self.assertEqual(len(report["rewritten_references"]), 1)
            self.assertEqual(
                report["rewritten_references"][0]["input"],
                "native_exact_identity",
            )

    def test_module_contract_preserves_ambiguous_identity_literal(self) -> None:
        generator = (
            PROJECT_ROOT / "scripts" / "terraform" / "generate_module_calls.py"
        )
        contract = (
            PROJECT_ROOT
            / "templates"
            / "destination"
            / "config"
            / "resource_module_map.json"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            source = temp / "main.tf"
            imports = temp / "imports.tf"
            output = temp / "output"
            source.write_text(
                'resource "aws_cloudformation_stack" "stack" {\n'
                '  parameters = { BucketName = "shared-identity" }\n'
                "}\n\n"
                'resource "aws_s3_bucket" "first" {\n'
                '  bucket = "first"\n'
                "}\n\n"
                'resource "aws_s3_bucket" "second" {\n'
                '  bucket = "second"\n'
                "}\n",
                encoding="utf-8",
            )
            imports.write_text(
                "import {\n"
                "  to = aws_cloudformation_stack.stack\n"
                '  id = "example-stack"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_s3_bucket.first\n"
                '  id = "shared-identity"\n'
                "}\n\n"
                "import {\n"
                "  to = aws_s3_bucket.second\n"
                '  id = "shared-identity"\n'
                "}\n",
                encoding="utf-8",
            )

            subprocess.run(
                [
                    "python3",
                    str(generator),
                    str(source),
                    str(imports),
                    str(contract),
                    str(output),
                    "dev",
                    "EXAMPLE",
                    "../../tag",
                    "example",
                    "unified",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            generated = (output / "main.tf").read_text(encoding="utf-8")
            report = json.loads(
                (output / "modularization_report.json").read_text(
                    encoding="utf-8"
                )
            )

            self.assertIn('BucketName = "shared-identity"', generated)
            self.assertEqual(report["rewritten_references"], [])

    def test_environment_context_uses_work_directory(self) -> None:
        environment_script = PROJECT_ROOT / "scripts" / "core" / "environment.sh"
        with tempfile.TemporaryDirectory() as temp_dir:
            command = (
                f"source {environment_script}; "
                "terraform_get_project_name() { echo example; }; "
                "terraform_set_env_context prd; "
                'printf "%s" "$TF_ENV_DIR"'
            )
            result = subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
                env={"PROJECT_ROOT": temp_dir, "PATH": "/usr/bin:/bin"},
            )

            self.assertEqual(result.stdout, f"{temp_dir}/work/example/prd")
            self.assertTrue(Path(result.stdout).is_dir())

    def test_account_scope_uses_account_environment_work_directory(self) -> None:
        environment_script = PROJECT_ROOT / "scripts" / "core" / "environment.sh"
        with tempfile.TemporaryDirectory() as temp_dir:
            command = (
                f"PROJECT_ROOT={temp_dir}; "
                f"source {environment_script}; "
                "terraform_get_project_name() { echo example; }; "
                "TF_ACCOUNT_KEY=account-a; export TF_ACCOUNT_KEY; "
                "terraform_set_env_context prd; "
                'printf "%s" "$TF_ENV_DIR"'
            )
            result = subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
                env={"PROJECT_ROOT": temp_dir, "PATH": "/usr/bin:/bin"},
            )

            self.assertEqual(
                result.stdout,
                f"{temp_dir}/work/example/account-a/prd",
            )
            self.assertTrue(Path(result.stdout).is_dir())

    def test_account_registry_resolves_alias_and_validates_environments(self) -> None:
        environment_script = PROJECT_ROOT / "scripts" / "core" / "environment.sh"
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            (temp / "config").mkdir()
            (temp / "config" / "environments.conf").write_text(
                "ACCOUNT_1_KEY=account-a\n"
                "ACCOUNT_1_ID=123456789012\n"
                "ACCOUNT_1_PROFILE=account-a-prd\n"
                "ACCOUNT_1_ENVIRONMENTS=prd,qa\n",
                encoding="utf-8",
            )
            command = (
                f"PROJECT_ROOT={temp}; "
                f"source {environment_script}; "
                "log_error() { :; }; "
                "terraform_validate_account_registry; "
                "printf '%s\\n' "
                '"$(terraform_get_account_field account-a ID)" '
                '"$(terraform_get_account_field account-a ENVIRONMENTS)"'
            )
            result = subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.stdout, "123456789012\nprd,qa\n")
            self.assertEqual(
                subprocess.run(
                    [
                        "bash",
                        "-c",
                        f"PROJECT_ROOT={temp}; source {environment_script}; "
                        "terraform_list_account_keys",
                    ],
                    cwd=PROJECT_ROOT,
                    check=True,
                    capture_output=True,
                    text=True,
                ).stdout,
                "account-a\n",
            )

    def test_demo_environment_selects_its_single_registered_account(self) -> None:
        environment_script = PROJECT_ROOT / "scripts" / "core" / "environment.sh"
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            (temp / "config").mkdir()
            (temp / "config" / "environments.conf").write_text(
                "ACCOUNT_1_KEY=demo-account\n"
                "ACCOUNT_1_ID=123456789012\n"
                "ACCOUNT_1_PROFILE=demo-profile\n"
                "ACCOUNT_1_ENVIRONMENTS=demo\n",
                encoding="utf-8",
            )
            command = (
                "set -euo pipefail; "
                f"PROJECT_ROOT={temp}; "
                "AWS_PROFILE=demo-profile; export AWS_PROFILE; "
                f"source {environment_script}; "
                "log_error() { :; }; log_info() { :; }; "
                "aws_get_account() { printf '123456789012'; }; "
                "terraform_validate_environment demo; "
                "printf '%s' \"$TF_ACCOUNT_KEY\""
            )
            result = subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.stdout, "demo-account")

    def test_demo_discovery_is_scoped_to_the_lab_project_tag(self) -> None:
        discovery_script = (
            PROJECT_ROOT
            / "scripts"
            / "providers"
            / "aws"
            / "resource_explorer_discover.sh"
        )
        command = (
            "set -euo pipefail; "
            f"source {discovery_script}; "
            "aws_generic_discover_region() { "
            "printf '%s|%s' \"$AWS_DISCOVER_TAG_KEY\" \"$AWS_DISCOVER_TAG_VALUE\"; "
            "}; "
            "aws_resource_explorer_enabled_for_environment() { return 1; }; "
            "aws_discover_environment demo"
        )
        result = subprocess.run(
            ["bash", "-c", command],
            cwd=PROJECT_ROOT,
            check=True,
            capture_output=True,
            text=True,
        )

        self.assertEqual(result.stdout, "Project|tf-importer-demo")

    def test_account_modularization_overrides_fallback_defaults(self) -> None:
        environment_script = PROJECT_ROOT / "scripts" / "core" / "environment.sh"
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            (temp / "config").mkdir()
            (temp / "config" / "environments.conf").write_text(
                "ACCOUNT_1_KEY=account-a\n"
                "ACCOUNT_1_STATE_BUCKET=account-a-state\n"
                "ACCOUNT_1_STATE_KEY_PREFIX=account-a-prefix\n",
                encoding="utf-8",
            )
            (temp / "config" / "modularization.conf").write_text(
                "STATE_BUCKET=default-state\n"
                "STATE_KEY_PREFIX=default-prefix\n"
                "COST_CENTER=DEFAULT\n",
                encoding="utf-8",
            )
            command = (
                f"PROJECT_ROOT={temp}; "
                f"source {environment_script}; "
                "TF_ACCOUNT_KEY=account-a; export TF_ACCOUNT_KEY; "
                "printf '%s\\n' "
                '"$(terraform_get_scoped_modularization_value STATE_BUCKET)" '
                '"$(terraform_get_scoped_modularization_value STATE_KEY_PREFIX)" '
                '"$(terraform_get_scoped_modularization_value COST_CENTER)"'
            )
            result = subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertEqual(
                result.stdout,
                "account-a-state\naccount-a-prefix\nDEFAULT\n",
            )

    def test_generated_versions_file_enforces_compatibility(self) -> None:
        environment_script = PROJECT_ROOT / "scripts" / "core" / "environment.sh"
        logger_script = PROJECT_ROOT / "scripts" / "core" / "logger.sh"
        with tempfile.TemporaryDirectory() as temp_dir:
            command = (
                f"PROJECT_ROOT={PROJECT_ROOT}; "
                f"LOG_FILE={temp_dir}/test.log; "
                f"source {logger_script}; "
                f"source {environment_script}; "
                "terraform_get_modularization_value() { "
                'case "$1" in '
                "TERRAFORM_VERSION_CONSTRAINT) echo '>= 1.5.0, < 2.0.0' ;; "
                "AWS_PROVIDER_VERSION_CONSTRAINT) echo '>= 6.54.0, < 7.0.0' ;; "
                "esac; "
                "}; "
                f"terraform_generate_versions_file {temp_dir}"
            )
            subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            versions = (Path(temp_dir) / "versions.tf").read_text(encoding="utf-8")

            self.assertIn('required_version = ">= 1.5.0, < 2.0.0"', versions)
            self.assertIn('version = ">= 6.54.0, < 7.0.0"', versions)

    def test_logger_reports_progress_on_stderr_only(self) -> None:
        logger_script = PROJECT_ROOT / "scripts" / "core" / "logger.sh"
        with tempfile.TemporaryDirectory() as temp_dir:
            log_file = Path(temp_dir) / "tf-importer.log"
            result = subprocess.run(
                [
                    "bash",
                    "-c",
                    f"source {logger_script}; log_info 'pipeline progress'",
                ],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
                env={
                    "LOG_FILE": str(log_file),
                    "LOG_LEVEL": "INFO",
                    "LOG_CONSOLE": "1",
                    "PATH": "/usr/bin:/bin",
                },
            )

            self.assertEqual(result.stdout, "")
            self.assertIn("[INFO] pipeline progress", result.stderr)
            self.assertIn(
                "[INFO] pipeline progress",
                log_file.read_text(encoding="utf-8"),
            )

    def test_discovery_is_sorted_before_import_generation(self) -> None:
        discovery_script = (
            PROJECT_ROOT / "scripts" / "providers" / "aws" / "generic_discover.sh"
        )
        content = discovery_script.read_text(encoding="utf-8")

        self.assertIn("| sort_by(.arn)", content)

    def test_resource_explorer_discovery_is_opt_in_and_deduplicated(self) -> None:
        generic_script = (
            PROJECT_ROOT / "scripts" / "providers" / "aws" / "generic_discover.sh"
        )
        explorer_script = (
            PROJECT_ROOT
            / "scripts"
            / "providers"
            / "aws"
            / "resource_explorer_discover.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            config = temp / "config"
            config.mkdir()
            (config / "environments.conf").write_text(
                "RESOURCE_EXPLORER_ENVIRONMENTS=prd\n",
                encoding="utf-8",
            )
            command = (
                "set -euo pipefail; "
                f"PROJECT_ROOT={temp!s}; "
                "AWS_DISCOVER_REGION=us-east-1; "
                f"source {generic_script}; "
                f"source {explorer_script}; "
                "log_info() { :; }; log_debug() { :; }; log_error() { :; }; "
                "aws() { "
                "  if [[ $1 == resourcegroupstaggingapi ]]; then "
                "    printf '%s\\n' '{\"ResourceTagMappingList\": [' "
                "      '{\"ResourceARN\":\"arn:aws:s3:::shared\",\"Tags\":[]},' "
                "      '{\"ResourceARN\":\"arn:aws:sns:us-east-1:123:topic/shared\",\"Tags\":[]}' "
                "      '],\"PaginationToken\":\"\"}'; "
                "  else "
                "    printf '%s\\n' '{\"Resources\": [' "
                "      '{\"Arn\":\"arn:aws:lambda:us-east-1:123:function/only-explorer\",\"Region\":\"us-east-1\",\"ResourceType\":\"AWS::Lambda::Function\"},' "
                "      '{\"Arn\":\"arn:aws:s3:::shared\",\"Region\":\"us-east-1\",\"ResourceType\":\"AWS::S3::Bucket\"}' "
                "      '],\"NextToken\":\"\"}'; "
                "  fi; "
                "}; "
                "aws_discover_environment prd"
            )
            result = subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )
            discovered = json.loads(result.stdout)

            self.assertEqual(
                [item["arn"] for item in discovered],
                [
                    "arn:aws:lambda:us-east-1:123:function/only-explorer",
                    "arn:aws:s3:::shared",
                    "arn:aws:sns:us-east-1:123:topic/shared",
                ],
            )
            shared = discovered[1]
            self.assertEqual(
                shared["sources"],
                ["resource_explorer", "resource_groups_tagging_api"],
            )
            self.assertEqual(
                discovered[0]["sources"], ["resource_explorer"]
            )

    def test_resource_explorer_uses_selected_account_override(self) -> None:
        environment_script = PROJECT_ROOT / "scripts" / "core" / "environment.sh"
        explorer_script = (
            PROJECT_ROOT
            / "scripts"
            / "providers"
            / "aws"
            / "resource_explorer_discover.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            temp = Path(temp_dir)
            config = temp / "config"
            config.mkdir()
            (config / "environments.conf").write_text(
                "ACCOUNT_1_KEY=account-a\n"
                "ACCOUNT_1_ID=123456789012\n"
                "ACCOUNT_1_PROFILE=account-a\n"
                "ACCOUNT_1_ENVIRONMENTS=prd\n"
                "ACCOUNT_1_RESOURCE_EXPLORER=true\n",
                encoding="utf-8",
            )
            command = (
                "set -euo pipefail; "
                f"PROJECT_ROOT={temp}; "
                "TF_ACCOUNT_KEY=account-a; export TF_ACCOUNT_KEY; "
                f"source {environment_script}; "
                f"source {explorer_script}; "
                "aws_resource_explorer_enabled_for_environment prd"
            )
            subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

    def test_resource_explorer_does_not_mix_incompatible_pagination_flags(self) -> None:
        explorer_script = (
            PROJECT_ROOT
            / "scripts"
            / "providers"
            / "aws"
            / "resource_explorer_discover.sh"
        ).read_text(encoding="utf-8")
        self.assertNotIn("--no-paginate", explorer_script)
        self.assertIn("--starting-token", explorer_script)

    def test_generated_terraform_blocks_are_sorted_by_address(self) -> None:
        sorter = (
            PROJECT_ROOT / "scripts" / "terraform" / "sort_terraform_blocks.py"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            resources = Path(temp_dir) / "main.tf"
            imports = Path(temp_dir) / "imports.tf"
            resources.write_text(
                'resource "aws_s3_bucket" "z" {\n'
                '  tags = { value = "}" }\n'
                '}\n\n'
                'resource "aws_s3_bucket" "a" {\n}\n',
                encoding="utf-8",
            )
            imports.write_text(
                'import {\n  to = aws_s3_bucket.z\n  id = "z"\n}\n\n'
                'import {\n  to = aws_s3_bucket.a\n  id = "a"\n}\n',
                encoding="utf-8",
            )

            subprocess.run(
                ["python3", str(sorter), str(resources), str(imports)],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertLess(
                resources.read_text(encoding="utf-8").index('"a"'),
                resources.read_text(encoding="utf-8").index('"z"'),
            )
            self.assertLess(
                imports.read_text(encoding="utf-8").index("aws_s3_bucket.a"),
                imports.read_text(encoding="utf-8").index("aws_s3_bucket.z"),
            )

    def test_staging_cleanup_is_restricted_and_effective(self) -> None:
        modularize_script = (
            PROJECT_ROOT
            / "scripts"
            / "commands"
            / "terraform"
            / "modularize_all.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir) / "terraform" / "prd"
            valid_staging = staging_root / ".network.tf-importer.ABC123"
            unexpected = staging_root / "network"
            valid_staging.mkdir(parents=True)
            unexpected.mkdir()

            command = (
                f"source {modularize_script}; "
                f"TF_ACTIVE_STAGING_ROOT={staging_root}; "
                f"TF_ACTIVE_STAGING_DIR={valid_staging}; "
                "terraform_cleanup_active_staging"
            )
            subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertFalse(valid_staging.exists())
            self.assertTrue(unexpected.exists())

    def test_category_publication_removes_only_legacy_root_files(self) -> None:
        modularize_script = (
            PROJECT_ROOT
            / "scripts"
            / "commands"
            / "terraform"
            / "modularize_all.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            destination_project = Path(temp_dir) / "example-iac"
            destination = destination_project / "terraform" / "prd"
            category = destination / "network"
            packages = destination / "lambda_code"
            category.mkdir(parents=True)
            packages.mkdir()
            for filename in (
                "backend.tf",
                "imports_generated.tf",
                "main.tf",
                "provider.tf",
                "versions.tf",
            ):
                (destination / filename).write_text("legacy", encoding="utf-8")
            (category / "main.tf").write_text("category", encoding="utf-8")

            command = (
                "log_info() { :; }; log_error() { :; }; "
                f"source {modularize_script}; "
                "terraform_remove_legacy_unified_root "
                f"{destination} {destination_project}"
            )
            subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertFalse((destination / "main.tf").exists())
            self.assertFalse(packages.exists())
            self.assertEqual(
                (category / "main.tf").read_text(encoding="utf-8"),
                "category",
            )

    def test_pipeline_publishes_category_roots(self) -> None:
        pipeline_script = (
            PROJECT_ROOT
            / "scripts"
            / "commands"
            / "terraform"
            / "pipeline.sh"
        ).read_text(encoding="utf-8")

        self.assertIn('cmd_modularize_all "$env"', pipeline_script)
        self.assertNotIn("cmd_unified_publish", pipeline_script)

    def test_term_signal_cleans_active_staging(self) -> None:
        modularize_script = (
            PROJECT_ROOT
            / "scripts"
            / "commands"
            / "terraform"
            / "modularize_all.sh"
        )
        with tempfile.TemporaryDirectory() as temp_dir:
            staging_root = Path(temp_dir) / "terraform" / "prd"
            valid_staging = staging_root / ".network.tf-importer.SIGNAL"
            valid_staging.mkdir(parents=True)
            command = (
                f"source {modularize_script}; "
                f"TF_ACTIVE_STAGING_ROOT={staging_root}; "
                f"TF_ACTIVE_STAGING_DIR={valid_staging}; "
                "terraform_install_staging_traps; "
                "kill -TERM $$"
            )
            result = subprocess.run(
                ["bash", "-c", command],
                cwd=PROJECT_ROOT,
                capture_output=True,
                text=True,
            )

            self.assertEqual(result.returncode, 143)
            self.assertFalse(valid_staging.exists())

    def test_project_has_no_terraform_apply_entrypoint(self) -> None:
        executable_sources = [PROJECT_ROOT / "Makefile", PROJECT_ROOT / "tf-importer"]
        executable_sources.extend((PROJECT_ROOT / "scripts").rglob("*.sh"))

        for path in executable_sources:
            content = path.read_text(encoding="utf-8")
            self.assertNotIn("terraform apply", content, str(path))
            self.assertNotIn("\napply:", content, str(path))


if __name__ == "__main__":
    unittest.main()
