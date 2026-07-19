# `test-utils`

통합 테스트와 로컬 검증에 사용하는 보조 스크립트·도구입니다. 운영 배포 리소스나 NCP Terraform state를 관리하지 않습니다.

변경 후에는 루트의 `./gradlew clean test build`와 관련 Kubernetes/Terraform 검증을 실행합니다.
