variable "name_prefix" {
  description = "모든 네트워크 리소스 이름의 접두사"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.name_prefix))
    error_message = "name_prefix는 영문 소문자로 시작하는 3~20자의 소문자, 숫자, 하이픈이어야 합니다."
  }
}

variable "zone" {
  description = "Single Zone NKS를 생성할 Zone"
  type        = string
  default     = "KR-1"

  validation {
    condition     = contains(["KR-1", "KR-2", "KR-3"], var.zone)
    error_message = "zone은 KR-1, KR-2, KR-3 중 하나여야 합니다."
  }
}

variable "vpc_cidr" {
  description = "개발 VPC CIDR"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr는 유효한 IPv4 CIDR이어야 합니다."
  }
}

variable "worker_subnet_cidr" {
  description = "NKS 워커 노드용 Private Subnet CIDR"
  type        = string
  default     = "10.0.10.0/24"

  validation {
    condition     = can(cidrhost(var.worker_subnet_cidr, 0))
    error_message = "worker_subnet_cidr는 유효한 IPv4 CIDR이어야 합니다."
  }
}

variable "lb_private_subnet_cidr" {
  description = "내부 Load Balancer 전용 Private Subnet CIDR"
  type        = string
  default     = "10.0.20.0/24"

  validation {
    condition     = can(cidrhost(var.lb_private_subnet_cidr, 0))
    error_message = "lb_private_subnet_cidr는 유효한 IPv4 CIDR이어야 합니다."
  }
}

variable "lb_public_subnet_cidr" {
  description = "외부 Load Balancer 전용 Public Subnet CIDR"
  type        = string
  default     = "10.0.30.0/24"

  validation {
    condition     = can(cidrhost(var.lb_public_subnet_cidr, 0))
    error_message = "lb_public_subnet_cidr는 유효한 IPv4 CIDR이어야 합니다."
  }
}

variable "nat_subnet_cidr" {
  description = "NAT Gateway 전용 Public Subnet CIDR"
  type        = string
  default     = "10.0.40.0/24"

  validation {
    condition     = can(cidrhost(var.nat_subnet_cidr, 0))
    error_message = "nat_subnet_cidr는 유효한 IPv4 CIDR이어야 합니다."
  }
}
