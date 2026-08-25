#!/usr/bin/env bash
# poll-issue.sh — the "radio" for a multi-agent session.
#
# Two modes:
#   init  <issue> <identity> <repo> <watermark_file>
#         Mark all EXISTING comments as already seen. Run once at start so you
#         do not reprocess history. Prints the watermark it set.
#
#   watch <issue> <identity> <repo> <watermark_file> [interval_s] [max_wait_s]
#         Block and poll. Return only when there is real mail for you, or a
#         SESSION DONE, or max_wait elapses. Zero LLM tokens spent while waiting.
#
# Exit codes for watch:
#   0  = new mail for you (printed). Act on it, then run watch again.
#   42 = SESSION DONE seen (printed). Stop the loop, sign off, wait for human.
#   10 = nothing after max_wait. Just run watch again to keep listening.
#
# Filtering (text-based, because every agent shares one GitHub login):
#   - A comment is "for you" if its body contains @<identity> or @all.
#   - A comment from you is skipped: it starts with "<identity>:".
#   - Plain acks addressed to you still return; YOU decide if they need action.

set -euo pipefail

MODE="${1:-}"
ISSUE="${2:-}"
IDENTITY="${3:-}"
REPO="${4:-}"
WM_FILE="${5:-}"
INTERVAL="${6:-45}"
MAX_WAIT="${7:-540}"   # keep under the 600s Bash timeout

if [ -z "$MODE" ] || [ -z "$ISSUE" ] || [ -z "$IDENTITY" ] || [ -z "$REPO" ] || [ -z "$WM_FILE" ]; then
  echo "usage: poll-issue.sh init|watch <issue> <identity> <repo> <watermark_file> [interval_s] [max_wait_s]" >&2
  exit 2
fi

fetch_comments() {
  gh issue view "$ISSUE" --repo "$REPO" --json comments -q '.comments' 2>/dev/null || echo '[]'
}

if [ "$MODE" = "init" ]; then
  NEWEST="$(fetch_comments | jq -r 'if length == 0 then "" else (max_by(.createdAt) | .createdAt) end')"
  echo "$NEWEST" > "$WM_FILE"
  echo "watermark set to: ${NEWEST:-<none, empty issue>}"
  exit 0
fi

if [ "$MODE" != "watch" ]; then
  echo "unknown mode: $MODE (use init or watch)" >&2
  exit 2
fi

WM=""
[ -f "$WM_FILE" ] && WM="$(cat "$WM_FILE")"

elapsed=0
while :; do
  COMMENTS="$(fetch_comments)"
  NEW="$(echo "$COMMENTS" | jq --arg wm "$WM" '[.[] | select(.createdAt > $wm)]')"
  COUNT="$(echo "$NEW" | jq 'length')"

  if [ "$COUNT" -gt 0 ]; then
    NEWEST="$(echo "$NEW" | jq -r 'max_by(.createdAt) | .createdAt')"

    STOP="$(echo "$NEW" | jq '[.[] | select(.body | test("SESSION DONE"))] | length')"

    MAIL="$(echo "$NEW" | jq --arg id "$IDENTITY" '
      [ .[]
        | select( (.body | test("@" + $id + "\\b"; "i")) or (.body | test("@all\\b"; "i")) )
        | select( (.body | test("^\\s*" + $id + "\\s*:"; "i")) | not )
      ]')"
    MAILCOUNT="$(echo "$MAIL" | jq 'length')"

    if [ "$STOP" -gt 0 ]; then
      echo "=== SESSION DONE received ==="
      echo "$NEW" | jq -r '.[] | "[" + .createdAt + "]\n" + .body + "\n"'
      echo "$NEWEST" > "$WM_FILE"
      exit 42
    fi

    if [ "$MAILCOUNT" -gt 0 ]; then
      echo "=== New mail for $IDENTITY ==="
      echo "$MAIL" | jq -r '.[] | "[" + .createdAt + "]\n" + .body + "\n"'
      echo "$NEWEST" > "$WM_FILE"
      exit 0
    fi

    # Only comments not addressed to us (or our own). Mark seen, keep waiting.
    echo "$NEWEST" > "$WM_FILE"
    WM="$NEWEST"
  fi

  if [ "$elapsed" -ge "$MAX_WAIT" ]; then
    echo "=== No mail after ${MAX_WAIT}s. Run watch again to keep listening. ==="
    exit 10
  fi

  sleep "$INTERVAL"
  elapsed=$((elapsed + INTERVAL))
done
