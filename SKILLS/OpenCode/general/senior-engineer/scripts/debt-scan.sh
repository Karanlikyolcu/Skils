#!/usr/bin/env bash
# Quick structural scan of a codebase for common technical-debt signals.
# Usage: debt-scan.sh [path]
# This is a heuristic aid, not an audit. Verify every finding by reading the code.

set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "cannot enter: $ROOT" >&2; exit 2; }

echo "== Structural debt scan: $(pwd) =="

files=$(find . -type f \
  \( -name '*.py' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' -o -name '*.tsx' \
     -o -name '*.go' -o -name '*.java' -o -name '*.kt' -o -name '*.rb' -o -name '*.rs' \
     -o -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.cs' -o -name '*.swift' \
     -o -name '*.php' -o -name '*.scala' -o -name '*.dart' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' \
  -not -path '*/dist/*' -not -path '*/build/*' -not -path '*/.venv/*' \
  -not -path '*/__pycache__/*' -not -path '*/target/*' -not -path '*/coverage/*' 2>/dev/null)

count=$(printf '%s\n' "$files" | grep -c . || true)
echo "  source files: $count"

# --- Large files ------------------------------------------------------------
echo
echo "-- Large files (>600 lines) --"
if [ "$count" -gt 0 ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    lines=$(wc -l < "$f" 2>/dev/null || echo 0)
    if [ "$lines" -gt 600 ]; then
      printf '  %-60s %6s lines\n' "$f" "$lines"
    fi
  done <<< "$files" | sort -k2 -rn | head -15
fi

# --- Long functions (indentation-based heuristic) ---------------------------
echo
echo "-- Long functions (heuristic: >80 lines between def/func/class) --"
found_long=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  awk '
    /^[[:space:]]*(def|func|function|public|private|protected|async)[^=]*\{?[[:space:]]*$/ { start=NR; name=$0 }
    END { if (start>0 && NR-start>80) printf "  %-58s %5d lines from line %d\n", FILENAME, NR-start, start }
  ' "$f" 2>/dev/null
done <<< "$files" | head -12

# --- TODO / FIXME -----------------------------------------------------------
echo
echo "-- TODO / FIXME / HACK / XXX --"
if [ "$count" -gt 0 ]; then
  grep -rnE '\b(TODO|FIXME|HACK|XXX)\b' $files 2>/dev/null \
    | grep -vE '(node_modules|/vendor/|/dist/|/build/)' | head -20 \
    | awk -F: '{printf "  %s:%s  %s\n", $1, $2, substr($0, index($0,$3))}' | cut -c1-140
  todo_count=$(grep -rnE '\b(TODO|FIXME|HACK|XXX)\b' $files 2>/dev/null | grep -vcE '(node_modules|/vendor/)' || true)
  echo "  total: $todo_count"
fi

# --- Error swallowing -------------------------------------------------------
echo
echo "-- Swallowed errors (catch with empty/pass body) --"
if [ "$count" -gt 0 ]; then
  grep -rnE -A2 'catch[ (]|except[[:space:]]*:|\.catch\(' $files 2>/dev/null \
    | grep -E '(pass$|continue$|return[[:space:]]+None?$|\{\s*\}|//\s*ignore|/\*\s*ignore)' \
    | head -12 | cut -c1-140
fi

# --- Long parameter lists ---------------------------------------------------
echo
echo "-- Long parameter lists (>=6 params) --"
if [ "$count" -gt 0 ]; then
  grep -rnE '^\s*(def|func|function|public|private|protected)[^()]*\([^)]*,[^)]*,[^)]*,[^)]*,[^)]*,[^)]*\)' $files 2>/dev/null \
    | head -12 | cut -c1-140
fi

# --- God files / type declarations -----------------------------------------
echo
echo "-- Files with many type/class declarations (possible god file) --"
if [ "$count" -gt 0 ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    n=$(grep -cE '^\s*(export\s+)?(class|interface|struct|enum|def|func)\s' "$f" 2>/dev/null || echo 0)
    if [ "$n" -gt 15 ]; then
      printf '  %-58s %4d declarations\n' "$f" "$n"
    fi
  done <<< "$files" | head -12
fi

# --- Mixed duplication signal (same 8-line block appearing twice) -----------
echo
echo "-- Possible duplication (identical 8-line blocks appearing 2+ times) --"
if [ "$count" -gt 0 ] && command -v python3 >/dev/null 2>&1; then
  python3 - <<'PY' 2>/dev/null | head -12
import hashlib, os, re, sys
from collections import defaultdict

BLOCK = 8
buckets = defaultdict(list)
skip_dirs = {'node_modules', '.git', 'vendor', 'dist', 'build', '.venv', '__pycache__', 'target', 'coverage'}
exts = {'.py', '.js', '.jsx', '.ts', '.tsx', '.go', '.java', '.kt', '.rb', '.rs', '.cs', '.swift', '.php'}

for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in skip_dirs]
    for fn in files:
        if os.path.splitext(fn)[1] not in exts:
            continue
        path = os.path.join(root, fn)
        try:
            lines = [l.rstrip() for l in open(path, encoding='utf-8', errors='ignore')]
        except OSError:
            continue
        for i in range(len(lines) - BLOCK):
            block = [l for l in lines[i:i+BLOCK] if l.strip()]
            if len(block) < BLOCK - 2:
                continue
            h = hashlib.md5('\n'.join(block).encode()).hexdigest()
            buckets[h].append((path, i + 1))

hits = [(v[0][0], v[0][1]) for v in buckets.values() if len(v) > 1]
seen = set()
for path, line in sorted(hits)[:12]:
    key = (path, line)
    if key in seen:
        continue
    seen.add(key)
    print(f"  {path}:{line}  (duplicate block)")
PY
fi

# --- Git churn (change coupling) --------------------------------------------
echo
echo "-- Files changed most often (last 300 commits) --"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  git log --name-only --pretty=format: -n 300 2>/dev/null \
    | grep -vE '^$' | sort | uniq -c | sort -rn | head -12 \
    | awk '{printf "  %5d  %s\n", $1, $2}'
else
  echo "  (not a git repository, skipping churn analysis)"
fi

echo
echo "Reminder: this scan finds signals, not problems. Confirm each one by reading the code,"
echo "and judge priority by blast radius and pain frequency, not by the count above."
