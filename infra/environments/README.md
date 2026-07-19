# `infra/environments`

환경별 Terraform Root Module입니다. 현재는 `dev`만 제공합니다.

환경별 state와 변수는 서로 분리하고, 공용 리소스 정의는 `../modules`에서 재사용합니다. 운영 환경을 추가할 때 `prod` Root Module과 별도 state key를 추가합니다.
