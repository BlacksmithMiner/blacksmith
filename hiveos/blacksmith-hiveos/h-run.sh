#!/usr/bin/env bash
cd "$(dirname "$0")" || exit 1

ENGINE=./blacksmith-forge
SETUP=./forge-cuda-setup.sh

chmod +x "$ENGINE" "$SETUP" 2>/dev/null

FORGE_CUDA_CACHE="${FORGE_CUDA_CACHE:-/hive/miners/custom/.blacksmith-cuda}"
export FORGE_CUDA_CACHE
export LD_LIBRARY_PATH="$(pwd)/lib:$FORGE_CUDA_CACHE:${LD_LIBRARY_PATH:-}:/hive/lib"

[ -t 1 ] && . colors 2>/dev/null
. ./h-manifest.conf

for v in CUSTOM_LOG_BASENAME CUSTOM_CONFIG_FILENAME; do
    [[ -z ${!v} ]] && { echo "manifest field $v is unset"; exit 1; }
done
[[ -f $CUSTOM_CONFIG_FILENAME ]] || { echo "config missing — apply the Flight Sheet (h-config.sh)"; exit 1; }

LOG="$CUSTOM_LOG_BASENAME.log"
FEED="$CUSTOM_LOG_BASENAME.jsonl"
mkdir -p "$(dirname "$LOG")" 2>/dev/null
: > "$LOG"

ARGS="$(cat "$CUSTOM_CONFIG_FILENAME")"
[[ -z ${ARGS// } ]] && { echo "config is empty — re-apply the Flight Sheet" | tee -a "$LOG"; exit 1; }

[[ -x $SETUP ]] && "$SETUP" 2>&1 | tee -a "$LOG"

UNRESOLVED=""
for so in $(ldd "$ENGINE" 2>/dev/null | awk '/not found/{print $1}'); do
    [[ $so == libcublasLt.so.13 && ( -e ./lib/$so || -e "$FORGE_CUDA_CACHE/$so" ) ]] && continue
    UNRESOLVED="$UNRESOLVED $so"
done
if [[ -n ${UNRESOLVED// } ]]; then
    {
        echo "blacksmith: cannot start — unresolved libraries:$UNRESOLVED"
        echo "blacksmith: run  bash $(pwd)/$SETUP  (needs internet; CUDA 13 wants driver >= 580), then restart"
    } | tee -a "$LOG"
    sleep 60
    exit 1
fi

exec stdbuf -oL -eL "$ENGINE" $ARGS 2>&1 \
    | stdbuf -oL tee "$FEED" \
    | stdbuf -oL awk -f ./forge-log.awk \
    | tee -a "$LOG"
