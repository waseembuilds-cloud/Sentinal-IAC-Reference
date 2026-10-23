# Security model

## Trust boundaries and request flow

1. Internet traffic reaches the regional AWS WAFv2 web ACL before the public ALB. HTTP is redirected to HTTPS, using an ACM certificate and an externally managed DNS hostname.
2. The ALB forwards TLS-terminated traffic to ECS Fargate tasks in private application subnets. The task security group permits the configured application port only from the ALB security group.
3. The application accesses PostgreSQL in private database subnets. The database security group permits the configured database port only from the task security group.
4. The task role accesses the private evidence bucket and the configured KMS key. Bucket policy denies non-TLS requests.
5. ECS uses its separate execution role for ECR image retrieval, CloudWatch Logs delivery, and retrieval/decryption of the RDS-managed master secret. The application must validate Cognito JWTs using the exported issuer/client configuration.

## Controls implemented

- Private application and database subnets, with public subnets reserved for the ALB and NAT gateways.
- Security groups that restrict application ingress to the ALB and database ingress to the application tasks.
- AWS-managed WAF common and known-bad-input rule groups and a rate-based rule.
- HTTPS-only application traffic after an HTTP redirect; WAF request logs redact authorization and cookie headers.
- Cognito user pool with production MFA enabled and deletion protection.
- KMS customer-managed key with automatic rotation for RDS and S3.
- S3 bucket encryption, versioning, full public-access blocking, and a TLS-only bucket policy.
- RDS-managed master password encrypted in Secrets Manager and injected into the task by secret reference; the password is not generated in Terraform.
- Separate ECS task and task-execution roles with scoped policies.
- Production RDS Multi-AZ, deletion protection, final snapshot, and configured automated backup retention.
- ECS target tracking and CloudWatch alarms for task availability, ALB target errors, database CPU/storage, and unhealthy load-balancer targets.

## Operational requirements before production

- Bootstrap a dedicated S3 state bucket with versioning, KMS encryption, public-access blocking, access logging, native lock-file permissions, and narrowly scoped access.
- Confirm the application validates Cognito JWT signature, issuer, audience, token use, expiry, and scopes.
- Replace the RDS master credential with a dedicated least-privilege application DB role and verify managed rotation/reconnection behavior.
- Define CloudTrail, WAF, ALB, VPC flow, application, and database audit log retention and alerting.
- Verify database backups and deletion protection, define recovery objectives, and perform restore/failover tests.
- Configure and test SNS notification delivery for CloudWatch alarms.
- Define container image provenance, scanning, deployment approvals, rollback, and supply-chain controls.
- Review WAF rules and rate limits against real application behavior and add alarms for blocked/allowed traffic.
- Validate quotas, CIDRs, encryption key administration, data residency, and organizational policies.

This reference does not itself establish compliance or guarantee application-level security.
