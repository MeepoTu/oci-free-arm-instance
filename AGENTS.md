# Repository Guidelines

## Project Structure & Module Organization

This repository documents a GitHub Actions workflow for repeatedly attempting to create an Oracle Cloud Infrastructure Always Free Arm VM.

- `README.md` is the primary user guide; keep it aligned with workflow or secret changes.
- `LICENSE` contains the MIT license.
- `info.txt` and `*.pem` files are local credential material or notes; do not treat them as source files.
- If the provisioning workflow is restored, place it under `.github/workflows/create-vm.yml` and keep workflow-specific settings documented in `README.md`.

There is currently no application source tree, package manifest, or test suite.

## Build, Test, and Development Commands

There is no local build step.

- `git status` checks pending local changes.
- `git log --oneline -8` reviews recent commit style.
- `markdownlint README.md AGENTS.md` checks Markdown formatting if available.
- For workflow changes, run the GitHub Actions workflow manually from the Actions tab in a fork.

## Coding Style & Naming Conventions

Use concise Markdown, sentence-case prose, and numbered steps for setup instructions. Keep command examples in backticks and use fenced blocks for multi-line YAML or shell examples. Workflow files should use two-space YAML indentation, uppercase GitHub secret names such as `OCI_CLI_REGION`, and descriptive job or step names.

Prefer explicit names that match OCI terminology: `OCI_COMPARTMENT_ID`, `OCI_SUBNET_ID`, `AD_NAME`, `IMAGE_ID`, and `DISCORD_WEBHOOK_URL`.

## Testing Guidelines

For documentation changes, verify links, secret names, and step order against the README. For workflow changes, test in a fork with GitHub Secrets configured. Check the Actions log for OCI CLI installation, authentication, instance creation output, and Discord notification behavior.

## Commit & Pull Request Guidelines

Recent history uses short imperative messages such as `Update create-vm.yml` and `Delete .github/workflows/create-vm.yml`. Follow that style, but be specific when possible, for example `Document required OCI secrets`.

Pull requests should include a short description, reason for the change, affected files, and validation performed. For workflow changes, include the relevant Actions run result or log excerpt with secrets redacted.

## Security & Configuration Tips

Never commit private keys, OCI OCIDs tied to a personal account, fingerprints, or Discord webhook URLs. Store runtime values in GitHub Secrets and reference them from workflows with `${{ secrets.NAME }}`. If sensitive data is committed by mistake, rotate the affected OCI API key or webhook before opening a pull request.
