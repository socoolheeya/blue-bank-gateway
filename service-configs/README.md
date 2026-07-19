# `service-configs`

Spring Cloud 설정 예제와 Docker Compose 전환용 서비스 설정입니다.

`*-eureka-config.yml` 파일은 레거시 Compose/Eureka 전환 참고용입니다. NKS 배포에서는 Eureka를 사용하지 않고 Kubernetes Service DNS를 사용합니다.

Kubernetes 설정은 `k8s/base/configmap.yaml`과 환경별 Overlay에서 관리합니다.
