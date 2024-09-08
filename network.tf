resource "aws_vpc" "main" {
  cidr_block           = var.vpccidr
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc_name
  }
}

resource "aws_subnet" "public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  cidr_block              = element(var.public_subnet_cidrs, count.index)
  vpc_id                  = aws_vpc.main.id
  availability_zone       = element(var.azs, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name                     = "Public Subnet ${count.index + 1} for EKS"
    "karpenter.sh/discovery" = var.cluster_name
    environment              = "prod"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  vpc_id            = aws_vpc.main.id
  availability_zone = element(var.azs, count.index)

  tags = {
    Name                     = "Private Subnet ${count.index + 1} for EKS"
    "karpenter.sh/discovery" = var.cluster_name
    environment              = "dev"
  }
}

resource "aws_route_table" "public_subnet_route_table" {
  count  = length(var.public_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }

  tags = {
    Name = "Public subnets route table"
  }
}

resource "aws_route_table_association" "public_subnet" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id = element(aws_route_table.public_subnet_route_table[*].id, count.index)
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "Internet Gateway for VPC ${var.vpc_name}"
  }
}

resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)
  domain = "vpc"
}

resource "aws_nat_gateway" "natgw" {
  count         = length(var.public_subnet_cidrs)
  allocation_id = element(aws_eip.nat[*].id, count.index)
  subnet_id     = element(aws_subnet.public_subnets[*].id, count.index)

  tags = {
    Name = "NAT GW ${count.index + 1} for EKS"
  }

  depends_on = [aws_internet_gateway.gateway]
}

resource "aws_route_table" "private_subnet_route_table" {
  count  = length(var.private_subnet_cidrs)
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = element(aws_nat_gateway.natgw[*].id, count.index)
  }
  depends_on = [aws_nat_gateway.natgw]
}

resource "aws_route_table_association" "private_subnet" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id = element(aws_route_table.private_subnet_route_table[*].id, count.index)
}