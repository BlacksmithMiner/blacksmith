#!/usr/bin/env bash
. /hive/miners/custom/${CUSTOM_MINER:-blacksmith-hiveos}/h-manifest.conf

khs=0
stats=""

local logfile="$CUSTOM_LOG_BASENAME.log"
local cards="${GPU_COUNT_NVIDIA:-0}"
(( cards < 1 )) && cards=$(gpu-detect NVIDIA 2>/dev/null)
(( cards < 1 )) && cards=1

[[ -f $logfile ]] || return
local seen_at=0
seen_at=$(stat -c %Y "$logfile" 2>/dev/null || echo 0)
(( $(date +%s) - seen_at > 90 )) && return

local row
row=$(grep -a '"event":"pool_stats"' "$logfile" | tail -n1)
[[ -z $row ]] && row=$(grep -a '"event":"pool_final"' "$logfile" | tail -n1)
[[ -z $row ]] && return

local rate acc rej
rate=$(jq -r 'try (.ep_s_window // .ep_s // 0) catch 0' <<< "$row" 2>/dev/null)
acc=$(jq -r  'try (.accepted // 0) catch 0'            <<< "$row" 2>/dev/null)
rej=$(jq -r  'try (.rejected // 0) catch 0'            <<< "$row" 2>/dev/null)
[[ $rate =~ ^[0-9.]+$ ]] || rate=0
[[ $acc  =~ ^[0-9]+$   ]] || acc=0
[[ $rej  =~ ^[0-9]+$   ]] || rej=0

local total per array
total=$(awk -v e="$rate" 'BEGIN{printf "%.4f", e*1000}')
per=$(awk -v t="$total" -v n="$cards" 'BEGIN{printf "%.4f", t/n}')
array=$(jq -nc --argjson p "$per" --argjson n "$cards" '[range($n) | $p]')

local temps fans buses
temps=$(jq -c "[.temp$nvidia_indexes_array]"   <<< "$gpu_stats" 2>/dev/null); [[ -z $temps || $temps == null ]] && temps='[]'
fans=$(jq -c  "[.fan$nvidia_indexes_array]"    <<< "$gpu_stats" 2>/dev/null); [[ -z $fans  || $fans  == null ]] && fans='[]'
buses=$(jq -c "[.busids$nvidia_indexes_array]" <<< "$gpu_stats" 2>/dev/null); [[ -z $buses || $buses == null ]] && buses='[]'

local secs=0 proc
proc=$(pgrep -f 'blacksmith-forge' | head -n1)
[[ -n $proc ]] && secs=$(( $(date +%s) - $(date +%s -d "$(ps -o lstart= -p "$proc" 2>/dev/null)" 2>/dev/null || date +%s) ))

khs=$total
stats=$(jq -nc \
    --argjson hs "$array" --argjson temp "$temps" --argjson fan "$fans" --argjson bus "$buses" \
    --arg up "$secs" --arg ver "$CUSTOM_VERSION" --arg a "$acc" --arg r "$rej" \
    '{hs:$hs, hs_units:"khs", temp:$temp, fan:$fan, bus_numbers:$bus,
      uptime:($up|tonumber), ver:$ver, ar:[($a|tonumber),($r|tonumber)], algo:"blacksmith"}')
