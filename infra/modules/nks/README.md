# NKS Module

NCP Kubernetes Service 클러스터와 개발 노드 풀을 생성합니다.

- KVM / Kubernetes 1.34 / Cilium
- Single Zone
- Private 워커 노드
- Public API Endpoint는 허용 CIDR만 접근
- 2 vCPU/8GB/100GB 노드 2대

Network Module의 VPC·Subnet 출력값을 입력으로 사용하며, 실제 생성은 Dev Root Module에서 조합합니다.
