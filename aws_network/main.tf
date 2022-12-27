#----------------------------------------------------------
# My Terraform
# Provision:
#  - VPC
#  - Internet Gateway
#  - XX Public Subnets
#  - XX Private Subnets
#  - XX NAT Gateways in Public Subnets to give access to Internet from Private Subnets
#
# Made by Anvar
#----------------------------------------------------------

#==============================================================


#---------------------------------------------

data "aws_availability_zones" "available" {

}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-VPC"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "${var.env}-IGW"
  }
}

#------------------Public Subnet and Routing---------------

resource "aws_subnet" "public_subnet" {
  count = length(var.public_subnet_ciders)
  vpc_id = aws_vpc.main.id
  cidr_block = element(var.public_subnet_ciders, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env}-public-${count.index + 1}"
  }
}



resource "aws_route_table" "public_subnets" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = {
    Name = "${var.env}-route-public-subnets"
  }
}

resource "aws_route_table_association" "public_routes" {
  count = length(aws_subnet.public_subnet[*].id)
  route_table_id = aws_route_table.public_subnets.id
  subnet_id = element(aws_subnet.public_subnet[*].id, count.index)
}

#------------NAT GATEWAYS with Elastic IP--------------------

resource "aws_eip" "nat" {
  count = length(var.private_subnet_ciders)
  vpc = true
  tags = {
    Name = "${var.env}-nat-gw-${count.index + 1}"
  }
}

resource "aws_nat_gateway" "nat" {
  count = length(var.private_subnet_ciders)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id = element(aws_subnet.public_subnet[*].id, count.index)
  tags = {
    Name = "${var.env}-nat-gw-${count.index + 1}"
  }
}




#-------------------------

resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_ciders)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_ciders, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  tags = {
    Name = "${var.env}-private-${count.index + 1}"
  }
}

resource "aws_route_table" "private_subnets" {
  count  = length(var.private_subnet_ciders)
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat[count.index].id
  }
  tags = {
    Name = "${var.env}-route-private-subnet-${count.index + 1}"
  }
}

resource "aws_route_table_association" "private_routes" {
  count          = length(aws_subnet.private_subnets[*].id)
  route_table_id = aws_route_table.private_subnets[count.index].id
  subnet_id      = element(aws_subnet.private_subnets[*].id, count.index)
}