#!/bin/sh

# husky.sh - Husky hook loader
# husky >= 9.0.0 버전용

# CI 환경이거나 husky가 비활성화된 경우 스킵
if [ "$HUSKY" = "0" ]; then
  exit 0
fi

# 환경 변수 설정
export HUSKY_GIT_PARAMS="$@"
