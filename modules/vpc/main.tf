# Community module: https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.6.1"

  name = var.name
  cidr = var.cidr

  azs             = var.azs
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets

  enable_nat_gateway   = var.enable_nat_gateway
  single_nat_gateway   = var.single_nat_gateway
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags expected by AWS Load Balancer Controller / EKS
  public_subnet_tags = merge(
    {
      "kubernetes.io/role/elb" = "1"
    },
    var.public_subnet_tags
  )

  private_subnet_tags = merge(
    {
      "kubernetes.io/role/internal-elb" = "1"
    },
    var.private_subnet_tags
  )

  tags = var.tags
}
