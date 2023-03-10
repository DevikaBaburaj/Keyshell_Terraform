provider "aws" {
  region = "us-east-1"
  profile = "default"
}

locals {
  env = "test"
  ingress_rules = [{
    port = 443
    description = "Ingress rules for port 443"
  },
  {
    port = 80
    description = "Ingress rules for port 80"
  }]
}

//VPC

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = title("${local.env}-vpc")

  }
}


//Public subnet

resource "aws_subnet" "public_subnet" {
  count                   = length(var.pub_cidr_block)
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = element(var.pub_cidr_block, count.index)
  map_public_ip_on_launch = true
  availability_zone       = element(var.az, count.index)
  tags = {
    Name = title("${local.env}-public-subnet-1")

  }
}

// PRIVATE SUBNETS

resource "aws_subnet" "private_subnet" {
  count             = length(var.priv_cidr_block)
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = element(var.priv_cidr_block, count.index)
  availability_zone = element(var.az, count.index)
  tags = {
    Name = title("${local.env}-private-subnet-2")

  }
}

// IGW

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = title("${local.env}-igw")

  }
}

// EIP
resource "aws_eip" "nat_eip" {
  count         = var.nat_gateway_count
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
  tags = {
    Name = title("${local.env}-eip")

  }
}

// NAT
resource "aws_nat_gateway" "nat" {
  count         = var.nat_gateway_count
  allocation_id = element(aws_eip.nat_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnet.*.id, count.index)
  depends_on    = [aws_internet_gateway.ig]
  tags = {
    Name = title("${local.env}-nat")
  }
}

// PUBLIC ROUTE
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = title("${local.env}-public-route-table")

  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

// PRIVATE ROUTE
resource "aws_route_table" "private" {
  count  = length(aws_nat_gateway.nat.*.id)
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = title("${local.env}-private-route-table")

  }
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.nat_gateway_count
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.nat.*.id, count.index)
}

// PUBLIC ROUTE TABLE ASSOCIATION
resource "aws_route_table_association" "public_subnet" {
  count          = length(aws_subnet.public_subnet.*.id)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

// PRIVATE ROUTE TABLE ASSOCIATION
resource "aws_route_table_association" "private_subnet" {
  count          = length(aws_subnet.private_subnet.*.id)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

resource "aws_security_group" "main" {
  name = "resource_with_dynamic_block"
  vpc_id = aws_vpc.vpc.id

  dynamic "ingress" {
    for_each = local.ingress_rules
    content {
      description = ingress.value.description
      from_port = ingress.value.port
      to_port = ingress.value.port
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  tags = {
    Name = "aws security group dynamic block"
  }
}
