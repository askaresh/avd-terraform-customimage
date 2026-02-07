# Module: shared-image-gallery

Creates:
- Azure Compute Gallery (formerly Shared Image Gallery)
- Gallery Image Definition (Windows, Generalized, Gen2)

## Security Features

The image definition includes the following security settings (enabled by default):

| Setting | Default | Description |
|---------|---------|-------------|
| `trusted_launch_supported` | `true` | Supports Trusted Launch VMs with standard security |
| `accelerated_network_support_enabled` | `true` | Supports Accelerated Networking |
| `hyper_v_generation` | `V2` | Uses Gen2 VMs for improved security |

## Configuration

Image **replication** and **storage type** are configured on the *image version* (published by Image Builder), not on the image definition. That configuration is handled in the `image-builder` module.

## Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `trusted_launch_supported` | bool | true | Enable Trusted Launch support |
| `accelerated_network_support_enabled` | bool | true | Enable Accelerated Networking |
| `hyper_v_generation` | string | V2 | Hyper-V generation (V1 or V2) |
