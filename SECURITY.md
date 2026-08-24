# Security Policy

## Scope and supported releases

Security reports are welcome for vulnerabilities in the current release of
`tf-importer`, including its account and region safeguards, import-only plan
enforcement, command execution, generated-file handling, and publication
controls. Only the latest published release receives security fixes. Older
releases may be asked to upgrade before a fix is evaluated.

## Reporting a vulnerability

Use GitHub's **Report a vulnerability** private reporting option on the
repository's Security page when it is available. Do not disclose a suspected
vulnerability in a public issue, discussion, or pull request. If private
vulnerability reporting is unavailable, contact the maintainers through a
private, project-specific GitHub channel and provide only a high-level request
for a secure reporting path; do not include vulnerability details or secrets
in that initial message.

Include the affected version, impact, prerequisites, and minimal reproduction
steps using fictitious identifiers and redacted output. Reports are
acknowledged and assessed as maintainer availability permits. The project does
not promise a fixed response or remediation deadline, but will communicate
material status changes through the private reporting channel.

## Protect sensitive data

Never attach credentials, access keys, session tokens, real account IDs, SSM
values, Lambda packages, generated Terraform, state, plans, inventories,
reports, or unsanitized logs and terminal output to public issues. Remove or
replace account context, resource identifiers, hostnames, usernames, and local
paths before sharing diagnostic material. A useful report must reproduce the
problem without real secrets.

The project never requires AWS credentials to be committed. Local
configuration and generated artifacts are ignored because they may contain
sensitive account context; keep them private even when they do not contain a
credential directly. If a secret may have been exposed, revoke or rotate it
through the relevant provider before continuing the report.
