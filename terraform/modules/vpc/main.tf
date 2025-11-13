data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    {
      Name = "${var.name_prefix}-vpc"
    },
    var.tags
  )
}

resource "aws_subnet" "public" {
  count = var.num_azs

  availability_zone       = data.aws_availability_zones.available.names[count.index]
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true

  tags = merge(
    {
      Name = "${var.name_prefix}-public-subnet-${data.aws_availability_zones.available.names[count.index]}"
      Type = "public"
    },
    var.tags
  )
}

resource "aws_subnet" "private" {
  count = var.num_azs

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + var.num_azs)
  vpc_id            = aws_vpc.main.id

  tags = merge(
    {
      Name = "${var.name_prefix}-private-subnet-${data.aws_availability_zones.available.names[count.index]}"
      Type = "private"
    },
    var.tags
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    {
      Name = "${var.name_prefix}-igw"
    },
    var.tags
  )
}

resource "aws_eip" "nat" {
  count  = var.num_azs
  domain = "vpc"

  tags = merge(
    {
      Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}

resource "aws_nat_gateway" "main" {
  count = var.num_azs

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(
    {
      Name = "${var.name_prefix}-nat-${count.index + 1}"
    },
    var.tags
  )

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    {
      Name = "${var.name_prefix}-public-rt"
    },
    var.tags
  )
}

resource "aws_route_table_association" "public" {
  count = var.num_azs

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = var.num_azs

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[count.index].id
  }

  tags = merge(
    {
      Name = "${var.name_prefix}-private-rt-${count.index + 1}"
    },
    var.tags
  )
}

resource "aws_route_table_association" "private" {
  count = var.num_azs

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
