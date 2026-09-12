#!/usr/bin/env bash

reject() { echo -e "${RED}blacksmith: $1${NOCOLOR}"; return 1; }

[[ -z $CUSTOM_CONFIG_FILENAME ]] && reject "manifest gave no config path" && return 1
[[ -z $CUSTOM_TEMPLATE ]] && reject "wallet template is empty — set it in the Flight Sheet" && return 1
[[ -z $CUSTOM_URL ]] && reject "pool URL is empty — set it in the Flight Sheet" && return 1

CUSTOM_ALGO=blacksmith

local endpoints="" host
local IFS=,
for host in $CUSTOM_URL; do
    host="${host#*://}"
    [[ -n $host ]] && endpoints+="${endpoints:+,}stratum+tls://$host"
done
unset IFS

local line="--ui json --stratum $endpoints --user $CUSTOM_TEMPLATE --pass ${CUSTOM_PASS:-x}"
[[ -n $CUSTOM_USER_CONFIG ]] && line+=" $CUSTOM_USER_CONFIG"
[[ -n $WORKER_NAME ]] && line="${line//%WORKER_NAME%/$WORKER_NAME}"

printf '%s\n' "$line" > "$CUSTOM_CONFIG_FILENAME"
