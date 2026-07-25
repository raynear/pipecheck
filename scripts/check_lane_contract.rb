#!/usr/bin/env ruby
# frozen_string_literal: true

# ============================================================
# fastlane 레인 계약 검증 (P1-12)
# ============================================================
# 템플릿(tools/cli + CI 워크플로우 + 문서화된 운영 명령)이 호출하는
# fastlane 레인이, 핀된 raynear/flutter-fastlane 클론에 모두 존재하는지
# 'bundle exec fastlane lanes' 출력을 파싱해 검증한다.
#
# 사용법:
#   ruby scripts/check_lane_contract.rb [fastlane_dir]
#   fastlane_dir: fastlane repo 클론 디렉토리 (기본: ./fastlane)
#
# 종료 코드: 0 = 계약 충족, 1 = 레인 누락 또는 실행 실패
# 소비처: .github/workflows/lane-contract.yml
# ============================================================

require 'open3'

# tools/cli가 호출하는 레인
# (실측: grep "_runFastlane\|runLane" tools/cli/lib → deploy_command.dart)
CLI_LANES = %w[
  build_and_upload
  bump_version
  generate_release_notes
  generate_screenshots
  upload_metadata
].freeze

# CI 워크플로우가 직접 호출하는 레인
# (.github/workflows/ci.yml, .github/workflows/firebase-distribution.yml)
WORKFLOW_LANES = %w[
  build_and_upload_ios
  build_and_upload_android
  distribute_ios
  distribute_android
].freeze

# 문서화된 핵심 운영 레인 (CLAUDE.md / docs의 사용자 진입점)
DOCUMENTED_LANES = %w[
  codegen
  ensure_version
  test
  version
].freeze

REQUIRED_LANES = (CLI_LANES + WORKFLOW_LANES + DOCUMENTED_LANES).sort.freeze

# 'fastlane lanes' 출력에서 레인 이름을 추출한다.
# 출력 형식 예: "----- fastlane build_and_upload"
def parse_available_lanes(output)
  stripped = output.gsub(/\e\[[0-9;]*m/, '') # ANSI 컬러 제거 (방어적)
  stripped
    .scan(/^-+\s*fastlane\s+(.+?)\s*$/)
    .map { |match| match[0].split.last } # 플랫폼 레인("ios beta")은 레인명만
    .uniq
end

def run_fastlane_lanes(fastlane_dir)
  env = {
    'FASTLANE_SKIP_UPDATE_CHECK' => '1',
    'FASTLANE_OPT_OUT_USAGE' => '1',
    'FASTLANE_DISABLE_COLORS' => '1',
  }
  Open3.capture3(env, 'bundle', 'exec', 'fastlane', 'lanes', chdir: fastlane_dir)
end

def main
  fastlane_dir = ARGV.fetch(0, 'fastlane')

  unless File.directory?(fastlane_dir)
    warn "✗ fastlane 디렉토리가 없습니다: #{fastlane_dir}"
    warn "  (project.yaml tooling.fastlane_ref로 raynear/flutter-fastlane을 먼저 checkout 하세요)"
    exit 1
  end

  stdout, stderr, status = run_fastlane_lanes(fastlane_dir)

  unless status.success?
    warn '✗ bundle exec fastlane lanes 실행 실패:'
    warn stdout
    warn stderr
    exit 1
  end

  available = parse_available_lanes("#{stdout}\n#{stderr}")
  missing = REQUIRED_LANES - available

  puts "계약 레인 #{REQUIRED_LANES.size}개 / 사용 가능 레인 #{available.size}개"

  if missing.empty?
    puts "✓ 레인 계약 충족 — #{REQUIRED_LANES.join(', ')}"
    exit 0
  end

  warn "✗ 핀된 fastlane ref에 누락된 레인 #{missing.size}개:"
  missing.each { |lane| warn "  - #{lane}" }
  warn '  → fastlane repo에 레인을 추가하거나, 호출부(tools/cli·워크플로우)와'
  warn '    project.yaml tooling.fastlane_ref 핀을 함께 갱신하세요.'
  exit 1
end

main if $PROGRAM_NAME == __FILE__
