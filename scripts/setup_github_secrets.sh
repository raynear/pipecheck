#!/bin/bash
# ============================================================
# GitHub Secrets 일괄 설정 스크립트
# ============================================================
# .env (프로젝트 루트)와 프로젝트 구조에서 자동으로 파일/값을 읽어 설정합니다.
#
# 사용법:
#   ./scripts/setup_github_secrets.sh [owner/repo]
#
# owner/repo 생략 시 .env의 GITHUB_REPOSITORY 사용
#
# 사전 준비:
#   1. gh auth login (GitHub CLI 로그인)
#   2. .env (프로젝트 루트) 설정 완료
#   3. .env에 명시된 파일들이 해당 경로에 존재
#
# 자동으로 읽어오는 항목:
#   프로젝트 파일:
#     app/config/env/.env.debug     → ENV_DEBUG
#     app/config/env/.env.profile   → ENV_PROFILE
#     app/config/env/.env.release   → ENV_RELEASE
#     .env                          → DOTENV_PROJECT
#     app/.env                      → DOTENV (있는 경우)
#
#   .env 경로 참조 (Base64):
#     APP_STORE_CONNECT_API_KEY_FILE  → APP_STORE_CONNECT_API_KEY_CONTENT
#     KEYSTORE_PATH                   → ANDROID_KEYSTORE
#     GOOGLE_PLAY_JSON_KEY            → GOOGLE_PLAY_CONFIG_JSON
#     GOOGLE_APPLICATION_CREDENTIALS  → FIREBASE_SERVICE_ACCOUNT_BASE64
#
#   .env 값 참조 (문자열):
#     GITHUB_TOKEN                    → GIT_AUTH_TOKEN
#     MATCH_PASSWORD                  → MATCH_PASSWORD
#     APP_STORE_CONNECT_API_KEY_ID    → APP_STORE_CONNECT_API_KEY_ID
#     APP_STORE_CONNECT_API_ISSUER_ID → APP_STORE_CONNECT_API_ISSUER_ID
#     KEYSTORE_PASSWORD               → ANDROID_STORE_PASSWORD
#     KEY_ALIAS                       → ANDROID_KEY_ALIAS
#     KEY_PASSWORD                    → ANDROID_KEY_PASSWORD
# ============================================================

set -euo pipefail

# ── 프로젝트 루트 감지 ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_PROJECT="$PROJECT_ROOT/.env"

if [ ! -f "$ENV_PROJECT" ]; then
  echo "Error: .env 파일이 없습니다: $ENV_PROJECT"
  echo "  ./init을 실행하여 .env를 생성하세요."
  exit 1
fi

# ── .env 파싱 ──
# 따옴표 제거 및 ~ 확장
get_env_value() {
  local key="$1"
  local value
  value=$(grep -E "^${key}=" "$ENV_PROJECT" | head -1 | sed 's/^[^=]*=//')
  # 따옴표 제거 (single/double)
  value=$(echo "$value" | sed "s/^['\"]//;s/['\"]$//")
  echo "$value"
}

# ~ 를 $HOME으로 확장
expand_path() {
  local path="$1"
  echo "${path/#\~/$HOME}"
}

# ── gh CLI 확인 ──
if ! command -v gh &>/dev/null; then
  echo "Error: gh CLI가 설치되어 있지 않습니다."
  echo "  brew install gh && gh auth login"
  exit 1
fi

if ! gh auth status &>/dev/null 2>&1; then
  echo "Error: gh CLI 로그인이 필요합니다."
  echo "  gh auth login"
  exit 1
fi

# ── 레포지토리 결정 ──
REPO="${1:-}"
if [ -z "$REPO" ]; then
  REPO=$(get_env_value "GITHUB_REPOSITORY")
  if [ -z "$REPO" ]; then
    echo "Error: 레포지토리를 지정하세요."
    echo "  ./scripts/setup_github_secrets.sh <owner/repo>"
    exit 1
  fi
  echo "GITHUB_REPOSITORY에서 자동 감지: $REPO"
fi

# ── 헬퍼 함수 ──
set_secret() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "  SKIP $name (값 없음)"
    SKIPPED=$((SKIPPED + 1))
    return
  fi
  echo "  Setting $name..."
  gh secret set "$name" -R "$REPO" -b "$value"
  SUCCESS=$((SUCCESS + 1))
}

