#!/usr/bin/env bash
# Detect the project stack and print the available verification commands.
# Usage: precheck.sh [project-dir]

set -uo pipefail

DIR="${1:-.}"
cd "$DIR" 2>/dev/null || { echo "cannot enter directory: $DIR" >&2; exit 1; }

found=0

section() {
  if [ "$found" -eq 1 ]; then
    printf '\n'
  fi
  found=1
  printf '== %s ==\n' "$1"
}

run_scripts() {
  # $1 = package.json path
  node -e '
    const p = require(process.argv[1]);
    const s = p.scripts || {};
    const keys = Object.keys(s);
    if (!keys.length) process.exit(0);
    for (const k of keys) console.log(`  ${k}: ${s[k]}`);
  ' "$1" 2>/dev/null
}

if [ -f package.json ]; then
  section "Node / package.json"
  [ -f pnpm-lock.yaml ] && echo "  package manager: pnpm"
  [ -f yarn.lock ] && echo "  package manager: yarn"
  [ -f bun.lockb ] || [ -f bun.lock ] && echo "  package manager: bun"
  [ -f package-lock.json ] && echo "  package manager: npm"
  echo "  scripts:"
  run_scripts package.json || echo "  (none)"
fi

if [ -f pyproject.toml ] || [ -f setup.py ] || [ -f requirements.txt ]; then
  section "Python"
  [ -f uv.lock ] && echo "  tool: uv"
  [ -f poetry.lock ] && echo "  tool: poetry"
  [ -f tox.ini ] && echo "  tox: tox"
  [ -f .pre-commit-config.yaml ] && echo "  hooks: pre-commit"
  echo "  candidates: pytest, ruff, mypy, pyright"
fi

if [ -f go.mod ]; then
  section "Go"
  echo "  candidates: go build ./..., go vet ./..., go test ./..."
fi

if [ -f Cargo.toml ]; then
  section "Rust"
  echo "  candidates: cargo fmt, cargo clippy, cargo test"
fi

if [ -f pom.xml ]; then
  section "Java / Maven"
  echo "  candidates: mvn -q verify, mvn test"
fi

if [ -f build.gradle ] || [ -f build.gradle.kts ]; then
  section "Java / Gradle"
  echo "  candidates: ./gradlew build, ./gradlew test"
fi

if [ -f Gemfile ]; then
  section "Ruby"
  echo "  candidates: bundle exec rspec, bundle exec rubocop"
fi

if [ -f Makefile ]; then
  section "Makefile targets"
  grep -E '^[a-zA-Z0-9_.-]+:' Makefile 2>/dev/null | cut -d: -f1 | sed 's/^/  /' | head -40
fi

if [ -f justfile ] || [ -f Justfile ]; then
  section "just recipes"
  grep -E '^[a-zA-Z0-9_-]+:' justfile Justfile 2>/dev/null | cut -d: -f1 | sed 's/^/  /' | head -40
fi

if [ -f Taskfile.yml ]; then
  section "Taskfile tasks"
  grep -E '^  [a-zA-Z0-9_-]+:' Taskfile.yml 2>/dev/null | sed 's/^  \([^:]*\):/  \1/' | head -40
fi

if [ -d .github/workflows ]; then
  section "CI workflows"
  ls .github/workflows 2>/dev/null | sed 's/^/  /'
fi

if [ -f AGENTS.md ]; then
  section "Instructions"
  echo "  AGENTS.md present - read it first"
fi
[ -f CLAUDE.md ] && echo "  CLAUDE.md present - read it first"

if [ "$found" -eq 0 ]; then
  echo "No recognizable stack detected in $(pwd)"
fi

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf '\n== Git ==\n'
  echo "  branch: $(git branch --show-current)"
  git status --porcelain | sed 's/^/  /' | head -30
fi
