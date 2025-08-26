#!/usr/bin/env bash
# pre-commit: format & lint staged changes (Go + Frontend) + secret scan
# Bypass once: git commit --no-verify
set -euo pipefail

# macOS Bash 3.2 compat: mapfile polyfill (поддерживает -t)
if ! type mapfile >/dev/null 2>&1; then
  mapfile() {
    local opt_t=0
    if [[ "${1:-}" == "-t" ]]; then opt_t=1; shift; fi
    local __arr="$1"; shift
    local i=0 line
    eval "$__arr=()"
    while IFS= read -r line; do
      eval "$__arr[i++]=\$line"
    done
  }
fi

STAGED="$(git diff --name-only --cached --diff-filter=ACMR || true)"
echo "🔎 pre-commit: checking staged changes…"
[[ -z "$STAGED" ]] && { echo "🟢 nothing staged"; exit 0; }

# Fast path: docs/metadata-only → skip code checks
only_docs=true
while IFS= read -r f; do
  case "$f" in
    docs/*|*.md|*.MD|LICENSE|SECURITY.md|CONTRIBUTING.md|CODEOWNERS|.github/pull_request_template.md|README.md) : ;;
    *) only_docs=false ;;
  esac
done <<< "$STAGED"
$only_docs && { echo "📝 Docs-only changes → skipping code checks."; echo "✅ pre-commit OK"; exit 0; }

# --- Go: format + lint on changed dirs ---
declare -a go_files=() fmt_list=() go_dirs=() go_pkgs=()
mapfile -t go_files < <(echo "$STAGED" | grep -E '\.go$' || true)
if (( ${#go_files[@]} > 0 )) && command -v go >/dev/null 2>&1; then
  echo "🐹 Go: gofmt…"
  gofmt -l "${go_files[@]}" | tee /tmp/gofmt.out || true
  if [ -s /tmp/gofmt.out ]; then
    mapfile -t fmt_list < /tmp/gofmt.out
    if (( ${#fmt_list[@]} > 0 )); then
      gofmt -w "${fmt_list[@]}"
      git add "${fmt_list[@]}"
      echo "  ↳ formatted & re-staged."
    fi
  fi

  if command -v golangci-lint >/dev/null 2>&1; then
    mapfile -t go_dirs < <(printf "%s\n" "${go_files[@]}" | xargs -n1 dirname | sort -u)
    echo "🐹 Go: golangci-lint on ${#go_dirs[@]} dir(s)…"
    golangci-lint run --timeout=3m "${go_dirs[@]}"
  else
    echo "ℹ️ golangci-lint not found → running go vet…"
    # 1) пытаемся вычислить пакеты из изменённых директорий
    mapfile -t go_dirs < <(printf "%s\n" "${go_files[@]}" | xargs -n1 dirname | sort -u)
    if (( ${#go_dirs[@]} > 0 )); then
      set +e
      mapfile -t go_pkgs < <(go list "${go_dirs[@]}" 2>/dev/null)
      rc=$?
      set -e
      if (( rc == 0 )) && (( ${#go_pkgs[@]} > 0 )); then
        echo "🐹 go vet ${#go_pkgs[@]} pkg(s)…"
        go vet "${go_pkgs[@]}"
      elif [ -f go.mod ]; then
        # 2) fallback — если в корне есть модуль
        echo "🐹 go vet ./... (repo root module)…"
        go vet ./...
      else
        # 3) иначе мягко скипаем
        echo "   ↳ No Go module found for changed files; skipping go vet."
      fi
    fi
  fi
fi


# --- Frontend: run inside changed app dirs (apps/*) ---
declare -a fe_changed=() files_in_dir=()
mapfile -t fe_changed < <(echo "$STAGED" \
  | grep -E '^(apps/[^/]+/).*\.(jsx?|tsx?|css|scss|json|ya?ml|md|html|mjs|cjs)$' \
  | awk -F/ '{print $1"/"$2}' | sort -u || true)

if (( ${#fe_changed[@]} > 0 )); then
  for dir in "${fe_changed[@]}"; do
    [ -f "$dir/package.json" ] || continue
    echo "🌐 FE: prettier + lint in $dir …"

    files_in_dir=()
    mapfile -t files_in_dir < <(echo "$STAGED" \
      | grep -E "^${dir}/.*\.(jsx?|tsx?|css|scss|json|ya?ml|md|html|mjs|cjs)$" \
      | sed -E "s#^${dir}/##" || true)
    (( ${#files_in_dir[@]} == 0 )) && continue

    # Prettier (soft) + re-stage
    if command -v npx >/dev/null 2>&1; then
      (cd "$dir" && npx --yes prettier -w "${files_in_dir[@]}") || true
      for f in "${files_in_dir[@]}"; do git add "$dir/$f"; done
    fi

    # Lint (blocking)
    if command -v pnpm >/dev/null 2>&1; then
      (cd "$dir" && pnpm -s lint)
    elif command -v yarn >/dev/null 2>&1; then
      (cd "$dir" && yarn -s lint)
    elif command -v npm  >/dev/null 2>&1; then
      (cd "$dir" && npm run -s lint --if-present)
    else
      echo "ℹ️ No Node package manager found → skipping FE lint in $dir"
    fi
  done
fi

# --- Secrets: staged diff scan (if available) ---
if command -v gitleaks >/dev/null 2>&1; then
  echo "🔐 gitleaks (staged)…"
  gitleaks protect --staged --no-banner
else
  echo "ℹ️ gitleaks not found → skipping secret scan."
fi

echo "✅ pre-commit OK"

