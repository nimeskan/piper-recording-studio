#!/bin/bash
set -u

OUTPUT_DIR=/app/output
PUSH_INTERVAL="${PUSH_INTERVAL_SECONDS:-180}"
GIT_USER_NAME="${GIT_USER_NAME:-Piper Recording Bot}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-piper-bot@users.noreply.github.com}"

if [ -z "${GIT_DATA_REPO:-}" ] || [ -z "${GIT_DATA_TOKEN:-}" ]; then
  echo "WARNING: GIT_DATA_REPO / GIT_DATA_TOKEN not set -- recordings will NOT be backed up and will be lost on restart." >&2
  AUTH_URL=""
else
  AUTH_URL="https://x-access-token:${GIT_DATA_TOKEN}@github.com/${GIT_DATA_REPO}.git"
fi

setup_output_repo() {
  [ -n "$AUTH_URL" ] || { mkdir -p "$OUTPUT_DIR"; return; }

  rm -rf "$OUTPUT_DIR"
  git clone "$AUTH_URL" "$OUTPUT_DIR"
  git -C "$OUTPUT_DIR" config user.name "$GIT_USER_NAME"
  git -C "$OUTPUT_DIR" config user.email "$GIT_USER_EMAIL"
  # Empty repos have no branch until the first commit; force the name so
  # it matches GitHub's "main" default instead of git's local "master" default.
  git -C "$OUTPUT_DIR" rev-parse --verify HEAD >/dev/null 2>&1 || \
    git -C "$OUTPUT_DIR" symbolic-ref HEAD refs/heads/main
}

push_output_repo() {
  [ -n "$AUTH_URL" ] && [ -d "$OUTPUT_DIR/.git" ] || return 0
  git -C "$OUTPUT_DIR" add -A
  git -C "$OUTPUT_DIR" diff --cached --quiet && return 0
  git -C "$OUTPUT_DIR" commit -m "Recordings backup $(date -u +%Y-%m-%dT%H:%M:%SZ)" --quiet
  git -C "$OUTPUT_DIR" push -u origin HEAD:main --quiet || \
    echo "push failed, will retry next cycle" >&2
}

setup_output_repo

/app/.venv/bin/python3 -m piper_recording_studio --host 0.0.0.0 "$@" &
APP_PID=$!

cleanup() {
  echo "Shutting down, final push..."
  push_output_repo
  kill "$APP_PID" 2>/dev/null
  wait "$APP_PID" 2>/dev/null
  exit 0
}
trap cleanup SIGTERM SIGINT

while kill -0 "$APP_PID" 2>/dev/null; do
  sleep "$PUSH_INTERVAL"
  push_output_repo
done
