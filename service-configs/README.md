# `service-configs`

기존 Compose 전용 서비스 설정은 Kubernetes 전환과 함께 제거했습니다.

현재 서비스 설정은 다음 위치에서 관리합니다.

- 공통 Gateway 환경값: `k8s/base/configmap.yaml`
- 개발 환경: `k8s/overlays/dev/`
- 운영 환경: `k8s/overlays/prod/`

업무 서비스는 `account`, `deposit`, `loan`, `card` Kubernetes Service DNS를 사용합니다.
