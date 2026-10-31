#!/usr/bin/env bash
# Scan a repository for committed secrets and common security misconfigurations.
# Usage: secret-scan.sh [path]
# Exit: 0 = clean, 1 = findings, 2 = error

set -uo pipefail

ROOT="${1:-.}"
cd "$ROOT" 2>/dev/null || { echo "cannot enter: $ROOT" >&2; exit 2; }

findings=0
report() {
  findings=$((findings + 1))
  printf '  [%s] %s:%s  %s\n' "$1" "$2" "$3" "$4"
}

echo "== Secret scan: $(pwd) =="

# --- Files that should never be tracked -------------------------------------
echo
echo "-- Tracked files that must not be committed --"
tracked=$(git ls-files 2>/dev/null)
if [ -z "$tracked" ]; then
  echo "  (not a git repository, skipping tracked-file check)"
else
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *.env|.env.*|*.pem|*.key|*.p12|*.pfx|*.keystore|*.jks|*.p12|secrets.*|*credentials*|*_rsa|*_dsa|*_ed25519|id_rsa|id_dsa|id_ecdsa|id_ed25519)
        case "$f" in
          *.example|*.sample|*.template|*.dist) ;;
          *) report "HIGH" "$f" "-" "sensitive file tracked in git" ;;
        esac
        ;;
    esac
  done <<< "$tracked"
fi

# --- Pattern scan -----------------------------------------------------------
echo
echo "-- Secret patterns in tracked files --"
PATTERNS='(api[_-]?key|apikey|secret[_-]?key|secret|password|passwd|pwd|token|access[_-]?key|private[_-]?key|client[_-]?secret)[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9_/+-]{16,}'

if [ -n "$tracked" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *.lock|*.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.gz|*.woff*|*.ico|*.mp4|*.so|*.dll|*.exe) continue ;;
    esac
    [ -f "$f" ] || continue
    hits=$(grep -niE "$PATTERNS" "$f" 2>/dev/null | head -5)
    if [ -n "$hits" ]; then
      while IFS= read -r line; do
        lineno=$(printf '%s' "$line" | cut -d: -f1)
        snippet=$(printf '%s' "$line" | cut -d: -f2- | sed 's/[[:space:]]\+/ /g' | cut -c1-110)
        report "MED" "$f" "$lineno" "$snippet"
      done <<< "$hits"
    fi
  done <<< "$tracked"
else
  grep -rInE "$PATTERNS" . --exclude-dir={.git,node_modules,vendor,dist,build,.venv,__pycache__} 2>/dev/null | head -20 | while IFS= read -r line; do
    report "MED" "$(cut -d: -f1 <<< "$line")" "$(cut -d: -f2 <<< "$line")" "$(cut -d: -f3- <<< "$line" | cut -c1-110)"
  done
fi

# --- High-entropy known key prefixes ---------------------------------------
echo
echo "-- Known key prefixes --"
KNOWN='AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|gho_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{50,}|sk-[A-Za-z0-9]{32,}|sk_live_[A-Za-z0-9]{20,}|pk_live_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_\-]{35}|-----BEGIN [A-Z ]*PRIVATE KEY-----|eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9_\-]{10,}'

search_target="${tracked:-.}"
if [ -n "$tracked" ]; then
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in *.lock|*.png|*.jpg|*.pdf|*.zip|*.gz) continue ;; esac
    [ -f "$f" ] || continue
    hits=$(grep -nEo "$KNOWN" "$f" 2>/dev/null | head -3)
    [ -z "$hits" ] && continue
    while IFS= read -r line; do
      lineno=$(printf '%s' "$line" | cut -d: -f1)
      token=$(printf '%s' "$line" | cut -d: -f2-)
      report "CRIT" "$f" "$lineno" "possible live key: ${token:0:12}..."
    done <<< "$hits"
  done <<< "$tracked"
else
  grep -rInEo "$KNOWN" . --exclude-dir={.git,node_modules,vendor,dist,build,.venv} 2>/dev/null | head -20 | while IFS= read -r line; do
    report "CRIT" "$(cut -d: -f1 <<< "$line")" "$(cut -d: -f2 <<< "$line")" "possible live key"
  done
fi

