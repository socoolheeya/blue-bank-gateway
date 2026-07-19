# `docker`

로컬 Gateway 이미지와 Docker 관련 설정을 보관합니다.

NCP 배포 이미지는 이 저장소 루트의 Dockerfile로 빌드해 NCR에 Push합니다.

```bash
docker build -t "$NCR_ENDPOINT/blue-bank-gateway:$IMAGE_TAG" .
docker push "$NCR_ENDPOINT/blue-bank-gateway:$IMAGE_TAG"
```

Nginx는 현재 아키텍처에서 사용하지 않습니다.
