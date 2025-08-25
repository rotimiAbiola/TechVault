# Cost-optimized VPC with NAT Instance instead of NAT Gateway
# This can save ~$35/month compared to NAT Gateway

# Data source for NAT Instance AMI - Using Amazon Linux 2
data "aws_ami" "nat_instance" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for NAT Instance
resource "aws_security_group" "nat_instance" {
  count       = var.use_nat_instance ? 1 : 0
  name        = "${var.project_name}-${var.environment}-nat-instance"
  description = "Security group for NAT instance"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict this to your IP for security
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-instance-sg"
  })
}

# NAT Instance (Cost-optimized alternative to NAT Gateway)
resource "aws_instance" "nat_instance" {
  count                   = var.use_nat_instance ? 1 : 0
  ami                     = data.aws_ami.nat_instance.id
  instance_type           = "t3.nano"  # Cheapest instance type
  key_name               = var.key_pair_name  # Optional: for SSH access
  vpc_security_group_ids = [aws_security_group.nat_instance[0].id]
  subnet_id              = aws_subnet.public[0].id
  source_dest_check      = false

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-instance"
  })
}

# Elastic IP for NAT Instance
resource "aws_eip" "nat_instance" {
  count    = var.use_nat_instance ? 1 : 0
  instance = aws_instance.nat_instance[0].id
  domain   = "vpc"

  tags = merge(var.common_tags, {
    Name = "${var.project_name}-${var.environment}-nat-instance-eip"
  })

  depends_on = [aws_internet_gateway.main]
}

# Route for NAT Instance
resource "aws_route" "private_nat_instance" {
  count                  = var.use_nat_instance ? length(var.private_subnet_cidrs) : 0
  route_table_id         = aws_route_table.private_nat_instance[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat_instance[0].primary_network_interface_id
}
