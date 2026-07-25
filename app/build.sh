#!/bin/bash

# Build script for the app
# Runs build_runner, organizes generated files, and syncs database.dart.
#
# In CI (fresh checkout), generated files don't exist yet.
# database.dart imports from lib/data/generated/drift/ but build_runner
# generates .drift.dart files in lib/data/definitions/ first.
# Order matters:
#   pass 1:   generate .drift.dart files next to definitions
#   organize: move them to generated/drift/
#   sync:     update database.dart imports/tables to match generated/drift/
#   pass 2:   drift now sees the synced database.dart -> database.g.dart correct
#   organize: move any files pass 2 produced

echo "🚀 Starting build process..."

# Resolve repo root from this script's own location (build.sh runs with cwd=app/
# when invoked by init/deploy via `bash build.sh` in appDir).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Regenerate env artifacts (.env.{debug,profile,release}) to match ./build.
# Idempotent: ./run gen-env just rewrites the runtime env files, so running it
# here is harmless even though init already ran generateEnvStep and deploy
# writes runtime artifacts. Non-fatal: a warning must not abort the build.
echo "🔑 Regenerating env artifacts..."
"$ROOT/run" gen-env
if [ $? -ne 0 ]; then
    echo "⚠️  Env artifact generation failed (non-fatal, continuing)"
fi

# Resolve dependencies (mirrors ./build). Idempotent: flutter pub get is safe to
# re-run repeatedly. Hard-fail like the pass-1 step below.
echo "📥 Running flutter pub get..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ flutter pub get failed"
    exit 1
fi
echo "✅ Dependencies resolved"

# Run build_runner (1st pass)
echo "📦 Running build_runner (pass 1)..."
dart run build_runner build --delete-conflicting-outputs

if [ $? -ne 0 ]; then
    echo "❌ Build failed on pass 1"
    exit 1
fi
echo "✅ Pass 1 completed"

# Run file organizer - moves .drift.dart to generated/drift/
echo "📂 Organizing generated files..."
dart lib/data/table_generator/organize_files.dart --clean

if [ $? -ne 0 ]; then
    echo "⚠️  File organization failed"
fi

# Sync database.dart with generated tables (must run BEFORE pass 2 so that
# drift generates database.g.dart from the updated table list/imports)
echo "🔄 Syncing database.dart..."
dart lib/data/table_generator/sync_database.dart

if [ $? -eq 0 ]; then
    echo "✨ Database synced successfully!"
else
    echo "⚠️  Database sync failed"
fi

# Run build_runner (2nd pass) - now database.dart imports can resolve
echo "📦 Running build_runner (pass 2)..."
dart run build_runner build --delete-conflicting-outputs

if [ $? -ne 0 ]; then
    echo "⚠️  Pass 2 build_runner failed (non-fatal)"
fi

# Organize again in case pass 2 generated new files
echo "📂 Final file organization..."
dart lib/data/table_generator/organize_files.dart --clean 2>/dev/null

echo "🎉 Build process complete!"
