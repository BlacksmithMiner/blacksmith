#!/usr/bin/env bash
. /hive/miners/custom/${CUSTOM_MINER:-blacksmith-hiveos}/h-manifest.conf

khs=0
stats=""

local feed="$CUSTOM_LOG_BASENAME.jsonl"
local cards="${GPU_COUNT_NVIDIA:-0}"
(( cards < 1 )) && cards=$(gpu-detect NVIDIA 2>/dev/null)
(( cards < 1 )) && cards=1

[[ -f $feed ]] || return
local seen=0
seen=$(stat -c %Y "$feed" 2>/dev/null || echo 0)
(( $(date +%s) - seen > 90 )) && return

local row
row=$(grep -a '"event":"pool_stats"' "$feed" | tail -n1)
[[ -z $row ]] && row=$(grep -a '"event":"pool_final"' "$feed" | tail -n1)
[[ -z $row ]] && return

local rate acc rej
rate=$(jq -r 'try (.ep_s_window // .ep_s // 0) catch 0' <<< "$row" 2>/dev/null)
acc=$(jq -r  'try (.accepted // 0) catch 0'            <<< "$row" 2>/dev/null)
rej=$(jq -r  'try (.rejected // 0) catch 0'            <<< "$row" 2>/dev/null)
[[ $rate =~ ^[0-9.]+$ ]] || rate=0
[[ $acc  =~ ^[0-9]+$   ]] || acc=0
[[ $rej  =~ ^[0-9]+$   ]] || rej=0

local total per hs
total="$rate"
per=$(awk -v t="$total" -v n="$cards" 'BEGIN{printf "%.6f", t/n}')
hs=$(jq -nc --argjson p "$per" --argjson n "$cards" '[range($n) | $p]')

local temp fan bus
temp=$(jq -c "[.temp$nvidia_indexes_array]"   <<< "$gpu_stats" 2>/dev/null); [[ -z $temp || $temp == null ]] && temp='[]'
fan=$(jq -c  "[.fan$nvidia_indexes_array]"    <<< "$gpu_stats" 2>/dev/null); [[ -z $fan  || $fan  == null ]] && fan='[]'
bus=$(jq -c  "[.busids$nvidia_indexes_array]" <<< "$gpu_stats" 2>/dev/null); [[ -z $bus  || $bus  == null ]] && bus='[]'

local secs=0 proc
proc=$(pgrep -f 'blacksmith-forge' | head -n1)
[[ -n $proc ]] && secs=$(( $(date +%s) - $(date +%s -d "$(ps -o lstart= -p "$proc" 2>/dev/null)" 2>/dev/null || date +%s) ))

khs=$(awk -v t="$total" 'BEGIN{printf "%.6f", t/1000}')
stats=$(jq -nc \
    --argjson hs "$hs" --argjson temp "$temp" --argjson fan "$fan" --argjson bus "$bus" \
    --arg up "$secs" --arg ver "$CUSTOM_VERSION" --arg a "$acc" --arg r "$rej" \
    '{hs:$hs, hs_units:"hs", temp:$temp, fan:$fan, bus_numbers:$bus,
      uptime:($up|tonumber), ver:$ver, ar:[($a|tonumber),($r|tonumber)], algo:"blacksmith"}')
