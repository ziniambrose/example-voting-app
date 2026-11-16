# The capstone brief asks for the cluster in the AWS default VPC.
# This starter uses the existing default VPC and its subnets rather than creating a new VPC.
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_vpc" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Help AWS Load Balancer Controller / service load-balancer discovery identify
# the default-VPC subnets as suitable for internet-facing load balancers.
# This adds tags to existing default subnets; it does not create new subnets.
resource "aws_ec2_tag" "elb_subnet_role" {
  for_each    = toset(data.aws_subnets.default_vpc.ids)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.37.1"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  cluster_endpoint_public_access = true
  # Learning default: restrict this to your own public IP before using beyond a short lab.
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default_vpc.ids

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    default = {
      name           = "${var.cluster_name}-nodes"
      instance_types = ["t3.medium"]
      min_size       = 1
      max_size       = 2
      desired_size   = 2
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Project     = "voting-app-capstone"
    Environment = "learning"
  }

  depends_on = [aws_ec2_tag.elb_subnet_role]
}
