output "vpc_no" {
  description = "생성한 VPC 번호"
  value       = ncloud_vpc.this.id
}

output "worker_subnet_no" {
  description = "NKS 워커 노드 Subnet 번호"
  value       = ncloud_subnet.worker.id
}

output "lb_private_subnet_no" {
  description = "Private Load Balancer 전용 Subnet 번호"
  value       = ncloud_subnet.lb_private.id
}

output "lb_public_subnet_no" {
  description = "Public Load Balancer 전용 Subnet 번호"
  value       = ncloud_subnet.lb_public.id
}

output "nat_gateway_no" {
  description = "NAT Gateway 번호"
  value       = ncloud_nat_gateway.this.id
}

output "nat_public_ip" {
  description = "NAT Gateway Public IP"
  value       = ncloud_nat_gateway.this.public_ip
}
