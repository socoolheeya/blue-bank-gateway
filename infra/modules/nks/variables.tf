variable "name_prefix" {
  description = "NKS 리소스 이름의 접두사"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name_prefix))
    error_message = "name_prefix는 영문 소문자로 시작하는 3~20자의 소문자, 숫자, 하이픈이어야 합니다."
  }
}

variable "zone" {
  description = "Single Zone NKS를 생성할 Zone"
  type        = string

  validation {
    condition     = contains(["KR-1", "KR-2", "KR-3"], var.zone)
    error_message = "zone은 KR-1, KR-2, KR-3 중 하나여야 합니다."
  }
}

variable "vpc_no" {
  description = "NKS를 생성할 VPC 번호"
  type        = string
}

variable "worker_subnet_no" {
  description = "NKS 워커 노드용 Private Subnet 번호"
  type        = string
}

variable "lb_private_subnet_no" {
  description = "Private Load Balancer 전용 Subnet 번호"
  type        = string
}

variable "lb_public_subnet_no" {
  description = "Public Load Balancer 전용 Subnet 번호"
  type        = string
}

variable "allowed_api_cidrs" {
  description = "NKS Public API 접근 허용 CIDR"
  type        = set(string)

  validation {
    condition = (
      length(var.allowed_api_cidrs) > 0 &&
      !contains(var.allowed_api_cidrs, "0.0.0.0/0") &&
      alltrue([for cidr in var.allowed_api_cidrs : can(cidrhost(cidr, 0))])
    )
    error_message = "allowed_api_cidrs에는 유효한 CIDR을 하나 이상 입력해야 하며 0.0.0.0/0은 금지됩니다."
  }
}

variable "node_count" {
  description = "개발 노드 풀의 고정 노드 수"
  type        = number
  default     = 2

  validation {
    condition     = var.node_count >= 2 && var.node_count <= 5
    error_message = "개발 노드 수는 2~5 사이여야 합니다."
  }
}

variable "node_storage_size" {
  description = "NKS 노드 기본 스토리지 크기(GB)"
  type        = number
  default     = 100

  validation {
    condition     = var.node_storage_size >= 100 && var.node_storage_size <= 2000
    error_message = "노드 스토리지는 100~2000GB 사이여야 합니다."
  }
}

variable "return_protection" {
  description = "NKS 클러스터 반납 보호 여부"
  type        = bool
  default     = true
}
