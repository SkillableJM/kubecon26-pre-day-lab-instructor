#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# KubeCon AKS capture-the-flag lab - open the event leaderboard to attendees:
# publish its submit URL to the secret gist behind the event's registration
# link, https://aka.ms/aksctfsecrets.
#
# Attendees join from the lab instructions (Get started, Task 6): the lab
# repository's scoring/join-leaderboard.ps1 (or .sh) reads the submit URL from
# the registration link, which points at one file in a secret GitHub gist. So
# a new token needs no change to the lab profile or its instructions: this
# script writes the file with the submit URL from leaderboard/setup
# (.lab/leaderboard/submit-url.txt), and checks that the link serves it. The
# first run creates the secret gist, and prints the address to point the link
# at, once; later runs update the gist that .lab/leaderboard/gist.env records.
# --close publishes "no leaderboard is open"; leaderboard/cleanup does too.
# Needs the GitHub CLI (gh auth login, with the gist scope) and curl.
#
#   ./leaderboard/publish.sh                 # after ./leaderboard/setup.sh
#   ./leaderboard/publish.sh --close         # no new joins
# -----------------------------------------------------------------------------
set -uo pipefail
export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL="*"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/.lab/leaderboard"
GIST_ENV="$OUT_DIR/gist.env"
FILE_NAME=kubecon-ctf-leaderboard.env
SUBMIT_PATTERN='^https://[a-z0-9]{3,24}\.blob\.core\.windows\.net/[a-z0-9-]{3,63}\?[^[:space:]]*sig='
GIST=""
LINK=https://aka.ms/aksctfsecrets
CLOSE=false
WAIT=3

usage() {
  sed -n '3,19p' "$0" | sed 's/^# \{0,1\}//'
  cat <<EOF
Options:
  --gist ID|URL   the gist (default: the one in .lab/leaderboard/gist.env, else a new secret gist)
  --link URL      the registration link that attendees' join script reads (default: $LINK)
  --close         publish "no leaderboard is open" instead of the submit URL
  --wait MINUTES  how long to wait for the link to serve the new file, 0-30 (default: $WAIT);
                  GitHub takes a few seconds to serve a new version. 0 doesn't check the link.
  -h, --help      show this help
EOF
}
stop() { echo "$1" >&2; exit "${2:-1}"; }
need() { [ "$1" -ge 2 ] || stop "$2 needs a value (see --help)" 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --gist)    need $# "$1"; GIST=$2; shift 2 ;;
    --link)    need $# "$1"; LINK=$2; shift 2 ;;
    --close)   CLOSE=true; shift ;;
    --wait)    need $# "$1"; WAIT=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *)         stop "Unknown option $1 (see --help)" 2 ;;
  esac
done
case "$LINK" in https://*) ;; *) stop "--link must start with https://" 2 ;; esac
printf '%s' "$WAIT" | grep -Eq '^([0-9]|[12][0-9]|30)$' || stop "--wait must be 0 to 30" 2