set_secret_from_file() {
  local name="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo "  SKIP $name (파일 없음: $file)"
    SKIPPED=$((SKIPPED + 1))
    return
  fi
  echo "  Setting $name... (from $(basename "$file"))"
  gh secret set "$name" -R "$REPO" < "$file"
  SUCCESS=$((SUCCESS + 1))
}

set_secret_base64() {
  local name="$1"
  local file="$2"
  if [ ! -f "$file" ]; then
    echo "  SKIP $name (파일 없음: $file)"
    SKIPPED=$((SKIPPED + 1))
    return
  fi
  echo "  Setting $name... (base64 of $(basename "$file"))"
  gh secret set "$name" -R "$REPO" -b "$(base64 < "$file")"
  SUCCESS=$((SUCCESS + 1))
}

SUCCESS=0
SKIPPED=0

echo ""
echo "============================================================"
echo " GitHub Secrets 설정: $REPO"
echo " 소스: $ENV_PROJECT"
echo "============================================================"
echo ""

# ── 1. 환경 변수 파일 (프로젝트 구조에서 자동 읽기) ──
echo "[1/4] 환경 변수 파일..."
set_secret_from_file "ENV_DEBUG"   "$PROJECT_ROOT/app/config/env/.env.debug"
set_secret_from_file "ENV_PROFILE" "$PROJECT_ROOT/app/config/env/.env.profile"
set_secret_from_file "ENV_RELEASE" "$PROJECT_ROOT/app/config/env/.env.release"
set_secret_from_file "DOTENV_PROJECT" "$ENV_PROJECT"
set_secret_from_file "DOTENV"      "$PROJECT_ROOT/app/.env"
echo ""

# ── 2. Base64 인코딩 파일 (.env 경로에서 자동 읽기) ──
echo "[2/4] 인증서 & 서비스 계정 파일 (Base64)..."

P8_PATH=$(expand_path "$(get_env_value 'APP_STORE_CONNECT_API_KEY_FILE')")
KEYSTORE=$(expand_path "$(get_env_value 'KEYSTORE_PATH')")
PLAY_KEY=$(expand_path "$(get_env_value 'GOOGLE_PLAY_JSON_KEY')")
SA_FILE=$(expand_path "$(get_env_value 'GOOGLE_APPLICATION_CREDENTIALS')")

set_secret_base64 "APP_STORE_CONNECT_API_KEY_CONTENT" "$P8_PATH"
set_secret_base64 "ANDROID_KEYSTORE"                  "$KEYSTORE"
set_secret_base64 "GOOGLE_PLAY_CONFIG_JSON"            "$PLAY_KEY"
set_secret_base64 "FIREBASE_SERVICE_ACCOUNT_BASE64"    "$SA_FILE"
echo ""

# ── 3. 문자열 시크릿 (.env 값에서 자동 읽기) ──
echo "[3/4] 문자열 시크릿..."
set_secret "GIT_AUTH_TOKEN"                  "$(get_env_value 'GITHUB_TOKEN')"
set_secret "MATCH_PASSWORD"                  "$(get_env_value 'MATCH_PASSWORD')"
set_secret "APP_STORE_CONNECT_API_KEY_ID"    "$(get_env_value 'APP_STORE_CONNECT_API_KEY_ID')"
set_secret "APP_STORE_CONNECT_API_ISSUER_ID" "$(get_env_value 'APP_STORE_CONNECT_API_ISSUER_ID')"
set_secret "ANDROID_STORE_PASSWORD"          "$(get_env_value 'KEYSTORE_PASSWORD')"
set_secret "ANDROID_KEY_ALIAS"               "$(get_env_value 'KEY_ALIAS')"
set_secret "ANDROID_KEY_PASSWORD"            "$(get_env_value 'KEY_PASSWORD')"
echo ""

# ── 4. 결과 확인 ──
echo "[4/4] 설정 완료 확인..."
echo ""
gh secret list -R "$REPO"

echo ""
echo "============================================================"
echo " 완료! 설정: ${SUCCESS}개 | 스킵: ${SKIPPED}개"
echo "============================================================"
echo ""
echo "다음 단계:"
echo "  1. git tag v0.0.1-test && git push origin v0.0.1-test  (CI 테스트)"
echo "  2. GitHub Actions 탭에서 실행 결과 확인"
echo "  3. 테스트 태그 삭제: git tag -d v0.0.1-test && git push origin :v0.0.1-test"
