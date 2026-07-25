#!/bin/bash

# 색상 코드 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📸 Starting screenshot generation...${NC}"

# 기존 스크린샷 디렉토리 정리
if [ -d "screenshots" ]; then
    echo -e "${YELLOW}🗑️  Cleaning existing screenshots...${NC}"
    rm -rf screenshots/
fi

# 스크린샷 디렉토리 생성
mkdir -p screenshots

# Flutter 패키지 업데이트
echo -e "${BLUE}📦 Getting Flutter packages...${NC}"
flutter pub get

# 통합 테스트 실행
echo -e "${BLUE}🧪 Running integration tests...${NC}"
flutter test integration_test/screenshot_simple.dart --dart-define=SCREENSHOT_MODE=true

# 결과 확인
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Screenshot generation complete!${NC}"
    
    # 생성된 스크린샷 목록 표시
    echo -e "${BLUE}📁 Generated screenshots:${NC}"
    ls -la screenshots/*.png 2>/dev/null | awk '{print "   " $9}'
    
    # 스크린샷 개수 표시
    COUNT=$(ls -1 screenshots/*.png 2>/dev/null | wc -l)
    echo -e "${GREEN}📊 Total screenshots: ${COUNT}${NC}"
else
    echo -e "${RED}❌ Screenshot generation failed!${NC}"
    exit 1
fi

# Fastlane 통합 옵션
if [ "$1" == "--fastlane" ]; then
    echo -e "${BLUE}🚀 Preparing for Fastlane...${NC}"
    
    # iOS Fastlane 디렉토리 구조 생성
    for file in screenshots/*.png; do
        if [ -f "$file" ]; then
            filename=$(basename "$file")
            language="${filename%%_*}"
            
            # Fastlane 스크린샷 디렉토리 생성
            mkdir -p "ios/fastlane/screenshots/${language}"
            
            # 파일 복사
            cp "$file" "ios/fastlane/screenshots/${language}/"
            echo -e "   Copied: $filename → ios/fastlane/screenshots/${language}/"
        fi
    done
    
    echo -e "${GREEN}✅ Fastlane preparation complete!${NC}"
fi