step() { printf '\n==> %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
ok() { printf '    OK  %s\n' "$1"; }
env_value() { [ -f "$1" ] && sed -n "s/^$2=//p" "$1" | tr -d '\r' | head -n 1; }
# A JSON string's contents: escapes backslashes, quotes, and line ends.
json_string() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | awk 'BEGIN { ORS = "\\n" } { print }'; }
# fetch <url>: BODY, STATUS, and FINAL (the address after redirects)
fetch() {
  local out last
  out=$(curl -sSL -m 20 -w '\n%{http_code} %{url_effective}' "$1" 2>/dev/null) || return 1
  last=${out##*$'\n'}
  BODY=${out%$'\n'*}
  STATUS=${last%% *}
  FINAL=${last#* }
}
# read_link <url>: what the registration link serves. STATE is file (VALUE: the submit URL, empty when closed),
# missing (not set up), other, or error.
read_link() {
  STATE=error VALUE="" DETAIL="couldn't read it"
  fetch "$1" || return 0
  if ! printf '%s\n' "$BODY" | grep -q '^CTF_LEADERBOARD_URL=' \
     && printf '%s' "$FINAL" | grep -Eq '^https://gist\.github\.com/[^/?#]+/[0-9a-fA-F]+/?$'; then
    fetch "${FINAL%/}/raw" || return 0
  fi
  # As the join script does: a unique query string reads the newest version, which GitHub doesn't cache.
  if printf '%s' "$FINAL" | grep -Eq '^https://gist\.githubusercontent\.com/[^?#]+$'; then
    fetch "$FINAL?nocache=$RANDOM$RANDOM$(date +%s)" || return 0
  fi
  if printf '%s\n' "$BODY" | grep -q '^CTF_LEADERBOARD_URL='; then
    STATE="file"
    VALUE=$(printf '%s\n' "$BODY" | tr -d '\r' | sed -n 's/^CTF_LEADERBOARD_URL=//p' | head -n 1 | sed 's/[[:space:]]*$//')
  else
    case "$FINAL" in https://www.bing.com/*shorturl=*) STATE=missing ;; *) STATE=other ;; esac
    DETAIL="HTTP $STATUS from $FINAL"
  fi
}

step "Checking prerequisites"
command -v gh >/dev/null 2>&1 || stop "The GitHub CLI (gh) is required: https://cli.github.com"
command -v curl >/dev/null 2>&1 || stop "curl is required"
login=$(gh api user --jq .login 2>/dev/null | tr -d '\r') || stop "The GitHub CLI isn't signed in: run gh auth login"
info "GitHub account $login"
now=$(date -u '+%Y-%m-%d %H:%M')
header="# Read by scoring/join-leaderboard.ps1 and .sh in https://github.com/bbenz/kubecon26-pre-day-lab: never run."
if [ "$CLOSE" = true ]; then
  url=""
  content="$header"$'\n'"# No KubeCon CTF leaderboard is open. Published by leaderboard/publish, $now UTC."
  info "Publishing: no leaderboard is open"
else
  saved="$OUT_DIR/submit-url.txt"
  [ -f "$saved" ] || stop "Run ./leaderboard/setup.sh first: it writes $saved."
  url=$(tr -d '\r\n' < "$saved")
  printf '%s' "$url" | grep -Eq "$SUBMIT_PATTERN" || stop "$saved doesn't have a submit URL: run ./leaderboard/setup.sh again."
  printf '%s' "$url" | grep -Eq '[?&]sp=c(&|$)' || stop "The token must only add results (sp=c): run ./leaderboard/setup.sh again."
  expires=$(env_value "$OUT_DIR/settings.env" LB_TOKEN_EXPIRES)
  if [ -n "$expires" ]; then
    digits=$(printf '%s' "${expires:0:16}" | tr -cd '0-9')
    [ ${#digits} -ge 12 ] || digits=$(printf '%-12s' "$digits" | tr ' ' 0)
    [ "$digits" -gt "$(date -u +%Y%m%d%H%M)" ] || stop "The token expired at $expires UTC: run ./leaderboard/setup.sh to issue a new one."
  fi
  content="$header"$'\n'"# KubeCon CTF leaderboard: a token that can add results, not read them. Expires $expires UTC."
  content="$content"$'\n'"# Published by leaderboard/publish, $now UTC."
  info "Publishing the submit URL from $saved (token expires $expires UTC)"
fi
content="$content"$'\n'"CTF_LEADERBOARD_URL=$url"$'\n'
files="{\"$FILE_NAME\":{\"content\":\"$(json_string "$content")\"}}"

step "Secret gist"
gist_id=""
if [ -n "$GIST" ]; then
  gist_id=$(printf '%s' "$GIST" | grep -Eo '[0-9a-fA-F]{20,}/?$' | tr -d '/')
  [ -n "$gist_id" ] || stop "--gist must be a gist's ID or address: $GIST" 2
else
  gist_id=$(env_value "$GIST_ENV" LB_GIST_ID)
fi
# The request body, which holds the token, goes to gh on standard input: never on a command line.
if [ -n "$gist_id" ]; then
  info_line=$(gh api "gists/$gist_id" --jq '[(.public | tostring), .owner.login, .html_url] | @tsv' 2>&1 | tr -d '\r') \
    || stop "Can't read gist $gist_id with GitHub account $login: $info_line. To start over with a new gist, delete $GIST_ENV, and point the registration link at the new one."
  IFS=$'\t' read -r public owner page <<< "$info_line"
  [ "$public" = false ] || stop "Gist $gist_id is public. Use a secret gist: leave out --gist (and delete $GIST_ENV, if it names this gist), and run this again to create one."
  printf '{"files":%s}' "$files" | gh api -X PATCH "gists/$gist_id" --input - --jq .id >/dev/null \
    || stop "Couldn't update gist $gist_id."
  ok "updated $page"
else
  created=$(printf '{"description":"KubeCon CTF leaderboard registration (see leaderboard/README.md)","public":false,"files":%s}' "$files" \
    | gh api -X POST gists --input - --jq '[.id, .owner.login, .html_url] | @tsv' | tr -d '\r') || stop "Couldn't create a gist."
  IFS=$'\t' read -r gist_id owner page <<< "$created"
  [ -n "$gist_id" ] && [ -n "$owner" ] || stop "Couldn't create a gist."
  ok "created a secret gist: $page"
fi
# The file's address without a revision, so it always serves the latest version.
raw="https://gist.githubusercontent.com/$owner/$gist_id/raw/$FILE_NAME"
mkdir -p "$OUT_DIR"
{
  echo "# Written by leaderboard/publish - the secret gist behind the registration link (no token here)"
  echo "LB_GIST_ID=$gist_id"
  echo "LB_GIST_OWNER=$owner"
  echo "LB_GIST_RAW_URL=$raw"
  echo "LB_REGISTRATION_LINK=$LINK"
} > "$GIST_ENV"
info "File: $raw"

if [ "$WAIT" = 0 ]; then info "Didn't check $LINK (--wait 0)."; exit 0; fi
step "Registration link $LINK"
deadline=$(( $(date +%s) + WAIT * 60 ))
waited=false
while true; do
  read_link "$LINK"
  if [ "$STATE" = file ] && [ "$VALUE" = "$url" ]; then break; fi
  case "$STATE" in
    missing) stop "WARNING: $LINK isn't set up yet. In the aka.ms portal, point it at $raw (once), and then run this script again to check it." ;;
    other)   stop "WARNING: $LINK doesn't serve the gist's file ($DETAIL). Point it at $raw, and then run this script again to check it." ;;
  esac
  if [ "$(date +%s)" -gt "$deadline" ]; then
    if [ "$STATE" = error ]; then what="can't be read"; else what="still serves an earlier version"; fi
    stop "WARNING: $LINK $what after $WAIT minutes. Check that it points at $raw, and run this script again."
  fi
  if [ "$waited" = false ]; then info "Waiting for the link to serve the new version ..."; waited=true; fi
  sleep 10
done
if [ "$CLOSE" = true ]; then ok 'serves "no leaderboard is open": attendees who join now are told so'
else ok "serves the new submit URL: attendees can join (lab instructions, Get started, Task 6)"; fi
