# Kubernetes Base

모든 환경에서 공통으로 사용하는 리소스입니다.

- Spring Cloud Gateway Deployment/Service
- Redis StatefulSet/Service/PVC
- HPA/PDB/ConfigMap
- Gateway API `GatewayClass`, `Gateway`, `HTTPRoute`

namespaced 리소스에는 `blue-bank`를 직접 지정하고, cluster-scoped인 `GatewayClass`에는 Namespace를 지정하지 않습니다.
