# NCP NKS Terraform infrastructure design

## Goal

Provision a reproducible development foundation for Blue Bank on Naver Cloud Platform using Terraform. The foundation must support the existing NKS, Envoy Gateway, Argo CD, Spring Cloud Gateway, and Redis deployment without restoring Eureka or Nginx.

## Fixed decisions

- Cloud and region: Naver Cloud Platform, Korea (`KR`)
- Environment: development only in this implementation; production reuses modules later
- Availability: single zone for development
- Kubernetes: NKS 1.34 on KVM with Cilium
- Worker network: private subnet with outbound access through a NAT Gateway
- Node pool: two nodes, 2 vCPU, 8 GB memory, 100 GB root storage, autoscaling disabled
- Kubernetes API: public endpoint, default deny, explicitly allowed `/32` CIDRs
- Image registry: Naver Cloud Container Registry (NCR)
- Terraform state: NCP Object Storage remote backend
- Workload deployment: Argo CD GitOps; Terraform does not own application manifests
- Development ingress: public NCP Load Balancer IP and HTTP until a domain and TLS are introduced

## Scope and ownership

Terraform owns NCP infrastructure:

- VPC, subnets, route tables, routes, NAT Gateway, and network ACL rules
- NKS cluster and node pool
- NCR resources supported by the NCP provider
- Outputs needed to connect CI, operators, and bootstrap scripts

Argo CD owns Kubernetes platform and workload resources after the cluster is reachable:

- Envoy Gateway v1.8.2 and Gateway API resources
- Spring Cloud Gateway
- Development Redis StatefulSet and persistent volume
- Future account, deposit, loan, and card workloads

NCP access credentials, Kubernetes Secrets, kubeconfig, and application credentials remain outside Terraform source and Git. Terraform state contains infrastructure metadata and is stored remotely, but it is still treated as sensitive.

## Repository layout

```text
infra/
  modules/
    network/
    nks/
    registry/
  environments/
    dev/
      backend.tf
      main.tf
      providers.tf
      variables.tf
      outputs.tf
      terraform.tfvars.example
      backend.hcl.example
  scripts/
    bootstrap-argocd.sh
    verify-dev.sh
```

Shared modules provide narrow interfaces and contain no environment-specific credentials. The `dev` root module supplies development CIDRs, capacity, naming, and API access rules. A future `prod` root can reuse the modules without copying resource definitions.

## Network design

The development VPC uses the following non-overlapping address plan:

| Purpose | Type | CIDR |
| --- | --- | --- |
| VPC | Private address space | `10.0.0.0/16` |
| NKS workers | Private general subnet | `10.0.10.0/24` |
| Private load balancers | Private load-balancer subnet | `10.0.20.0/24` |
| Public load balancers | Public load-balancer subnet | `10.0.30.0/24` |
| NAT Gateway | Public general subnet | `10.0.40.0/24` |

The worker subnet has a `0.0.0.0/0` route to the NAT Gateway. Worker nodes receive no public IP. NKS uses the dedicated load-balancer subnets, and Envoy Gateway obtains an NCP public Load Balancer for north-south traffic. Network ACL rules permit required intra-VPC traffic, established return traffic, DNS, and outbound HTTPS while avoiding unrestricted inbound access to worker nodes.

## NKS design

The NKS cluster uses KVM, Kubernetes 1.34, Cilium, the private worker subnet, and both dedicated load-balancer subnets. The control-plane API remains public for developer access, but its default ACL action is `deny`. The root module requires at least one explicit CIDR in `allowed_api_cidrs`; individual developer or CI addresses use `/32` entries.

The development node pool contains two 2-vCPU/8-GB nodes with 100-GB root disks. Two nodes allow rolling updates and basic node-failure testing while limiting development cost. Autoscaling is initially disabled so cost is predictable. Cluster and node-pool deletion protection is enabled where the provider exposes it; teardown documentation requires an intentional protection change before destroy.

## Registry design

