# Prod Overlay

운영용 Kubernetes 차이점입니다.

- Gateway replica/resource 증가
- `/management/health/*` probe
- 외부 Redis Endpoint
- 개발용 Redis StatefulSet/Service 제거

운영 도메인·TLS·Managed Redis가 확정된 뒤 별도 운영 값과 state로 배포합니다.
