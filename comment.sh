#!/usr/bin/env bash
# Posts the result on the pull request, or updates the comment Sightline posted there before.
# Inputs (environment): GH_TOKEN, PR, REPO, FILE.
set -euo pipefail

marker='<!-- sightline-map-diff -->'
body="$FILE"

# A comment holds at most 65536 characters. A very large change keeps its first part there;
# the job summary has all of it.
if [ "$(wc -c < "$FILE")" -gt 60000 ]; then
  body="${RUNNER_TEMP:-/tmp}/sightline-comment.md"
  { head -c 60000 "$FILE" | sed '$d'; printf '\n\n*The rest is in the job summary.*\n'; } > "$body"
fi

post() {
  local id
  id=$(gh api "repos/$REPO/issues/$PR/comments" --paginate --jq ".[] | select(.body | startswith(\"$marker\")) | .id" | tail -n 1) || return 1
  if [ -n "$id" ]; then
    gh api -X PATCH "repos/$REPO/issues/comments/$id" -F "body=@$body" > /dev/null || return 1
    echo "Updated the Sightline comment on #$PR."
  else
    gh pr comment "$PR" --repo "$REPO" --body-file "$body" || return 1
  fi
}

# Pull requests from forks get a read-only token, so this cannot work there. The check carries on.
if ! post; then
  echo "::warning title=Sightline::Could not comment on the pull request. The job needs the \"pull-requests: write\" permission, which pull requests from forks do not get. The job summary has the result."
fi
