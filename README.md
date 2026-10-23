# Project Sentinel — AWS Infrastructure Reference

## Executive summary

Project Sentinel is a secure foundation for a document assessment and credentialing platform. The infrastructure is delivered in two phases:

1. **Phase 1 — Secure staging:** a cost-conscious environment for integration and acceptance testing. It uses smaller compute and database capacity and a single NAT gateway while retaining private application and database subnets, encryption, and a web application firewall.
2. **Phase 2 — Production:** a resilient deployment with larger capacity, Multi-AZ database availability, and a NAT gateway in each Availability Zone. Production sizing and scaling remain explicit environment inputs.

Both phases use the same composable Terraform modules so that security boundaries and deployment behavior stay consistent as capacity changes.

## Architecture

```mermaid
flowchart LR
    Internet((Internet)) --> WAF[AWS WAFv2]
    WAF --> ALB[Public Application Load Balancer<br/>HTTP redirects to HTTPS]
    ALB -->|HTTPS with ACM certificate| ECS[ECS Fargate tasks<br/>Private application subnets]
    ECS --> RDS[(PostgreSQL RDS<br/>Private database subnets)]
    ECS --> S3[(Private S3<br/>Evidence Storage)]
    ECS --> Cognito[AWS Cognito<br/>Identity]
    KMS[AWS KMS<br/>Customer-managed key] --> S3
    KMS --> RDS
```

Terraform provisions the network, WAF, KMS key, IAM roles, evidence bucket, HTTPS load balancer, Fargate cluster/service, PostgreSQL database, and Cognito user pool/client. The application must still validate Cognito JWTs; creating a pool does not enforce authentication in application code. A region-matched ACM certificate and DNS record are external deployment inputs.

## Key architectural boundaries

- **Identity:** Authentication and MFA belong behind an identity provider boundary. The application is designed to integrate with Cognito rather than own credentials or authentication flows.
- **Evidence storage:** Documents are isolated in a private, versioned S3 bucket, encrypted with KMS, and accessed by a narrowly scoped workload role. This boundary can later be replaced by a dedicated document or evidence service without changing the assessment domain.
- **Assessment:** Assessment logic runs as a containerized service behind the ALB. Its API boundary separates the business workflow from storage and identity implementations.
- **Credentials:** Credential issuance and verification are separate domain capabilities from assessment. They can be moved to a dedicated managed credentialing service while preserving the application and evidence boundaries.

## Security first

- AWS WAFv2 protects the public ALB with AWS-managed common and known-bad-input rules plus a configurable rate limit.
- The ALB redirects HTTP to HTTPS and uses a supplied ACM certificate; production traffic must use a hostname covered by that certificate.
- Cognito provisions email-based sign-in, MFA, a public client, and an issuer URL for application JWT validation.
- S3 evidence and RDS database storage are encrypted at rest with a customer-managed KMS key with automatic rotation enabled.
- The VPC separates public load-balancer subnets from private application and database subnets; compute and database ingress is security-group constrained.
- ECS task and execution roles have separate, scoped permissions. The application role is limited to the evidence bucket and its KMS key; the execution role reads only the RDS-managed database secret, in addition to the ECS image/log permissions.
- S3 public access is blocked at both the bucket and account-independent bucket settings; bucket versioning and TLS-only access are enforced.
- Database credentials are RDS-managed and encrypted by KMS rather than generated as Terraform values. Production requires Multi-AZ, deletion protection, final snapshots, and backup retention.
- ECS CPU/memory target tracking and CloudWatch alarms cover task count, target 5xx responses, RDS CPU/storage, and unhealthy targets. Configure an SNS topic to receive alarm notifications.

## Repository layout

```text
.
├── README.md
├── .github/
│   └── workflows/
│       └── terraform-ci.yml
├── docs/
│   ├── architecture_decisions.md
│   ├── production_readiness.md
│   └── security_model.md
├── environments/
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── terraform.tfvars.example
│   └── production/
│       ├── main.tf
│       ├── variables.tf
│       └── terraform.tfvars.example
└── modules/
    ├── compute/
    ├── identity/
    ├── networking/
    ├── security/
    └── storage/
```

## Getting started

Use Terraform 1.10 or newer and AWS provider 5.x. Authenticate through your organization's approved AWS SSO or short-lived role-assumption workflow; do not put access keys in Terraform files or variable files.

Before initializing either environment, bootstrap a dedicated state bucket outside these environment stacks. Enable S3 versioning, default encryption with the specified KMS key, public-access blocking, and tightly scoped IAM access. Grant the Terraform role the S3 read/write/delete permissions needed for its state object and `.tflock` object, plus the required KMS permissions. The state bucket and key are security-critical and must not be managed by the same state they contain.

```powershell
Set-Location .\environments\staging
Copy-Item .\terraform.tfvars.example .\terraform.tfvars
Copy-Item .\backend.hcl.example .\backend.hcl
# Edit terraform.tfvars with account-specific values, including a real ACM
# certificate ARN and matching application hostname.
# Edit backend.hcl with the bootstrapped state bucket, region, and KMS key.
terraform init -backend-config=backend.hcl
terraform validate
terraform plan
```

Repeat from `environments/production` for production, using its separate backend configuration and state key. Review and approve any state migration prompt before proceeding. Commit each root's generated `.terraform.lock.hcl` file to pin exact provider selections. Never commit `terraform.tfvars`, populated backend configuration, state files, or saved plans.

The example variables are illustrative only. Replace the sample certificate ARN, hostname, and container image. Review CIDRs, database sizing, alarm thresholds, backup retention, state permissions, and organizational policies before deployment. The application container must listen on the configured container port, implement its own health endpoint, and validate Cognito JWTs using the exported issuer and client ID. DNS hosting and record creation remain external.

## Scope and production readiness

This is an infrastructure reference, not a complete application or compliance certification. The GitHub Actions workflow formats, validates, and scans infrastructure but does not deploy it. Configure SNS alarm delivery, on-call ownership, database restore testing, application authentication, immutable image scanning, and organizational guardrails before launch. Cost and capacity estimates, RTO/RPO, and production acceptance require client traffic assumptions and explicit sign-off; see [production readiness](./docs/production_readiness.md).
