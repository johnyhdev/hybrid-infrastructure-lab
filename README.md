# Hybrid Infrastructure Lab

Hands-on hybrid infrastructure automation lab.

## Technologies

- Azure
- Terraform
- Ansible
- GitHub Actions
- Linux
- Nginx
- Monitoring
- Security as Code

## Architecture

Private Azure VM with no public SSH access.

Infrastructure is provisioned using Terraform and configuration is managed using Ansible.

## Terraform State

Terraform state is stored remotely in Azure Blob Storage.

- Backend: AzureRM
- Storage: Azure Blob Storage
- TLS: 1.2+
- Public blob access: Disabled
- State locking: Enabled through the backend
- Local state is not committed to Git
