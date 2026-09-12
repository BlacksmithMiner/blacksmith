#!/usr/bin/env bash
set -u

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLED="$SELF_DIR/lib"
STORE="${FORGE_CUDA_CACHE:-/hive/miners/custom/.blacksmith-cuda}"
RUNTIME_LIB="libcublasLt.so.13"
NV_REPO="https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64"
DEB_HEAD="libcublas-13-2_"
DRIVER_FLOOR=580
FORCE_REFRESH="${FORGE_CUDA_REFRESH:-0}"
DRIVER_AUTO="${FORGE_DRIVER_AUTO:-1}"

log() { printf 'forge: %s\n' "$*"; }

nv_query() { nvidia-smi --query-gpu="$1" --format=csv,noheader 2>/dev/null; }

TOP_ARCH=0
scan_cards() {
    local table row card cap major
    table="$(nv_query name,compute_cap)"
    if [[ -z $table ]]; then
        log "no GPU reported by nvidia-smi — architecture cannot be auto-detected"
        return
    fi
    while IFS=, read -r card cap; do
        card="${card#"${card%%[![:space:]]*}"}"; card="${card%"${card##*[![:space:]]}"}"
        cap="${cap//[[:space:]]/}"
        [[ -z $cap ]] && continue
        major="${cap%%.*}"
        (( major > TOP_ARCH )) && TOP_ARCH=$major
        log "detected ${card:-GPU}  cc ${cap}  (sm_${cap//./})  — driver floor ${DRIVER_FLOOR}"
    done <<< "$table"
}

pick_driver_build() {
    command -v nvidia-driver-update >/dev/null 2>&1 || return 1
    nvidia-driver-update --list 2>/dev/null \
        | grep -oE '[0-9]{3}\.[0-9]+(\.[0-9]+)?' | sort -V | tail -n1
}

provision_driver() {
    if ! command -v nvidia-driver-update >/dev/null 2>&1; then
        log "this host has no nvidia-driver-update — install an NVIDIA driver >= ${DRIVER_FLOOR} manually, then reboot"
        return 1
    fi
    mkdir -p "$STORE" 2>/dev/null || true
    local stamp="$STORE/.driver-attempt"
    if [[ -f $stamp ]]; then
        log "driver auto-install was already tried ($(cat "$stamp" 2>/dev/null)); still inadequate — finish by hand:"
        log "    nvidia-driver-update --list ; nvidia-driver-update <build>   # then reboot"
        return 1
    fi
    local build; build="$(pick_driver_build)"
    printf '%s %s\n' "${build:-latest}" "$(date -u +%FT%TZ)" > "$stamp" 2>/dev/null || true
    log "installing NVIDIA driver ${build:-latest} for the detected card(s) — the rig reboots on completion"
    if [[ -n $build ]]; then nvidia-driver-update "$build"; else nvidia-driver-update; fi
}

runtime_dir() {
    [[ -e "$BUNDLED/$RUNTIME_LIB" ]] && { printf '%s' "$BUNDLED"; return 0; }
    [[ -e "$STORE/$RUNTIME_LIB"   ]] && { printf '%s' "$STORE";   return 0; }
    return 1
}

newest_deb() {
    local page
    page="$(curl -fsSL --max-time 60 "$NV_REPO/" 2>/dev/null)"
    printf '%s' "$page" | grep -oE "${DEB_HEAD}[0-9.]+-[0-9]+_amd64\.deb" | sort -V | tail -n1 \
        || printf '%s' "$page" | grep -oE 'libcublas-13-[0-9]+_[0-9.]+-[0-9]+_amd64\.deb' | sort -V | tail -n1
}

pull_runtime() {
    local deb="$1" work="$STORE/.staging" item hit=0
    command -v curl >/dev/null || { log "curl absent — cannot download the CUDA runtime"; return 1; }
    mkdir -p "$STORE" || return 1
    rm -rf "$work"; mkdir -p "$work" || return 1
    log "fetching $deb (~360 MB, one-time, kept in $STORE)"
    curl -fL --retry 3 --connect-timeout 20 -o "$work/$deb" "$NV_REPO/$deb" \
        || { log "download failed"; rm -rf "$work"; return 1; }
    log "unpacking $RUNTIME_LIB"
    dpkg-deb --fsys-tarfile "$work/$deb" | tar -x -C "$work" --wildcards "*/$RUNTIME_LIB*" 2>/dev/null \
        || { log "unpack failed"; rm -rf "$work"; return 1; }
    while IFS= read -r item; do cp -a "$item" "$STORE/" && hit=1; done \
        < <(find "$work" -name "$RUNTIME_LIB*" 2>/dev/null)
    rm -rf "$work"
    (( hit )) || { log "package held no $RUNTIME_LIB"; return 1; }
    if [[ ! -e $STORE/$RUNTIME_LIB ]]; then
        local real; real="$(find "$STORE" -maxdepth 1 -name "$RUNTIME_LIB.*" -printf '%f\n' | sort -V | tail -n1)"
        [[ -n $real ]] && ln -sf "$real" "$STORE/$RUNTIME_LIB"
    fi
    printf '%s\n' "$deb" > "$STORE/STAMP" 2>/dev/null || true
    log "cached into $STORE"
}

scan_cards
CUR_DRIVER="$(nv_query driver_version | head -n1)"
if [[ -z $CUR_DRIVER ]]; then
    log "WARNING: nvidia-smi returned nothing — no NVIDIA driver is visible"
    [[ $DRIVER_AUTO == 1 ]] && provision_driver
elif (( ${CUR_DRIVER%%.*} < DRIVER_FLOOR )); then
    log "driver ${CUR_DRIVER} is below the CUDA 13 floor (${DRIVER_FLOOR})"
    if [[ $DRIVER_AUTO == 1 ]]; then
        provision_driver
    else
        log "FORGE_DRIVER_AUTO=0 — install by hand: nvidia-driver-update --list ; nvidia-driver-update <build> ; reboot"
    fi
else
    log "driver ${CUR_DRIVER} satisfies CUDA 13 (top arch sm_${TOP_ARCH}x)"
fi

if [[ $FORCE_REFRESH != 1 ]] && here="$(runtime_dir)"; then
    tag=""; [[ -f $STORE/STAMP ]] && tag=" ($(cat "$STORE/STAMP" 2>/dev/null))"
    log "$RUNTIME_LIB already in $here$tag — set FORGE_CUDA_REFRESH=1 to update"
    exit 0
fi

mkdir -p "$STORE" 2>/dev/null || true
exec 8>"$STORE/.lock"
if command -v flock >/dev/null && ! flock -n 8; then
    log "another provisioning run is active — waiting"
    flock 8
    [[ $FORCE_REFRESH != 1 ]] && runtime_dir >/dev/null && { log "runtime supplied by the other run"; exit 0; }
fi

DEB="$(newest_deb)"
[[ -z $DEB ]] && { log "no libcublas-13-* package found at $NV_REPO"; exit 1; }
if [[ $FORCE_REFRESH == 1 && -e $STORE/$RUNTIME_LIB && -f $STORE/STAMP && "$(cat "$STORE/STAMP" 2>/dev/null)" == "$DEB" ]]; then
    log "cache is current ($DEB) — nothing to update"
    exit 0
fi

if pull_runtime "$DEB" && runtime_dir >/dev/null; then
    log "runtime ready"
    exit 0
fi
log "FAILED to provide $RUNTIME_LIB"
exit 1
