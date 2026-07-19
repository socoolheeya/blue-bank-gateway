output "cluster_uuid" {
  description = "NKS 클러스터 UUID"
  value       = ncloud_nks_cluster.this.uuid
}

output "cluster_endpoint" {
  description = "NKS Control Plane API Endpoint"
  value       = ncloud_nks_cluster.this.endpoint
}

output "node_pool_name" {
  description = "기본 NKS 노드 풀 이름"
  value       = ncloud_nks_node_pool.default.node_pool_name
}

output "node_instance_numbers" {
  description = "기본 노드 풀 인스턴스 번호 목록"
  value       = ncloud_nks_node_pool.default.instance_no
}
