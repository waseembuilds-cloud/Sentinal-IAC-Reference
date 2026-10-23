# Security model

## Trust boundaries and request flow

1. Internet traffic reaches the regional AWS WAFv2 web ACL before the public ALB.
2. The ALB forwards traffic to ECS Fargate tasks in private application subnets. The task security group permits the configured application port only from the ALB security group.
3. The application accesses PostgreSQL in private database subnets. The database security group permits the configured database port only from the task security group.
4. The task role accesses the private evidence bucket and the configured KMS key. Bucket policy denies non-TLS requests.
5. ECS uses its separate execution role for ECR image retrieval, CloudWatch Logs delivery, and retrieval/decryption of the configured Secrets Manager database secret.

## Controls implemented

- Private application and database subnets, with public subnets reserved for the ALB and NAT gateways.
- Security groups that restrict application ingress to the ALB and database ingress to the application tasks.
- AWS-managed WAF common and known-bad-input rule groups and a rate-based rule.
- KMS customer-managed key with automatic rotation for RDS and S3.
- S3 bucket encryption, versioning, full public-access blocking, and a TLS-only bucket policy.
- Generated database password stored as a Secrets Manager secret and injected into the task as a secret reference.
- Separate ECS task and task-execution roles with scoped policies.

## Operational requirements before production

- Add an ACM certificate and HTTPS-only ALB listener, then redirect or reject plaintext HTTP.
- Bootstrap a dedicated S3 state bucket with versioning, KMS encryption, public-access blocking, access logging, native lock-file permissions, and narrowly scoped access.
- Define CloudTrail, WAF, ALB, VPC flow, application, and database audit log retention and alerting.
- Configure database backups, deletion protection, maintenance windows, recovery objectives, and restore tests.
- Add secret rotation and operationally test application reconnection behavior.
- Define container image provenance, scanning, deployment approvals, rollback, and supply-chain controls.
- Review WAF rules and rate limits against real application behavior and add alarms for blocked/allowed traffic.
- Validate quotas, CIDRs, encryption key administration, data residency, and organizational policies.

This reference does not itself establish compliance or guarantee application-level security.
