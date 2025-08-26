#!/usr/bin/env bash
# Husky pre-push hook for a Go + Frontend monorepo
# Skips on docs-only, checks selectively by changed areas.
# Bypass if needed: `git push --no-verify` or `HUSKY=0 git push`
# Allow pushing to main once: `ALLOW_MAIN_PUSH=1 git push`

set -euo pipefail

# macOS Bash 3.2 compat: mapfile polyfill
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

remote_name="${1:-}"
remote_url="${2:-}"

# Collect refs from stdin (local_ref local_sha remote_ref remote_sha)
pushed_lines=()
while read -r local_ref local_sha remote_ref remote_sha; do
  pushed_lines+=("$local_ref $local_sha $remote_ref $remote_sha")
done || true

# 1) Block direct pushes to main unless explicitly allowed
for line in "${pushed_lines[@]}"; do
  read -r _local_ref _local_sha _remote_ref _remote_sha <<<"$line"
  if [[ "${_remote_ref:-}" == "refs/heads/main" && "${ALLOW_MAIN_PUSH:-0}" != "1" ]]; then
    echo "❌ Direct push to 'main' is blocked. Open a PR instead. (set ALLOW_MAIN_PUSH=1 to override once)"
    exit 1
  fi
done

# 2) Figure out diff (handles first push)
branch="$(git rev-parse --abbrev-ref HEAD)"
head="HEAD"

diff_names() {
  if git rev-parse --verify --quiet "origin/$branch" >/dev/null; then
    git diff --name-only --diff-filter=ACMR "origin/$branch...$head"
  else
    git diff --name-only --diff-filter=ACMR --root "$head"
  fi
}

log_range() {
  if git rev-parse --verify --quiet "origin/$branch" >/dev/null; then
    printf "origin/%s..%s" "$branch" "$head"
  else
    first="$(git rev-list --max-parents=0 "$head" | tail -n1)"
    printf "%s..%s" "$first" "$head"
  fi
}

# Changed files (added/copied/modified/renamed)
CHANGED="$(diff_names || true)"
if [ -z "$CHANGED" ]; then
  echo "🟢 Nothing changed to validate."
  exit 0
fi

# 3) Classify changes
only_docs=true
ci_changed=false
go_changed=false
frontend_changed=false
docker_changed=false
migrations_changed=false
contracts_changed=false

while IFS= read -r f; do
  # docs/meta
  if [[ "$f" =~ (^docs/|\.md$|^LICENSE$|^SECURITY\.md$|^CONTRIBUTING\.md$|^CODEOWNERS$|^\.github/pull_request_template\.md$|^README\.md$) ]]; then
    :
  else
    only_docs=false
  fi
  [[ "$f" =~ ^\.github/workflows/ ]] && ci_changed=true
  [[ "$f" =~ \.go$|^go\.mod$|^go\.sum$|^services/|^internal/|^cmd/|^libs/ ]] && go_changed=true
  [[ "$f" =~ (^apps/|^web/|^frontend/|package\.json$|pnpm-lock\.yaml$|yarn\.lock$|package-lock\.json$|tsconfig\.json$) ]] && frontend_changed=true
  [[ "$f" =~ (^|/)Dockerfile|^Dockerfile\.svc$|^docker-compose.*\.ya?ml$ ]] && docker_changed=true
  [[ "$f" =~ ^migrations/ ]] && migrations_changed=true
  [[ "$f" =~ (^idl/|\.proto$|openapi\.ya?ml$|openapi\.json$) ]] && contracts_changed=true
done <<< "$CHANGED"

# 4) Docs-only → skip fast
if $only_docs; then
  echo "📝 Docs/metadata-only changes → skipping checks."
  exit 0
fi

# 5) Quick secret scan on the pushed range (if available)
if command -v gitleaks >/dev/null 2>&1; then
  range="$(log_range)"
  echo "🔍 gitleaks (range $range)…"
  gitleaks detect --no-banner --log-opts "$range" || {
    echo "❌ Secrets detected by gitleaks. Please fix (or add allowlist where appropriate)."
    exit 1
  }
else
  echo "ℹ️ gitleaks not found → skipping secret scan."
fi

# 6) Warn on very large newly added/modified files (outside Git LFS)
MAX_FILE_MB="${MAX_FILE_MB:-10}"
LARGE=()
while IFS= read -r f; do
  [ -f "$f" ] || continue
  size_bytes=$(wc -c < "$f" 2>/dev/null || echo 0)
  size_mb=$(( (size_bytes + 1024*1024 - 1) / (1024*1024) ))
  if [ "$size_mb" -ge "$MAX_FILE_MB" ]; then
    LARGE+=("$f (${size_mb}MB)")
  fi
done <<< "$CHANGED"
if [ "${#LARGE[@]}" -gt 0 ]; then
  echo "⚠️  Large files detected (>${MAX_FILE_MB}MB):"
  printf '   - %s\n' "${LARGE[@]}"
  echo "    Consider Git LFS or shrinking them."
