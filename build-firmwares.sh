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
  --search) search="$2"; shift 2;; --env) requested+=("$2"); shift 2;; --all) all=1; shift;;
  --pio) pio="$2"; shift 2;; -h|--help) usage; exit 0;; *) echo "Unknown option: $1" >&2; exit 2;; esac; done
if [[ -z "$pio" ]]; then [[ -x .venv/bin/pio ]] && pio=.venv/bin/pio || pio=$(command -v pio || true); fi
[[ -n "$pio" ]] || { echo 'PlatformIO not found; pass --pio PATH.' >&2; exit 127; }
mapfile -t envs < <("$pio" project config --json-output | python3 -c '
import json,sys
for s,p in json.load(sys.stdin):
 if s.startswith("env:"):
  c=dict(p); x=(" ".join(c.get("build_flags",[]))+" "+str(c.get("platform",""))+" "+str(c.get("board",""))).lower()
  f="nrf52" if "nrf52" in x else "esp32" if "esp32" in x or "espressif32" in x else ""
  if f: print(s[4:]+"\\t"+f)
')
filter(){ filtered=(); local r n needle="${1,,}"; for r in "${envs[@]}"; do n="${r%%$'\\t'*}"; [[ -z "$needle" || "${n,,}" == *"$needle"* ]] && filtered+=("$r"); done; return 0; }
select_menu(){ local answer token a b i; while :; do
 filter "$search"; [[ "${#filtered[@]}" -gt 0 ]] || { echo 'No ESP32/nRF52 environments match.'; read -r -p 'Search: ' search; continue; }
 echo; echo "Search/build tag: [${search:-all}]"; for i in "${!filtered[@]}"; do printf ' %2d) %-58s %s\\n' "$((i+1))" "${filtered[i]%%$'\\t'*}" "${filtered[i]##*$'\\t'}"; done
 read -r -p 'Choose numbers/ranges, all, search, or q: ' answer || exit 0; [[ "$answer" == q ]] && exit 0
 if [[ "$answer" == search ]]; then read -r -p 'Search/build tag: ' search; continue; fi
 selected=(); if [[ "$answer" == all ]]; then selected=("${filtered[@]}"); else IFS=, read -ra tokens <<< "$answer"; for token in "${tokens[@]}"; do
  token="${token// /}"; if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then a="${BASH_REMATCH[1]}"; b="${BASH_REMATCH[2]}"; for ((i=a;i<=b;i++)); do [[ ${filtered[i-1]+x} ]] && selected+=("${filtered[i-1]}"); done
  elif [[ "$token" =~ ^[0-9]+$ && ${filtered[token-1]+x} ]]; then selected+=("${filtered[token-1]}"); else echo "Invalid: $token"; selected=(); break; fi; done; fi
 [[ "${#selected[@]}" -gt 0 ]] && return; done; }
if [[ "${#requested[@]}" -gt 0 ]]; then selected=(); for want in "${requested[@]}"; do hit=0; for r in "${envs[@]}"; do [[ "${r%%$'\\t'*}" == "$want" ]] && { selected+=("$r"); hit=1; }; done; [[ $hit == 1 ]] || { echo "Unknown/unsupported: $want" >&2; exit 2; }; done
elif [[ $all == 1 ]]; then filter "$search"; selected=("${filtered[@]}"); else select_menu; fi
[[ "${#selected[@]}" -gt 0 ]] || { echo 'No firmwares selected.'; exit 0; }
esp=() nrf=(); for r in "${selected[@]}"; do [[ "${r##*$'\\t'}" == esp32 ]] && esp+=("${r%%$'\\t'*}") || nrf+=("${r%%$'\\t'*}"); done
failed=0
build(){ local family="$1"; shift; [[ $# -gt 0 ]] || return; echo "=== $family batch: $* ==="; args=(run); local e; for e in "$@"; do args+=(-e "$e"); done; [[ "$family" == nRF52 ]] && args+=(-t create_uf2); "$pio" "${args[@]}" || failed=1; for e in "$@"; do for ext in bin uf2; do [[ -f .pio/build/"$e"/firmware."$ext" ]] && { cp -f .pio/build/"$e"/firmware."$ext" "$e.$ext"; echo "Copied $e.$ext"; }; done; done; }
build ESP32 "${esp[@]}"; build nRF52 "${nrf[@]}"; exit "$failed"
