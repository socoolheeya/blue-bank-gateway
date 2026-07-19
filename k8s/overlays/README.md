# Kubernetes Overlays

환경별 차이만 Patch와 Image 설정으로 관리합니다.

- `dev/`: 개발용 이미지와 Redis StatefulSet
- `prod/`: 운영용 리소스와 외부 Redis

새 환경을 추가할 때 Base 리소스를 복사하지 말고 Overlay를 추가합니다.
