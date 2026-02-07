# Module: image-builder

Creates an Azure VM Image Builder **Image Template** using an ARM template deployment.

## Key behaviors
- Uses a **user-assigned managed identity**
- Downloads scripts using **AIB File customizers** from **private** blob storage (no SAS tokens)
- Runs PowerShell steps to:
  - Write application configuration (JSON) to the build VM
  - Install applications using **multi-strategy installer** (winget/direct/offline/psadt)
  - (optional) Run Windows Update
  - (optional) Run AVD Optimization Tool
  - (optional) Install/configure FSLogix
  - Finalize image cleanup
- Publishes a version to **Azure Compute Gallery** (SharedImage distributor)

## Multi-Strategy Application Installation

The module supports a flexible application installation framework:

| Method | Description |
|--------|-------------|
| `winget` | Windows Package Manager (default) |
| `direct` | Direct URL download + silent install |
| `offline` | Pre-staged packages from blob storage |
| `psadt` | PSAppDeployToolkit packages |

Applications are configured via the `applications_config` variable, which is passed as a Base64-encoded JSON string to the PowerShell installer script. This ensures proper handling of complex configurations across the Azure Image Builder pipeline.

## Auto-run
If `auto_run = true`, the template is created/updated with `autoRun = Enabled`. AIB starts a build automatically after a successful template create/update.

Terraform does **not** wait for the build to finish. Monitor with:
- `az image builder show-runs`
- `az image builder show --query lastRunStatus`

## Important Notes
- Azure Image Builder does not support in-place template updates
- To modify a template, delete the existing one first, then re-apply Terraform
- Build typically takes 60-80 minutes (Windows Updates is the longest step)
