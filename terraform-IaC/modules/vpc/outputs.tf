output "vpc_id" {
  description = "The ID of the created VPC."
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC."
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "List of Availability Zones used by the subnets."
  value       = var.availability_zones
}

output "public_route_table_id" {
  description = "The ID of the public route table."
  value       = aws_route_table.public.id
}

# Output the correct private route table IDs based on the NAT configuration
output "private_route_table_ids" {
  description = "List of IDs of the private route tables (one per AZ if multi-NAT, one if single-NAT or no-NAT)."
  value = var.enable_nat_gateway ? (
    var.single_nat_gateway ? aws_route_table.private_single_nat[*].id : aws_route_table.private_multi_nat[*].id
  ) : aws_route_table.private_no_nat[*].id
}

output "nat_gateway_public_ips" {
  description = "List of public IP addresses assigned to the NAT Gateway(s), if created."
  value       = aws_eip.nat[*].public_ip
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway."
  value       = aws_internet_gateway.gw.id
}


