#!/usr/bin/env bash
# PlatformIO build selector: batches ESP32 once, then nRF52 once with create_uf2.
set -euo pipefail
cd "$(cd "$(dirname "$0")" && pwd)"
search= all=0 pio="${PIO:-}"; requested=()
usage(){ cat <<'EOF'
Usage: build-firmwares.sh [--search TAG] [--env ENV]... [--all] [--pio PATH]
No --env/--all opens a searchable numbered selector. Output files are copied to
this project directory as ENV.bin and/or ENV.uf2.
EOF
}
while (($#)); do case "$1" in
  --search|--env|--pio) [[ $# -ge 2 && -n "$2" && "$2" != --* ]] || { echo "Missing value for $1" >&2; exit 2; }; case "$1" in --search) search="$2";; --env) requested+=("$2");; --pio) pio="$2";; esac; shift 2;; --all) all=1; shift;;
  -h|--help) usage; exit 0;; *) echo "Unknown option: $1" >&2; exit 2;; esac; done
if [[ -z "$pio" ]]; then [[ -x .venv/bin/pio ]] && pio=.venv/bin/pio || pio=$(command -v pio || true); fi
[[ -n "$pio" ]] || { echo 'PlatformIO not found; pass --pio PATH.' >&2; exit 127; }
command -v python3 >/dev/null || { echo "Python 3 is required." >&2; exit 127; }
config=$("$pio" project config --json-output) || { echo "Failed to read PlatformIO project configuration." >&2; exit 1; }
env_data=$(printf '%s\n' "$config" | python3 -c '
import json,sys
for s,p in json.load(sys.stdin):
 if s.startswith("env:"):
  c=dict(p); x=(" ".join(c.get("build_flags",[]))+" "+str(c.get("platform",""))+" "+str(c.get("board",""))).lower()
  f="nrf52" if "nrf52" in x else "esp32" if "esp32" in x or "espressif32" in x else ""
  if f: print(s[4:]+"\t"+f)
') || { echo 'Failed to parse PlatformIO project configuration.' >&2; exit 1; }
envs=(); [[ -z "$env_data" ]] || mapfile -t envs <<< "$env_data"
filter(){ filtered=(); local r n needle="${1,,}"; for r in "${envs[@]}"; do n="${r%%$'\t'*}"; [[ -z "$needle" || "${n,,}" == *"$needle"* ]] && filtered+=("$r"); done; return 0; }
select_menu(){ local answer token a b i; while :; do
 filter "$search"; [[ "${#filtered[@]}" -gt 0 ]] || { echo 'No ESP32/nRF52 environments match.'; read -r -p 'Search: ' search || exit 0; continue; }
 echo; echo "Search/build tag: [${search:-all}]"; for i in "${!filtered[@]}"; do printf ' %2d) %-58s %s\n' "$((i+1))" "${filtered[i]%%$'\t'*}" "${filtered[i]##*$'\t'}"; done
 read -r -p 'Choose numbers/ranges, all, search, or q: ' answer || exit 0; [[ "$answer" == q ]] && exit 0
 if [[ "$answer" == search ]]; then read -r -p 'Search/build tag: ' search || exit 0; continue; fi
 selected=(); if [[ "$answer" == all ]]; then selected=("${filtered[@]}"); else IFS=, read -ra tokens <<< "$answer"; for token in "${tokens[@]}"; do
  token="${token// /}"; if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then a="${BASH_REMATCH[1]}"; b="${BASH_REMATCH[2]}"; if ((10#$a < 1 || 10#$b < 10#$a || 10#$b > ${#filtered[@]})); then echo "Invalid: $token"; selected=(); break; fi; for ((i=10#$a;i<=10#$b;i++)); do selected+=("${filtered[i-1]}"); done
  elif [[ "$token" =~ ^[0-9]+$ ]] && ((10#$token >= 1 && 10#$token <= ${#filtered[@]})); then selected+=("${filtered[10#$token-1]}"); else echo "Invalid: $token"; selected=(); break; fi; done; fi
 [[ "${#selected[@]}" -gt 0 ]] && return; done; }
if [[ "${#requested[@]}" -gt 0 ]]; then selected=(); for want in "${requested[@]}"; do hit=0; for r in "${envs[@]}"; do [[ "${r%%$'\t'*}" == "$want" ]] && { selected+=("$r"); hit=1; }; done; [[ $hit == 1 ]] || { echo "Unknown/unsupported: $want" >&2; exit 2; }; done
elif [[ $all == 1 ]]; then filter "$search"; selected=("${filtered[@]}"); else select_menu; fi
[[ "${#selected[@]}" -gt 0 ]] || { echo 'No firmwares selected.'; exit 0; }
esp=() nrf=(); for r in "${selected[@]}"; do [[ "${r##*$'\t'}" == esp32 ]] && esp+=("${r%%$'\t'*}") || nrf+=("${r%%$'\t'*}"); done
failed=0
build(){ local family="$1"; shift; [[ $# -gt 0 ]] || return 0; echo "=== $family batch: $* ==="; args=(run -j 1); local e; for e in "$@"; do args+=(-e "$e"); done; [[ "$family" == nRF52 ]] && args+=(-t create_uf2); if ! "$pio" "${args[@]}"; then echo "$family batch failed; no artifacts copied from this batch." >&2; failed=1; return; fi; local ext=bin; [[ "$family" == nRF52 ]] && ext=uf2; for e in "$@"; do if [[ -f .pio/build/"$e"/firmware."$ext" ]]; then cp -f .pio/build/"$e"/firmware."$ext" "$e.$ext"; echo "Copied $e.$ext"; else echo "Missing artifact: .pio/build/$e/firmware.$ext" >&2; failed=1; fi; done; }
build ESP32 "${esp[@]}"; build nRF52 "${nrf[@]}"; exit "$failed"
