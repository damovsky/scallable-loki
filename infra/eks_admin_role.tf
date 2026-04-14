# Dedicated IAM Role for EKS Cluster Administration
# This follows the principle of Least Privilege by separating the SSO identity from Cluster Admin rights.

resource "aws_iam_role" "eks_admin_role" {
  name = "LokiEKSAdminRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          # Restrict to a specific SSO role, not the entire account root.
          # Set var.admin_sso_role_arn in terraform.tfvars or via TF_VAR_admin_sso_role_arn.
          AWS = var.admin_sso_role_arn
        }
      }
    ]
  })

  tags = {
    Role = "Admin"
    Component = "Loki-EKS"
  }
}

# Attach minimal EKS viewing permissions to the role so it can interact with the API
resource "aws_iam_role_policy_attachment" "eks_admin_read" {
  role       = aws_iam_role.eks_admin_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Explicit permissions for the AWS CLI to discover and "handshake" with the cluster
resource "aws_iam_role_policy" "eks_admin_cli_access" {
  name = "EKSAdminCLIAccess"
  role = aws_iam_role.eks_admin_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}
