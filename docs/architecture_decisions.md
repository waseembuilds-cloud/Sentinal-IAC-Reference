# Architecture decisions

## Two Terraform environments

Staging and production call the same modules so that network and security controls do not drift between phases. Staging uses smaller Fargate tasks and a smaller PostgreSQL instance, with one NAT gateway to reduce fixed network cost. Production uses larger capacity, Multi-AZ RDS, and one NAT gateway per Availability Zone to improve resilience. Values that vary by account or deployment are inputs rather than embedded resource identifiers.

Each environment is a separate Terraform root and therefore has independent state. Both roots use the S3 backend with native lock files. Bootstrap a dedicated state bucket separately with versioning, KMS encryption, public-access blocking, and narrowly scoped access. Keep environment backend details out of source control. Commit the generated provider lock file for each root so provider selections are reproducible.

## Identity: Amazon Cognito

Cognito is the intended user identity provider rather than a bespoke credential store. A managed provider reduces the amount of authentication code the platform must secure and maintain, offers built-in MFA and federation capabilities, and provides service-level security and compliance documentation. Authentication remains outside the assessment and evidence data boundaries. Cognito integration is represented in the architecture but is not provisioned by these Terraform modules.

## Secrets: AWS Secrets Manager

Database credentials should not be placed in source control, Terraform variable files, or plain-text container environment variables. Secrets Manager provides encrypted storage, access auditing through AWS service events, and a supported path to rotation. The database password is generated during provisioning and stored as a Secrets Manager secret; ECS receives the secret through its task definition. Production deployments should add and test a rotation strategy compatible with the application's connection lifecycle.

## WAF in front of the ALB

WAFv2 is associated with the internet-facing ALB, so requests are inspected before reaching application tasks. The managed common and known-bad-input rule groups provide baseline filtering for common exploit patterns such as SQL injection and cross-site scripting, while the rate-based rule limits abusive request bursts. WAF is a defense-in-depth layer, not a replacement for application input validation or upstream DDoS planning.

## Private networking and storage

Only the ALB is placed in public subnets. Fargate tasks and RDS are placed in private subnets and accept traffic only from their immediate upstream security group. Evidence objects use a private, versioned S3 bucket with KMS encryption and TLS-only access. A shared, rotated customer-managed KMS key provides the database and bucket encryption key in this reference; key policy, separation, and recovery controls should be reviewed against the client's data classification and retention requirements.

## Workload identity

The ECS task role is distinct from the ECS execution role. Application code receives only evidence-bucket and KMS permissions. The execution role is used by ECS to pull images, publish logs, retrieve the named database secret, and decrypt that secret. Neither role receives general administrative access.
