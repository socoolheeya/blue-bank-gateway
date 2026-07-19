data "ncloud_nks_versions" "selected" {
  hypervisor_code = "KVM"

  filter {
    name   = "value"
    values = ["1.34"]
    regex  = true
  }
}

data "ncloud_nks_server_images" "ubuntu" {
  hypervisor_code = "KVM"

  filter {
    name   = "label"
    values = ["ubuntu-22.04"]
    regex  = true
  }
}

data "ncloud_nks_server_products" "standard_2c_8g" {
  software_code = data.ncloud_nks_server_images.ubuntu.images[0].value
  zone          = var.zone

  filter {
    name   = "product_type"
    values = ["STAND"]
  }
  filter {
    name   = "cpu_count"
    values = ["2"]
  }
  filter {
    name   = "memory_size"
    values = ["8GB"]
  }
}

resource "ncloud_login_key" "nks" {
  key_name = "${var.name_prefix}-nks-key"
}

resource "ncloud_nks_cluster" "this" {
  hypervisor_code      = "KVM"
  cluster_type         = "SVR.VNKS.STAND.C004.M016.G003"
  k8s_version          = data.ncloud_nks_versions.selected.versions[0].value
  login_key_name       = ncloud_login_key.nks.key_name
  name                 = "${var.name_prefix}-nks"
  zone                 = var.zone
  vpc_no               = var.vpc_no
  subnet_no_list       = [var.worker_subnet_no]
  lb_private_subnet_no = var.lb_private_subnet_no
  lb_public_subnet_no  = var.lb_public_subnet_no
  public_network       = false
  kube_network_plugin  = "cilium"
  return_protection    = var.return_protection

  ip_acl_default_action = "deny"
  dynamic "ip_acl" {
    for_each = var.allowed_api_cidrs
    content {
      action  = "allow"
      address = ip_acl.value
      comment = "Terraform-managed NKS API access"
    }
  }

  lifecycle {
    precondition {
      condition     = length(data.ncloud_nks_versions.selected.versions) == 1
      error_message = "KVM용 Kubernetes 1.34 버전을 정확히 하나 조회해야 합니다."
    }
  }
}

resource "ncloud_nks_node_pool" "default" {
  cluster_uuid     = ncloud_nks_cluster.this.uuid
  node_pool_name   = "${var.name_prefix}-default"
  node_count       = var.node_count
  software_code    = data.ncloud_nks_server_images.ubuntu.images[0].value
  server_spec_code = data.ncloud_nks_server_products.standard_2c_8g.products[0].value
  storage_size     = var.node_storage_size
  subnet_no_list   = [var.worker_subnet_no]

  autoscale {
    enabled = false
    min     = var.node_count
    max     = var.node_count
  }

  lifecycle {
    precondition {
      condition     = length(data.ncloud_nks_server_products.standard_2c_8g.products) > 0
      error_message = "선택 Zone에서 2 vCPU/8GB NKS 서버 상품을 찾지 못했습니다."
    }
  }
}
