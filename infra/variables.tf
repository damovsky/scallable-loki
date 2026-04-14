variable "aws_profile" {
  description = "AWS CLI profile name to use for authentication"
  type        = string
  # Set via TF_VAR_aws_profile env var or terraform.tfvars — no default to avoid accidental leaks
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
}

variable "admin_sso_role_arn" {
  description = <<-EOT
    ARN of the SSO/IAM role allowed to assume LokiEKSAdminRole.
    Restrict this to your specific SSO role rather than the account root.
    Example: "arn:aws:iam::123456789012:role/aws-reserved/sso.amazonaws.com/AWSReservedSSO_AWSAdministratorAccess_xxxx"
  EOT
  type        = string
}

variable "eks_public_access_cidrs" {
  description = <<-EOT
    List of CIDRs allowed to reach the EKS public API endpoint.
    SECURITY: Restrict to your known IPs in production.
    Example: ["203.0.113.42/32"]
    Default allows all — tighten before production use.
  EOT
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