The registry module creates or declares the NCR infrastructure available through the current NCP Terraform provider and exports the registry endpoint. CI builds the Gateway image, pushes an immutable tag, and commits the corresponding Kustomize image change. Argo CD never builds images.

If NCR creation requires an account-level prerequisite not representable by the provider, the module accepts the existing registry identifier or endpoint as an input and documents the one-time console prerequisite. It must not silently create a second registry.

## State and credentials

The Object Storage bucket for Terraform state is a bootstrap prerequisite and is not managed by the state it stores. It is created once through the NCP console with versioning and restricted access. `backend.hcl` supplies the bucket, object key, region, S3-compatible endpoint, and backend authentication settings required by the installed Terraform version.

NCP provider credentials are read from supported environment variables. They are never Terraform variables with committed defaults. These files are ignored:

- `terraform.tfvars`
- `backend.hcl`
- `.terraform/`
- Terraform state and plan files
- kubeconfig files

Example files contain non-secret placeholders and document each required value.

## Provisioning and GitOps flow

1. Create the state bucket once and prepare `backend.hcl` from its example.
2. Export NCP credentials and prepare `terraform.tfvars`, including the operator's public `/32` CIDR.
3. Run `terraform init`, `terraform fmt -check`, `terraform validate`, `terraform plan`, and `terraform apply` from `infra/environments/dev`.
4. Obtain kubeconfig using the NCP CLI and the cluster UUID output.
5. Run the Argo CD bootstrap script against the explicit kubeconfig/context.
6. Apply the existing Envoy Gateway and Blue Bank Argo CD Applications.
7. Argo CD installs Envoy Gateway and synchronizes `k8s/overlays/dev`.
8. Verify the public Load Balancer IP and send an HTTP request through Envoy to Spring Cloud Gateway.

Spring Cloud Gateway routes to Kubernetes Services through cluster DNS and retains JWT authentication, Redis-backed rate limiting, circuit breakers, fallbacks, and business-specific filters. No Eureka server, Eureka client, or Nginx proxy participates in this flow.

## Failure handling and safeguards

- Variable validation rejects malformed CIDRs, empty API allowlists, unsupported node counts, and invalid storage sizes before resource creation.
- Provider data sources select a compatible NKS version, node image, and server product rather than hard-coding unstable product identifiers where possible.
- Bootstrap and verification scripts use strict shell mode and require an explicit kubeconfig/context so they cannot mutate an unintended cluster.
- An unavailable NAT path is detected by node and workload readiness checks before Argo CD synchronization is considered successful.
- Missing Kubernetes Secrets leave workloads unready instead of injecting default secrets.
- Terraform failures are repaired at the infrastructure layer; Argo CD reconciliation failures are diagnosed at the Kubernetes layer.
- Remote state versioning provides recovery from accidental state replacement, while deletion protection reduces unintended NKS removal.

## Verification

Static and offline verification must succeed before any infrastructure apply:

- `terraform fmt -check -recursive infra`
- `terraform init -backend=false` where provider initialization permits it
- `terraform validate`
- Shell syntax checks for bootstrap and verification scripts
- Repository scans confirming that credentials, state, plans, kubeconfig, and real `terraform.tfvars` files are not tracked
- Existing `./gradlew clean test build` to ensure infrastructure changes do not break the Gateway build

After apply, verification checks:

- Terraform outputs and state backend availability
- NKS control-plane access from an allowed IP and denial assumptions for non-allowed addresses
- two Ready worker nodes on private addresses
- NAT-backed outbound image pulls
- Argo CD, Envoy Gateway, Gateway API, Spring Gateway, and Redis readiness
- allocation of a public Load Balancer address
- an HTTP request through Envoy Gateway

## Deferred items

- Multi-zone production cluster and production node sizing
- Production remote-state key and environment root module
- Domain, DNS, certificate issuance, and HTTPS listener
- Managed or highly available production Redis
- CI-provider-specific image build and NCR push workflow
- Central observability, backup policy, and disaster-recovery automation
- Private-only Kubernetes API connectivity through VPN or a bastion

