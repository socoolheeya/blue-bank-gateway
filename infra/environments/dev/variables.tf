variable "region" {
  description = "NCP 리전"
  type        = string
  default     = "KR"

  validation {
    condition     = var.region == "KR"
    error_message = "현재 개발 인프라는 KR 리전만 지원합니다."
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

variable "name_prefix" {
  description = "Dev 인프라 리소스 이름 접두사"
  type        = string
  default     = "blue-bank-dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "worker_subnet_cidr" {
  type    = string
  default = "10.0.10.0/24"
}

variable "lb_private_subnet_cidr" {
  type    = string
  default = "10.0.20.0/24"
}

variable "lb_public_subnet_cidr" {
  type    = string
  default = "10.0.30.0/24"
}

variable "nat_subnet_cidr" {
  type    = string
  default = "10.0.40.0/24"
}

variable "allowed_api_cidrs" {
  description = "Terraform 실행 PC/CI의 공인 CIDR 목록. 단일 IP는 /32 사용"
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

variable "ncr_endpoint" {
  description = "콘솔에서 생성한 NCR Public Endpoint"
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}\\.kr\\.ncr\\.ntruss\\.com$", var.ncr_endpoint))
    error_message = "ncr_endpoint는 <registry>.kr.ncr.ntruss.com 형식이어야 합니다."
  }
}

variable "return_protection" {
  description = "NKS 클러스터 반납 보호 여부"
  type        = bool
  default     = true
}
