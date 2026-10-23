# Production readiness and deployment gates

This reference does not assert that production is ready. The checklist below separates controls present in Terraform from items that require account-specific configuration, application testing, or business approval.

## Provisioned baseline

- [x] HTTPS listener with HTTP-to-HTTPS redirect; deploy requires a valid regional ACM certificate and matching DNS hostname.
- [x] Cognito user pool and public app client with MFA enabled in production configuration.
- [x] S3 backend examples use encryption and native lock files; the actual state bucket, KMS key, IAM policy, and S3 versioning must be bootstrapped and verified before `terraform init`.
- [x] RDS-managed master credential stored by RDS/Secrets Manager, encrypted with KMS; Terraform no longer generates or stores a plaintext DB password.
- [x] Production RDS configuration requires Multi-AZ, deletion protection, final snapshot, and at least seven backup-retention days.
- [x] ECS target tracking for CPU/memory and CloudWatch alarms for task count, ALB 5xx responses, and database CPU.
- [x] Container Insights and application log retention are configurable.
- [x] CI validates formatting/configuration and runs Checkov on pull requests and main-branch changes.

## Required before production traffic

- [ ] Issue an ACM certificate in the ALB region for the chosen application hostname, populate the deployment variable, and create/verify DNS routing to the ALB. Confirm HTTPS, redirect, and certificate renewal behavior.
- [ ] Integrate the application with Cognito. Validate JWT signature, issuer, audience/client ID, token use, expiry, and required scopes; test MFA and account recovery. Provisioning a pool does not make the application enforce authentication.
- [ ] Bootstrap and independently verify the S3 state bucket: versioning, KMS encryption, public-access block, access logging, lock-file access, bucket policy, and least-privilege role permissions. Terraform state still contains infrastructure metadata and must remain restricted.
- [ ] Replace the demonstration container image with a trusted, immutable image digest. Add build provenance, vulnerability scanning, patching, and deployment approval policies for the actual application image.
- [ ] Replace the RDS master account in application runtime with a dedicated least-privilege database principal. Test the application's credential refresh/reconnect behavior when the RDS-managed master secret rotates.
- [ ] Configure a pre-created SNS topic ARN for alarm delivery, verify subscriptions, and test alarm notifications. WAF and ALB access logging, CloudTrail retention, VPC flow logs, and centralized audit alerting are not fully provisioned here.
- [ ] Validate the application health endpoint and target-group matcher against startup, dependency failures, and graceful shutdown. Test ALB deregistration and ECS rollback behavior.
- [ ] Run a restore exercise from an automated backup/snapshot and document measured recovery results. Production retention is configured, but no restore test or cross-region recovery is provisioned.
- [ ] Review WAF false positives, rate limits, security-group egress, IAM/KMS policies, service quotas, and regional data requirements with the client's security owner.
- [ ] Run `terraform plan` against the real account, review cost and replacement/deletion actions, and require peer approval before applying.

## Recovery and launch decisions (client sign-off required)

| Decision | Required value/evidence | Status |
|---|---|---|
| Recovery point objective (RPO) | Maximum acceptable data loss, with backup/replication design mapped to it | Not defined |
| Recovery time objective (RTO) | Maximum acceptable service recovery time, demonstrated by a restore/failover exercise | Not defined |
| Availability and traffic envelope | Peak/average requests, concurrency, seasonal growth, latency SLO | Not defined |
| Application scaling boundaries | Capacity-test evidence supporting task CPU/memory targets and min/max counts | Defaults are examples |
| Database sizing | Query, storage-growth, connection, IOPS and failover test evidence | Defaults are examples |
| Cost envelope | AWS Pricing Calculator estimate for the selected region, traffic, log retention, NAT, WAF, RDS, ECS, storage, KMS, and data transfer | Not estimated |
| Launch acceptance | Security review, load test, restore test, monitoring/on-call ownership, rollback rehearsal, and business sign-off | Not approved |

Do not treat example thresholds or instance sizes as capacity commitments. Cost varies materially by region, traffic, data transfer, log volume, and database usage; enter those measured assumptions into AWS Pricing Calculator before approval.

## Rollback

The CI workflow validates and scans Terraform but does not deploy. Infrastructure changes must use an approved saved plan and a reviewed forward fix or documented state/data recovery procedure; Terraform rollback is not a substitute for restoring data. Application releases should use an immutable image digest and ECS deployment circuit-breaker/rollback settings after the application health checks and desired minimum capacity are validated.