# --- Misconfigurations ------------------------------------------------------
echo
echo "-- Common misconfigurations --"
misconfig() {
  if [ -f "$1" ]; then
    report "MED" "$1" "-" "$2"
  fi
}

# CORS wildcard with credentials
for f in $(find . -maxdepth 3 -type f \( -name '*.js' -o -name '*.ts' -o -name '*.py' -o -name '*.go' -o -name '*.java' \) -not -path '*/node_modules/*' 2>/dev/null | head -200); do
  if grep -qE "Access-Control-Allow-Origin['\"],?\s*['\"]?\*" "$f" 2>/dev/null && grep -qE "Access-Control-Allow-Credentials['\"],?\s*['\"]?true" "$f" 2>/dev/null; then
    report "HIGH" "$f" "-" "CORS wildcard combined with credentials"
  fi
done

# TLS verification disabled
if grep -rInE "verify\s*=\s*False|rejectUnauthorized\s*:\s*false|InsecureSkipVerify\s*:\s*true" . --include='*.py' --include='*.js' --include='*.ts' --include='*.go' --exclude-dir={.git,node_modules,vendor,dist,.venv} 2>/dev/null | head -10 | grep -q .; then
  grep -rInE "verify\s*=\s*False|rejectUnauthorized\s*:\s*false|InsecureSkipVerify\s*:\s*true" . --include='*.py' --include='*.js' --include='*.ts' --include='*.go' --exclude-dir={.git,node_modules,vendor,dist,.venv} 2>/dev/null | head -5 | while IFS= read -r line; do
    report "HIGH" "$(cut -d: -f1 <<< "$line")" "$(cut -d: -f2 <<< "$line")" "TLS certificate verification disabled"
  done
fi

# Dangerous sinks
echo
echo "-- Dangerous code sinks --"
SINKS='eval\(|exec\(|os\.system\(|subprocess\.[a-z]+\([^\n]*shell\s*=\s*True|child_process\.exec\(|new Function\(|Runtime\.getRuntime\(\)\.exec'
grep -rInE "$SINKS" . --include='*.py' --include='*.js' --include='*.ts' --include='*.jsx' --include='*.tsx' --exclude-dir={.git,node_modules,vendor,dist,build,.venv,__pycache__} 2>/dev/null | head -15 | while IFS= read -r line; do
  report "MED" "$(cut -d: -f1 <<< "$line")" "$(cut -d: -f2 <<< "$line")" "$(cut -d: -f3- <<< "$line" | sed 's/[[:space:]]\+/ /g' | cut -c1-100)"
done

# Weak hash for passwords
grep -rInE "(md5|sha1)\(.*(password|passwd|pwd)" . --include='*.py' --include='*.js' --include='*.ts' --exclude-dir={.git,node_modules,vendor,dist,.venv} 2>/dev/null | head -5 | while IFS= read -r line; do
  report "HIGH" "$(cut -d: -f1 <<< "$line")" "$(cut -d: -f2 <<< "$line")" "weak hash used with a password"
done

# Math.random for tokens
grep -rInE "Math\.random\(\).*(token|secret|key|nonce|iv)" . --include='*.js' --include='*.ts' --include='*.jsx' --include='*.tsx' --exclude-dir={.git,node_modules,vendor,dist,build} 2>/dev/null | head -5 | while IFS= read -r line; do
  report "HIGH" "$(cut -d: -f1 <<< "$line")" "$(cut -d: -f2 <<< "$line")" "Math.random used for a security value"
done

# --- Security headers -------------------------------------------------------
echo
echo "-- Security headers configured --"
for h in "Content-Security-Policy" "Strict-Transport-Security" "X-Content-Type-Options"; do
  if grep -rIl "$h" . --include='*.js' --include='*.ts' --include='*.py' --include='*.go' --exclude-dir={.git,node_modules,vendor,dist,.venv} 2>/dev/null | grep -q .; then
    echo "  [ok ] $h present"
  else
    echo "  [?? ] $h not found (may be set at the proxy/CDN layer)"
  fi
done

echo
if [ "$findings" -eq 0 ]; then
  echo "Result: no findings from this scan."
  echo "Note: this is a shallow heuristic scan, not a security audit."
  exit 0
else
  echo "Result: $findings potential finding(s) listed above. Review each one manually."
  echo "If a finding is a real secret: rotate it now, then remove it from the code and the git history."
  exit 1
fi
