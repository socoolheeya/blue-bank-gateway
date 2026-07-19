output "vpc_no" {
  description = "개발 VPC 번호"
  value       = module.network.vpc_no
}

output "worker_subnet_no" {
  description = "개발 NKS 워커 Subnet 번호"
  value       = module.network.worker_subnet_no
}

output "nat_public_ip" {
  description = "NAT Gateway Public IP"
  value       = module.network.nat_public_ip
}

output "cluster_uuid" {
  description = "개발 NKS 클러스터 UUID"
  value       = module.nks.cluster_uuid
}

output "cluster_endpoint" {
  description = "개발 NKS Control Plane Endpoint"
  value       = module.nks.cluster_endpoint
}

output "node_pool_name" {
  description = "개발 NKS 기본 노드 풀 이름"
  value       = module.nks.node_pool_name
}

output "ncr_endpoint" {
  description = "Gateway 이미지를 저장할 NCR Public Endpoint"
  value       = var.ncr_endpoint
}
