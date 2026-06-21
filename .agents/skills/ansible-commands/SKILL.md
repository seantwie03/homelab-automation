---
name: ansible-commands
description: Use when running Ansible commands in this homelab repository, especially ansible, ansible-doc, ansible-playbook syntax checks, or ansible-lint validation. Prefer host-visible execution when Codex sandboxing can hide installed collections, inventory behavior, system facts, or Ansible temporary-file behavior.
---

# Ansible Commands

This repository is validated against the real workstation environment. Codex's
read-only sandbox can block Ansible temporary files, installed collection
discovery, local inventory behavior, or access to host state.

Run these outside the sandbox with `sandbox_permissions: require_escalated`:

- `ansible ...`
- `ansible-doc ...`
- `ansible-playbook --syntax-check ...`

Do not use unrestricted playbook execution as a validation shortcut. A normal
`ansible-playbook` run can change the host and still requires explicit user
intent.

Use the narrowest useful command:

- use `ansible-doc <module_or_plugin>` to verify module arguments and behavior
- use `ansible-playbook --syntax-check <playbook>.yml` for syntax validation
- use `ansible-lint` for repository linting

When an Ansible command fails, report whether it failed because of syntax,
missing collections, inventory or host targeting, permissions, or sandboxing. If
a sandboxed run failed with a likely sandbox-related temp-directory or
host-access error, rerun the same command outside the sandbox before treating
the failure as a repository defect.
