resource "ncloud_vpc" "this" {
  name            = "${var.name_prefix}-vpc"
  ipv4_cidr_block = var.vpc_cidr
}

resource "ncloud_network_acl" "nks" {
  vpc_no      = ncloud_vpc.this.id
  name        = "${var.name_prefix}-nks-nacl"
  description = "NACL for Blue Bank NKS subnets"
}

# NCP Provider는 하나의 NACL에 여러 rule 리소스를 적용하면 기존 규칙을
# 덮어쓸 수 있으므로 모든 규칙을 단일 리소스에서 관리한다.
resource "ncloud_network_acl_rule" "nks" {
  network_acl_no = ncloud_network_acl.nks.id

  inbound {
    priority    = 100
    protocol    = "TCP"
    rule_action = "ALLOW"
    ip_block    = var.vpc_cidr
    port_range  = "1-65535"
  }
  inbound {
    priority    = 110
    protocol    = "UDP"
    rule_action = "ALLOW"
    ip_block    = var.vpc_cidr
    port_range  = "1-65535"
  }
  inbound {
    priority    = 120
    protocol    = "ICMP"
    rule_action = "ALLOW"
    ip_block    = var.vpc_cidr
  }
  inbound {
    priority    = 130
    protocol    = "TCP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "80"
  }
  inbound {
    priority    = 140
    protocol    = "TCP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "1024-65535"
  }
  inbound {
    priority    = 150
    protocol    = "UDP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "1024-65535"
  }

  outbound {
    priority    = 100
    protocol    = "TCP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "1-65535"
  }
  outbound {
    priority    = 110
    protocol    = "UDP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
    port_range  = "1-65535"
  }
  outbound {
    priority    = 120
    protocol    = "ICMP"
    rule_action = "ALLOW"
    ip_block    = "0.0.0.0/0"
  }
}

resource "ncloud_subnet" "worker" {
  vpc_no         = ncloud_vpc.this.id
  subnet         = var.worker_subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_network_acl.nks.id
  subnet_type    = "PRIVATE"
  name           = "${var.name_prefix}-worker-sbn"
  usage_type     = "GEN"
}

resource "ncloud_subnet" "lb_private" {
  vpc_no         = ncloud_vpc.this.id
  subnet         = var.lb_private_subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_network_acl.nks.id
  subnet_type    = "PRIVATE"
  name           = "${var.name_prefix}-lb-private-sbn"
  usage_type     = "LOADB"
}

resource "ncloud_subnet" "lb_public" {
  vpc_no         = ncloud_vpc.this.id
  subnet         = var.lb_public_subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_network_acl.nks.id
  subnet_type    = "PUBLIC"
  name           = "${var.name_prefix}-lb-public-sbn"
  usage_type     = "LOADB"
}

resource "ncloud_subnet" "nat" {
  vpc_no         = ncloud_vpc.this.id
  subnet         = var.nat_subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_network_acl.nks.id
  subnet_type    = "PUBLIC"
  name           = "${var.name_prefix}-nat-sbn"
  usage_type     = "NATGW"
}

resource "ncloud_nat_gateway" "this" {
  vpc_no      = ncloud_vpc.this.id
  subnet_no   = ncloud_subnet.nat.id
  zone        = var.zone
  name        = "${var.name_prefix}-natgw"
  description = "Outbound internet for private NKS workers"
}

resource "ncloud_route_table" "worker" {
  vpc_no                = ncloud_vpc.this.id
  supported_subnet_type = "PRIVATE"
  name                  = "${var.name_prefix}-worker-rt"
  description           = "Private NKS worker routes"
}

resource "ncloud_route_table_association" "worker" {
  route_table_no = ncloud_route_table.worker.id
  subnet_no      = ncloud_subnet.worker.id
}

resource "ncloud_route" "worker_default" {
  route_table_no         = ncloud_route_table.worker.id
  destination_cidr_block = "0.0.0.0/0"
  target_type            = "NATGW"
  target_name            = ncloud_nat_gateway.this.name
  target_no              = ncloud_nat_gateway.this.id
}
