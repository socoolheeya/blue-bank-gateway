module "network" {
  source = "../../modules/network"

  name_prefix            = var.name_prefix
  zone                   = var.zone
  vpc_cidr               = var.vpc_cidr
  worker_subnet_cidr     = var.worker_subnet_cidr
  lb_private_subnet_cidr = var.lb_private_subnet_cidr
  lb_public_subnet_cidr  = var.lb_public_subnet_cidr
  nat_subnet_cidr        = var.nat_subnet_cidr
}

module "nks" {
  source = "../../modules/nks"

  name_prefix          = var.name_prefix
  zone                 = var.zone
  vpc_no               = module.network.vpc_no
  worker_subnet_no     = module.network.worker_subnet_no
  lb_private_subnet_no = module.network.lb_private_subnet_no
  lb_public_subnet_no  = module.network.lb_public_subnet_no
  allowed_api_cidrs    = var.allowed_api_cidrs
  node_count           = 2
  node_storage_size    = 100
  return_protection    = var.return_protection
}
