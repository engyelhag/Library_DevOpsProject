locals {
  num_azs = length(var.availability_zones)
  common_tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-igw"
  })
}

# --- Public Subnets ---
resource "aws_subnet" "public" {
  count                   = local.num_azs
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr_blocks[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true # Instances launched here get public IPs by default

  tags = merge(local.common_tags, {
    Name                     = "${var.project_name}-${var.environment}-public-subnet-${var.availability_zones[count.index]}"
    "kubernetes.io/role/elb" = "1" # Required for AWS Load Balancer Controller auto-discovery
  })
}

# --- Public Route Table ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count          = local.num_azs
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- NAT Gateway(s) - Optional ---
resource "aws_eip" "nat" {
  # Create EIPs only if NAT Gateway is enabled
  # Create one EIP if single_nat_gateway is true, otherwise one per AZ
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.num_azs) : 0
  domain = "vpc" # Changed from `vpc = true` to `domain = "vpc"` for newer provider versions

  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway ? "${var.project_name}-${var.environment}-nat-eip" : "${var.project_name}-${var.environment}-nat-eip-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.gw] # Ensure IGW exists before creating EIP
}

resource "aws_nat_gateway" "nat" {
  # Create NAT Gateways only if NAT Gateway is enabled
  # Create one NGW if single_nat_gateway is true, otherwise one per AZ
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : local.num_azs) : 0
  allocation_id = aws_eip.nat[count.index].id
  # Place NAT GW in the corresponding public subnet
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(local.common_tags, {
    Name = var.single_nat_gateway ? "${var.project_name}-${var.environment}-nat-gw" : "${var.project_name}-${var.environment}-nat-gw-${var.availability_zones[count.index]}"
  })

  depends_on = [aws_internet_gateway.gw] # Explicit dependency
}

# --- Private Subnets ---
resource "aws_subnet" "private" {
  count             = local.num_azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidr_blocks[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = merge(local.common_tags, {
    Name                                = "${var.project_name}-${var.environment}-private-subnet-${var.availability_zones[count.index]}"
    "kubernetes.io/role/internal-elb"   = "1" # Required for internal LBs and AWS Load Balancer Controller
    "kubernetes.io/cluster/${var.project_name}-${var.environment}" = "owned" # Often used by EKS for resource discovery
  })
}

# --- Private Route Table(s) ---

# Option 1: Single NAT Gateway -> Single Private Route Table
resource "aws_route_table" "private_single_nat" {
  count = var.enable_nat_gateway && var.single_nat_gateway ? 1 : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-single-nat"
  })
}

resource "aws_route" "private_single_nat_route" {
  count = var.enable_nat_gateway && var.single_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private_single_nat[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}

resource "aws_route_table_association" "private_single_nat" {
  count = var.enable_nat_gateway && var.single_nat_gateway ? local.num_azs : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_single_nat[0].id
}


# Option 2: One NAT Gateway per AZ -> One Private Route Table per AZ
resource "aws_route_table" "private_multi_nat" {
  count = var.enable_nat_gateway && !var.single_nat_gateway ? local.num_azs : 0

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-${var.availability_zones[count.index]}"
  })
}

resource "aws_route" "private_multi_nat_route" {
  count = var.enable_nat_gateway && !var.single_nat_gateway ? local.num_azs : 0

  route_table_id         = aws_route_table.private_multi_nat[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[count.index].id
}

resource "aws_route_table_association" "private_multi_nat" {
  count = var.enable_nat_gateway && !var.single_nat_gateway ? local.num_azs : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_multi_nat[count.index].id
}

# Option 3: No NAT Gateway -> Private Route Table(s) with no default route (optional, depends on need)
# If you need private subnets with *no* internet access, you'd create route tables similar to above
# but without the aws_route resource pointing to a NAT gateway. For simplicity,
# if enable_nat_gateway is false, private subnets will currently use the main VPC route table
# which only has local routes unless explicitly associated elsewhere. We'll associate them
# with specific tables lacking internet routes if NAT is disabled.

resource "aws_route_table" "private_no_nat" {
  count = !var.enable_nat_gateway ? 1 : 0 # Create one common route table for all private subnets if no NAT

  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-private-rt-no-internet"
  })
}

resource "aws_route_table_association" "private_no_nat" {
  count = !var.enable_nat_gateway ? local.num_azs : 0

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_no_nat[0].id
}