fi

# 7) CI/workflow YAML lint
if $ci_changed; then
  if command -v actionlint >/dev/null 2>&1; then
    echo "🧪 actionlint .github/workflows …"
    actionlint
  elif command -v yamllint >/dev/null 2>&1; then
    echo "🧪 yamllint .github/workflows …"
    yamllint -s .github/workflows || true
  else
    echo "ℹ️ actionlint/yamllint not found → skipping workflow lint."
  fi
fi

# 8) Go smoke checks (vet + build for changed packages)
if $go_changed; then
  if command -v go >/dev/null 2>&1; then
    echo "🐹 Go: collecting changed packages…"

    # Собираем директории, где поменялись .go
    mapfile -t go_dirs < <(
      echo "$CHANGED" | grep -E '\.go$' \
      | awk -F/ '{
          out="";
          for (i=1;i<NF;i++){ out = (out?out"/":"") $i }
          if(out!="") print out
        }' | sort -u
    )

    # Пробуем получить import-пакеты из этих директорий
    rc=1
    go_pkgs=()
    if [ "${#go_dirs[@]}" -gt 0 ]; then
      set +e
      mapfile -t go_pkgs < <(go list "${go_dirs[@]}" 2>/dev/null)
      rc=$?
      set -e
    fi

    if [ $rc -eq 0 ] && [ "${#go_pkgs[@]}" -gt 0 ]; then
      echo "🐹 go vet ${#go_pkgs[@]} pkg(s)…"
      go vet "${go_pkgs[@]}"
      echo "🐹 go build (type-check) ${#go_pkgs[@]} pkg(s)…"
      CGO_ENABLED=0 go build "${go_pkgs[@]}"
    elif [ -f go.mod ]; then
      echo "🐹 go vet ./... (repo root module)…"
      go vet ./...
      echo "🐹 go build ./... (repo root module)…"
      CGO_ENABLED=0 go build ./...
    else
      echo "ℹ️ No Go module found for changed files and no root go.mod → skipping Go checks."
    fi
  else
    echo "ℹ️ 'go' tool not found → skipping Go checks."
  fi
fi

# 9) Frontend checks (lint + typecheck) for changed workspaces
if $frontend_changed; then
  echo "🌐 Frontend: lint/typecheck…"
  roots=(".")
  mapfile -t fdirs < <(echo "$CHANGED" | grep -E '^(apps/|web/|frontend/)' \
    | awk -F/ '{print $1"/"$2}' | sort -u)
  roots+=("${fdirs[@]}")
  # de-duplicate (portable)
  unique_roots=$(printf "%s\n" "${roots[@]}" | awk '!seen[$0]++')

  for dir in $unique_roots; do
    [ -d "$dir" ] || continue
    [ -f "$dir/package.json" ] || continue
    echo "  • $dir"
    if [ -f "$dir/pnpm-lock.yaml" ] && command -v pnpm >/dev/null 2>&1; then
      (cd "$dir" && pnpm -s lint || true)
    elif [ -f "$dir/yarn.lock" ] && command -v yarn >/dev/null 2>&1; then
      (cd "$dir" && yarn -s lint || true)
    elif command -v npm >/dev/null 2>&1; then
      (cd "$dir" && npm run -s lint --if-present || true)
    else
      echo "   ↳ No Node package manager found → skipping lint in $dir"
    fi
    # TypeScript typecheck if tsconfig exists
    if [ -f "$dir/tsconfig.json" ]; then
      if command -v pnpm >/dev/null 2>&1; then
        (cd "$dir" && pnpm -s dlx tsc --noEmit) || true
      elif command -v npx >/dev/null 2>&1; then
        (cd "$dir" && npx --yes tsc --noEmit) || true
      else
        echo "   ↳ No npx/pnpm to run tsc → skipping typecheck in $dir"
      fi
    fi
  done
fi

# 10) Dockerfile lint (portable)
if $docker_changed; then
  if command -v hadolint >/dev/null 2>&1; then
    echo "🐳 hadolint Dockerfiles…"
    mapfile -t dockerfiles < <(echo "$CHANGED" | grep -E '(^|/)Dockerfile|^Dockerfile\.svc$' || true)
    if [ "${#dockerfiles[@]}" -gt 0 ]; then
      hadolint "${dockerfiles[@]}"
    fi
  else
    echo "ℹ️ hadolint not found → skipping Dockerfile lint."
  fi
fi

# 11) Optional hints
if $migrations_changed; then
  echo "ℹ️ Migrations changed — ensure you added matching *.down.sql and proper timestamp prefixes."
fi
if $contracts_changed; then
  echo "ℹ️ Contracts changed — consider running 'spectral lint' (OpenAPI) or 'buf lint' (Protobuf) locally."
fi

echo "✅ pre-push OK"
