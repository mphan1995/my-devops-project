locals {
  name = var.project
}

# Lấy danh sách AZ khả dụng trong region hiện tại
data "aws_availability_zones" "available" {
  state = "available"
}

# Lấy 3 AZ đầu (thường là a,b,c). Nếu region chỉ có 2 AZ thì slice sẽ trả 2.
locals {
  azs         = slice(data.aws_availability_zones.available.names, 0, 3)
  public_map  = { for idx, cidr in var.public_subnets  : idx => cidr }
  private_map = { for idx, cidr in var.private_subnets : idx => cidr }
}

# ------------------------------
# VPC + Subnets + Routing
# ------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags                 = merge(var.tags, { Name = "${local.name}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${local.name}-igw" })
}

# Public subnets
resource "aws_subnet" "public" {
  for_each                = local.public_map
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  map_public_ip_on_launch = true
  availability_zone       = local.azs[tonumber(each.key) % length(local.azs)]
  tags = merge(var.tags, {
    Name = "${local.name}-public-${replace(each.value, ".0/24", "")}"
  })
}

# Private subnets
resource "aws_subnet" "private" {
  for_each          = local.private_map
  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = local.azs[tonumber(each.key) % length(local.azs)]
  tags = merge(var.tags, {
    Name = "${local.name}-private-${replace(each.value, ".0/24", "")}"
  })
}

# NAT Gateway (EIP dùng domain = "vpc")
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = var.tags
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = values(aws_subnet.public)[0].id
  depends_on    = [aws_internet_gateway.igw]
  tags          = merge(var.tags, { Name = "${local.name}-nat" })
}

# Public route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${local.name}-rt-public" })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private route table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${local.name}-rt-private" })
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_route_table_association" "private_assoc" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# ------------------------------
# EKS Cluster (managed node group)
# ------------------------------
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${local.name}-eks"
  cluster_version = "1.29"

  vpc_id     = aws_vpc.main.id
  subnet_ids = [for s in aws_subnet.private : s.id]

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"] # hoặc chỉ IP Jenkins

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = 1
      max_size       = 3
      desired_size   = 1
    }
  }

  enable_irsa = true
  tags        = var.tags
}


# ------------------------------
# ECR repo cho app
# ------------------------------
resource "aws_ecr_repository" "myapp" {
  name                 = "myapp"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  tags = var.tags
}
