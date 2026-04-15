module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "loki-prod-cluster"
  cluster_version = "1.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Public access enabled for local kubectl. Restrict CIDRs via var.eks_public_access_cidrs.
  # SECURITY: Set to your known IPs in production, e.g. ["203.0.113.42/32"]
  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.eks_public_access_cidrs
  cluster_endpoint_private_access      = true

  # Truly Production: Disable lazy creator access, use explicit Access Entries.
  authentication_mode                         = "API"
  enable_cluster_creator_admin_permissions    = false

  access_entries = {
    # Explicitly map our Admin Role to Cluster Admin policy
    cluster_admin = {
      principal_arn     = aws_iam_role.eks_admin_role.arn

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  # IRSA is critical for production security
  enable_irsa = true

  eks_managed_node_groups = {
    # System node group: For CoreDNS, ALB controller, etc.
    # We use On-Demand here for stability of critical core components.
    system = {
      instance_types = ["m6i.large"]
      min_size     = 1
      max_size     = 3
      capacity_type  = "ON_DEMAND"
    }

    # Loki Workers: High-RAM Spot instances to keep compute costs low for 5TB/day.
    # We diversify instance types to ensure Spot availability.
    loki_workers = {
      instance_types = ["r6i.xlarge", "r6a.xlarge", "r5.xlarge"]
      capacity_type  = "SPOT"
      min_size     = 3
      max_size     = 25 # Increased from 15 to handle large Loki footprint
      desired_size = 8  # Increased from 5 to ensure immediate scheduling

      labels = {
        role = "loki-engine"
      }

      taints = [{
        key    = "loki-only"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]

      # Root volume for WAL (Write Ahead Log) - Must be large enough for ingest spikes.
      block_device_mappings = {
        xvda = {
          device_name = "/dev/xvda"
          ebs = {
            volume_size = 100
            volume_type = "gp3"
            iops        = 3000
          }
        }
      }
    }
  }
}
