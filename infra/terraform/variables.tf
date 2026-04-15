variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "eu-central-1"
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
