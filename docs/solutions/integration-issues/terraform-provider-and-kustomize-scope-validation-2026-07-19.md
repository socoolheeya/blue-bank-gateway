---
title: Terraform Provider 주소와 Kustomize 리소스 범위 검증
date: 2026-07-19
category: integration-issues
module: NCP NKS infrastructure and Kubernetes manifests
problem_type: integration_issue
component: tooling
symptoms:
  - "독립 Terraform 모듈 초기화가 ncloud를 NaverCloudPlatform/ncloud 대신 hashicorp/ncloud로 해석했다."
  - "Kustomize Namespace 변환이 클러스터 범위 GatewayClass에 metadata.namespace를 추가했다."
  - "원본 파일 검사는 통과했지만 독립 모듈 초기화와 최종 Kubernetes 렌더 결과가 유효하지 않았다."
root_cause: config_error
resolution_type: code_fix
severity: medium
related_components:
  - terraform
  - kustomize
  - kubernetes-gateway-api
tags:
  - naver-cloud
  - nks
  - terraform-provider
  - kustomize
  - gateway-api
  - static-validation
---

# Terraform Provider 주소와 Kustomize 리소스 범위 검증

## Problem

NCP NKS Terraform 구현을 독립 모듈 단위로 검증하는 과정에서 Terraform이 `ncloud`를 존재하지 않는 `hashicorp/ncloud`로 해석했다. Kubernetes Overlay는 렌더링 후 클러스터 범위인 `GatewayClass`에 `namespace: blue-bank`를 추가해 실제 Apply를 막을 수 있었다.

두 문제 모두 원본 코드만 보면 정상처럼 보이지만 도구가 모듈과 Overlay를 합성한 최종 결과에서 발생했다.

## Symptoms

- `terraform init`이 `hashicorp/ncloud` Provider를 찾으려 한다.
- Root Module은 정상이어도 `infra/modules/network` 또는 `infra/modules/nks`를 직접 초기화하면 Provider 주소가 달라진다.
- `kubectl kustomize k8s/overlays/dev` 출력의 `GatewayClass`에 `metadata.namespace`가 나타난다.
- Kubernetes Apply 시 cluster-scoped 리소스의 Namespace 오류 또는 상태 불일치가 발생할 수 있다.

## What Didn't Work

- Root Module에만 `required_providers`를 선언하는 방식은 독립적으로 초기화하는 Child Module의 Provider 주소를 보장하지 못했다. Provider 설정 전달과 Provider source requirement는 다른 문제다.
- `k8s/base/kustomization.yaml`에 전역 `namespace: blue-bank`를 두는 방식은 `Gateway`, `HTTPRoute`뿐 아니라 cluster-scoped `GatewayClass`에도 Namespace를 주입했다.
- JSON Patch로 렌더 후 Namespace를 제거하려 했지만 Patch가 Namespace Transformer보다 먼저 실행돼 아직 존재하지 않는 `/metadata/namespace`를 제거할 수 없었다.
- 원본 YAML만 검색하는 검사는 Kustomize가 합성 중 추가한 잘못된 필드를 발견하지 못했다.

## Solution

독립적으로 검증하는 모든 Terraform 모듈에 같은 Provider source와 버전을 선언했다.

```hcl
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    ncloud = {
      source  = "NaverCloudPlatform/ncloud"
      version = "4.0.5"
    }
  }
}
```

이 선언은 다음 파일에 존재한다.

- `infra/modules/network/versions.tf`
- `infra/modules/nks/versions.tf`
- `infra/environments/dev/providers.tf`

Kustomize Base에서는 전역 `namespace:`를 제거했다. ConfigMap, Service, Deployment, StatefulSet, PDB, HPA, `Gateway`, `HTTPRoute`와 Production Patch에는 `metadata.namespace: blue-bank`를 명시하고, `GatewayClass`에는 Namespace를 두지 않았다.

최종 렌더 결과를 `infra/tests/static.sh`에서 검사한다.

```bash
kubectl kustomize k8s/overlays/dev >"$rendered_dev"
```

검사는 `GatewayClass` 문서에 Namespace가 있으면 실패하며, namespace-scoped Kind에 `blue-bank`가 없을 때도 실패한다.

## Why This Works

Terraform에서 Provider의 Local Name인 `ncloud`와 Global Source Address인 `NaverCloudPlatform/ncloud`는 별개다. 각 모듈의 `required_providers`가 Source Identity를 결정하므로 독립적으로 초기화하거나 검증할 모듈마다 주소를 선언해야 한다. Root의 lock file은 실제 선택 결과를 `registry.terraform.io/navercloudplatform/ncloud` 4.0.5로 고정한다.

Kubernetes Namespace는 리소스 범위의 일부다. `GatewayClass`는 클러스터 전체에서 Envoy Controller를 선택하는 cluster-scoped 리소스이고, `Gateway`, `HTTPRoute`와 Workload는 namespace-scoped 리소스다. 각 namespaced 리소스에 Namespace를 명시하면 Kustomize가 알 수 없는 CRD 범위를 추측할 필요가 없다.

## Prevention

- 새 Terraform 모듈마다 `versions.tf`를 만들고 Provider source와 호환 버전을 명시한다.
- Root Module의 `.terraform.lock.hcl`에서 `registry.terraform.io/navercloudplatform/ncloud`를 확인한다.
- cluster-scoped 리소스가 포함된 Base에 전역 `namespace:`를 다시 추가하지 않는다.
- 새 Gateway API 리소스를 추가할 때 Kubernetes API scope를 먼저 확인한다.
- 원본 YAML뿐 아니라 모든 Overlay의 최종 렌더 결과를 검사한다.
- 다음 검증을 완료 전에 실행한다.

```bash
terraform fmt -check -recursive infra
terraform -chdir=infra/environments/dev init -backend=false -reconfigure
terraform -chdir=infra/environments/dev validate
bash infra/tests/static.sh
kubectl kustomize k8s/overlays/dev >/tmp/blue-bank-dev-rendered.yaml
kubectl kustomize k8s/overlays/prod >/tmp/blue-bank-prod-rendered.yaml
./gradlew clean test build
```

`Backend initialization required`는 Provider 주소 오류가 아니라 Backend 초기화 상태 문제다. 정적 검증 환경에서는 `-backend=false -reconfigure`를 사용하고 실제 배포 환경에서는 `backend.hcl`로 초기화한다.

## Related Issues

- [NCP NKS Terraform 구현 계획](../../superpowers/plans/2026-07-19-ncp-nks-terraform-infrastructure.md)
- [NCP NKS Terraform 설계](../../superpowers/specs/2026-07-19-ncp-nks-terraform-infrastructure-design.md)
- [NCP Terraform 배포 가이드](../../NCP_TERRAFORM_DEPLOYMENT.md)

