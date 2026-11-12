#!/usr/bin/env bash
# Compares the map of the pull request with the map of its base commit, using "sightline diff".
# Inputs (environment): BASE, SOLUTION, VERSION, COMMAND, FAIL_ON.
# Outputs: markdown (the result file) and failed (true when the pull request adds problems at FAIL_ON).
set -euo pipefail

if [ -z "${BASE:-}" ]; then
  echo "::error title=Sightline::This action compares a pull request with its base commit, so it runs on pull_request events."
  exit 1
fi

temp="${RUNNER_TEMP:-/tmp}"

# "sightline diff --base" checks the base commit out next to the working tree, so the commit has to be here.
# actions/checkout fetches only the pull request itself by default.
where="."
if [ -n "${SOLUTION:-}" ]; then
  if [ -d "$SOLUTION" ]; then where="$SOLUTION"; else where=$(dirname "$SOLUTION"); fi
fi
if ! git -C "$where" cat-file -e "$BASE^{commit}" 2> /dev/null; then
  depth=()
  if [ "$(git -C "$where" rev-parse --is-shallow-repository)" = true ]; then depth=(--depth=1); fi
  git -C "$where" fetch --no-tags ${depth[@]+"${depth[@]}"} origin "$BASE" || true
fi

if [ -n "${COMMAND:-}" ]; then
  read -ra run <<< "$COMMAND"
else
  # Installed from outside the repository, so its global.json and nuget.config do not decide
  # which SDK installs the tool or where it comes from.
  tools="$temp/sightline-${VERSION:-latest}"
  if [ ! -e "$tools/sightline" ] && [ ! -e "$tools/sightline.exe" ]; then
    version=()
    if [ -n "${VERSION:-}" ]; then version=(--version "$VERSION"); fi
    if ! (cd "$temp" && dotnet tool install Co.Revington.Sightline --tool-path "$tools" ${version[@]+"${version[@]}"}); then
      echo "::error title=Sightline::Could not install Sightline ${VERSION:-} from nuget.org."
      exit 1
    fi
  fi
  run=("$tools/sightline")
fi

args=(diff)
if [ -n "${SOLUTION:-}" ]; then args+=("$SOLUTION"); fi

out="$temp/sightline-map.md"
rm -f "$out"
set +e
"${run[@]}" "${args[@]}" --base "$BASE" --format markdown --out "$out" --fail-on "${FAIL_ON:-never}"
code=$?
set -e

# 0: compared. 1: compared, and the pull request adds problems at FAIL_ON. Anything else: it could not compare.
if [ "$code" -gt 1 ] || [ ! -f "$out" ]; then
  echo "::error title=Sightline::Sightline could not compare the maps (exit code $code). The log above says why."
  exit 1
fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat "$out" >> "$GITHUB_STEP_SUMMARY"; fi
{
  echo "markdown=$out"
  if [ "$code" -eq 1 ]; then echo "failed=true"; else echo "failed=false"; fi
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
