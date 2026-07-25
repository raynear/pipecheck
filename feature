#!/bin/bash
# ./run feature 위임 래퍼 — 부트스트랩 가드(pub get, fastlane 클론)는 run이 수행
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/run" feature "$@"
