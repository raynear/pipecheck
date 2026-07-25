# Makefile for BoilerPlate App

.PHONY: build organize generate clean help

# 기본 타겟
all: generate

# build_runner 실행
build:
	@echo "🔨 Running build_runner..."
	@dart run build_runner build --delete-conflicting-outputs

# 파일 정리
organize:
	@echo "📁 Organizing generated files..."
	@dart lib/data/table_generator/organize_files.dart --clean

# 빌드 후 파일 정리까지 한번에
generate: build organize
	@echo "✅ Build and organize completed!"

# 생성된 파일들 삭제
clean:
	@echo "🧹 Cleaning generated files..."
	@dart run build_runner clean
	@rm -rf lib/data/generated/

# 도움말
help:
	@echo "Available commands:"
	@echo "  make build     - Run build_runner"
	@echo "  make organize  - Organize generated files"
	@echo "  make generate  - Build and organize (default)"
	@echo "  make clean     - Clean all generated files"
	@echo "  make help      - Show this help message"