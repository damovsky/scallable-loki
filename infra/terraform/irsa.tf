# IAM Roles for Service Accounts (IRSA)
# This module maps a Kubernetes ServiceAccount to an AWS IAM Role.

module "loki_s3_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name = "loki-s3-access-role"

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["logging:loki"] # Adjust namespace if needed
    }
  }

  role_policy_arns = {
    s3 = aws_iam_policy.loki_s3_access.arn
  }
}

output "loki_irsa_role_arn" {
  value = module.loki_s3_irsa.iam_role_arn
}
