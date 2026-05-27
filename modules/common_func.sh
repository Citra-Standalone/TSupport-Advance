#!/bin/sh
MODDIR="/data/adb/modules/tsupport-advance"
CONF="/sdcard/TSupportConfig"
TARGET_DIR="/data/adb/tricky_store"
TARGET_FILE="$TARGET_DIR/target.txt"
TARGET_BACKUP="$TARGET_DIR/target.txt.bak"
ROM_SIGN_PATH="/system/etc/security"
BOOT_HASH_FILE="/data/adb/boot_hash"
CRITICAL_PACKAGES="com.android.vending com.google.android.gms com.google.android.gsf"
HEADER="[locked.xml]"
#VERCODE=$(grep 'versionCode=' $MODDIR/module.prop | cut -d '=' -f 2)
OLDVERCODE=$(grep 'versionCode=' $MODDIR/module.prop | cut -d '=' -f 2)
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH

RESETPROP="resetprop -n"
[ -f /data/adb/magisk/util_functions.sh ] && [ "$(grep MAGISK_VER_CODE /data/adb/magisk/util_functions.sh | cut -d= -f2)" -lt 27003 ] && RESETPROP=resetprop_hexpatch

# Abort script with a message
abort() {
    echo -e "$@"
    exit 1
}

# Check for a valid internet connection
check_internet() {
    if ! timeout 3 ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        if ! timeout 3 ping -c 1 google.com > /dev/null 2>&1; then
            abort "! Unable to connect to Internet"
        fi
    fi
}

BUSYBOX=$(command -v busybox)

if [ -z "$BUSYBOX" ]; then
    echo "! BusyBox not found"
    exit 1
fi


# Define wget using the detected BusyBox
wget() {
    if [ -n "$BUSYBOX" ]; then
        $BUSYBOX wget "$@"
    else
        echo "! BusyBox is not set. Cannot define wget."
    fi
}

reform() {
    local TARGET_FILE="$1"
    local TEMP_FILE=$(mktemp)
    grep -v '^$' "$TARGET_FILE" > "${TEMP_FILE}" && mv "${TEMP_FILE}" "$TARGET_FILE"
    SAFE_HEADER=$(echo "$HEADER" | sed 's/[][()\.^$?*+|]/\\&/g')
    sed -i "/^${SAFE_HEADER}$/i \\" "$TARGET_FILE"
}

# Write without leaving an empty space
# Usage: liner [oldtext] [target_file] [newtext] or none
liner() {
    LINE_NUM=$(grep -n -m 1 "^$" "$2" | cut -d: -f1)
    if grep -q -E "^$1[?!]?$" "$2"; then
        sed -i -E "/^$1[?!]?$/s/.*/$3/" "$2"
    elif [ -n "$LINE_NUM" ]; then
        sed -i "${LINE_NUM}s/.*/$3/" "$2"
    else
        #echo -en "\n$3" >> "$2"
        sed -i "1i $3" "$2"
    fi
}

# Argumen: apply_custom_list [source_file] [target_file] [header_text]
apply_custom_list() {
    local SOURCE_FILE="$1"
    local TARGET_FILE="$2"
    local HEADER="$3"

    if [ "$#" -ne 3 ]; then
        echo "Usage: apply_custom_list [source_file] [target_file] [header_text]" >&2
        return 1
    fi

    touch "$TARGET_FILE"

    if ! grep -qFx -- "$HEADER" "$TARGET_FILE"; then
        echo "$HEADER" >> "$TARGET_FILE"
    fi

    local HEADER_LINE_NUM=$(grep -n -m 1 -Fx -- "$HEADER" "$TARGET_FILE" | cut -d: -f1)

    if [ -z "$HEADER_LINE_NUM" ]; then
        echo "Error: Header '$HEADER' tidak ditemukan di '$TARGET_FILE'." >&2
        return 1
    fi

    local TEMP_FILE=$(mktemp)

    sed -n "1,${HEADER_LINE_NUM}p" "$TARGET_FILE" > "$TEMP_FILE"

    grep -v -e '^$' -e '^#' "$SOURCE_FILE" >> "$TEMP_FILE"

    mv "$TEMP_FILE" "$TARGET_FILE"
    
    reform $TARGET_FILE
}

# Handle user input via volume keys
key() {
    local option_name=$1
    local option1=$2
    local option2=$3
    local result_var=$4

    echo -e "\n[ VOL+ ] = [ $option1 ]"
    echo "[ VOL- ] = [ $option2 ]"
    echo "[ POWR ] = [ CANCEL ]"
    echo -e "\n$option_name"

    local maxtouch=3
    local touches=0

    while true; do
        keys=$(getevent -lqc1)
        
        if [ "$touches" -ge "$maxtouch" ]; then
            echo "! No Response, using Default ..."
            break
        fi

        if echo "$keys" | grep -q 'KEY_VOLUMEUP.*DOWN'; then
            echo "> $option1"
            eval "$result_var=1"
            return 1
        elif echo "$keys" | grep -q 'KEY_VOLUMEDOWN.*DOWN'; then
            echo "> $option2"
            eval "$result_var=0"
            return 0
        elif echo "$keys" | grep -q 'KEY_POWER.*DOWN'; then
            echo -e "> Power key detected! Canceling..."
            rm -rf "$TEMPDIR"
            sleep 1
            killer
            exit 0
        fi
        sleep 1
        touches=$((touches + 1))
    done
}

sh() {
    $BUSYBOX sh $@
}

# Kill DroidGuard related processes
killer() {
    droidguard="
    com.android.vending
    com.android.chrome
    com.google.android.googlequicksearchbox
    com.google.android.ims
    com.google.android.gms
    com.google.android.gms.persistent
    com.google.android.gms.unstable
    com.google.android.gsf
    com.google.android.contactkeys
    com.google.android.rkpdapp
    com.google.android.widevine
    com.google.android.apps.bard
    com.google.android.apps.walletnfcrel
    com.google.android.apps.messaging
    "
    for i in $(busybox pidof $droidguard); do
    	kill -9 "$i"
    done
}

delete_target() {
    [ -n "$1" ] && rm -rf "$1" 2>/dev/null
}


cleaner() {
    rm -rf "$CONF/temp"
}

# -------------------------- 

#PIF Props Function

# persistprop <prop name> <new value>
persistprop() {
    local NAME="$1"
    local NEWVALUE="$2"
    local CURVALUE="$(resetprop "$NAME")"

    if ! grep -q "$NAME" $MODPATH/uninstall.sh 2>/dev/null; then
        if [ "$CURVALUE" ]; then
            [ "$NEWVALUE" = "$CURVALUE" ] || echo "resetprop -n -p \"$NAME\" \"$CURVALUE\"" >> $MODPATH/uninstall.sh
        else
            echo "resetprop -p --delete \"$NAME\"" >> $MODPATH/uninstall.sh
        fi
    fi
    resetprop -n -p "$NAME" "$NEWVALUE"
}

# resetprop_hexpatch [-f|--force] <prop name> <new value>
resetprop_hexpatch() {
    case "$1" in
        -f|--force) local FORCE=1; shift;;
    esac 

    local NAME="$1"
    local NEWVALUE="$2"
    local CURVALUE="$(resetprop "$NAME")"

    [ ! "$NEWVALUE" -o ! "$CURVALUE" ] && return 1
    [ "$NEWVALUE" = "$CURVALUE" -a ! "$FORCE" ] && return 2

    local NEWLEN=${#NEWVALUE}
    if [ -f /dev/__properties__ ]; then
        local PROPFILE=/dev/__properties__
    else
        local PROPFILE="/dev/__properties__/$(resetprop -Z "$NAME")"
    fi
    [ ! -f "$PROPFILE" ] && return 3
    local NAMEOFFSET=$(echo $(strings -t d "$PROPFILE" | grep "$NAME") | cut -d ' ' -f 1)

    #<hex 2-byte change counter><flags byte><hex length of prop value><prop value + nul padding to 92 bytes><prop name>
    local NEWHEX="$(printf '%02x' "$NEWLEN")$(printf "$NEWVALUE" | od -A n -t x1 -v | tr -d ' \n')$(printf "%$((92-NEWLEN))s" | sed 's/ /00/g')"

    printf "Patch '$NAME' to '$NEWVALUE' in '$PROPFILE' @ 0x%08x -> \n[0000??$NEWHEX]\n" $((NAMEOFFSET-96))

    echo -ne "\x00\x00" \
        | dd obs=1 count=2 seek=$((NAMEOFFSET-96)) conv=notrunc of="$PROPFILE"
    echo -ne "$(printf "$NEWHEX" | sed -e 's/.\{2\}/&\\x/g' -e 's/^/\\x/' -e 's/\\x$//')" \
        | dd obs=1 count=93 seek=$((NAMEOFFSET-93)) conv=notrunc of="$PROPFILE"
}

# resetprop_if_diff <prop name> <expected value>
resetprop_if_diff() {
    local NAME="$1"
    local EXPECTED="$2"
    local CURRENT="$(resetprop "$NAME")"

    [ -z "$CURRENT" ] || [ "$CURRENT" = "$EXPECTED" ] || $RESETPROP "$NAME" "$EXPECTED"
}

# resetprop_if_match <prop name> <value match string> <new value>
resetprop_if_match() {
    local NAME="$1"
    local CONTAINS="$2"
    local VALUE="$3"

    [[ "$(resetprop "$NAME")" = *"$CONTAINS"* ]] && $RESETPROP "$NAME" "$VALUE"
}

# stub for boot-time
ui_print() { return; }

sleep_pause() {
    # APatch and KernelSU needs this
    # but not KSU_NEXT, MMRL
    if [ -z "$MMRL" ] && [ -z "$KSU_NEXT" ] && { [ "$KSU" = "true" ] || [ "$APATCH" = "true" ]; }; then
        sleep 5
    fi
}

# Specter VBMeta Fixer
# ---- START ----

# shellcheck shell=bash
# Read big-endian integer (N bytes, default 8) from file at offset
_val() {
  local _h
  _h=$(dd if="$1" bs=1 skip=$2 count=${3:-8} 2>/dev/null \
    | od -An -tx1 | tr -d ' \n')
  echo $((16#${_h:-0}))
}

# Emit VBMeta blob from a partition (handles AVB footer + raw VBMeta)
emit_vbmeta() {
  local _dev="$1" _sz _tail _prefix _pos _vb_off _vb_sz _auth_sz _aux_sz _total
  [ -b "$_dev" ] || return 1
  _sz=$(blockdev --getsize64 "$_dev" 2>/dev/null) || return 1

  # Check last 256 bytes for AVB footer ("AVBf" = hex 41564266)
  _tail=$(dd if="$_dev" bs=1 skip=$((_sz - 256)) count=256 2>/dev/null \
    | od -An -tx1 -v | tr -d ' \n')
  case "$_tail" in
    *41564266*)
      _prefix="${_tail%%41564266*}"
      _pos=$((_sz - 256 + ${#_prefix} / 2))
      _vb_off=$(_val "$_dev" $((_pos + 20)))
      _vb_sz=$(_val "$_dev" $((_pos + 28)))
      dd if="$_dev" bs=1 skip=$_vb_off count=$_vb_sz 2>/dev/null
      return 0
      ;;
  esac

  # Raw VBMeta
  [ "$(dd if="$_dev" bs=1 count=4 2>/dev/null)" = "AVB0" ] || return 1
  _auth_sz=$(_val "$_dev" 12)
  _aux_sz=$(_val "$_dev" 20)
  _total=$((256 + _auth_sz + _aux_sz))
  dd if="$_dev" bs=$_total count=1 2>/dev/null
}

# Calculate full VBMeta digest including chain partitions
vbmeta_digest() {
  local _part="$1" _auth_sz _aux_sz _total
  local _desc_off _desc_sz _aux_start _pos _pos_end
  local _tag _nbf _name_sz _name _d
  [ -b "$_part" ] || return 1
  _auth_sz=$(_val "$_part" 12)
  _aux_sz=$(_val "$_part" 20)
  _desc_off=$(_val "$_part" 96)
  _desc_sz=$(_val "$_part" 104)
  _total=$((256 + _auth_sz + _aux_sz))

  (
    dd if="$_part" bs=$_total count=1 2>/dev/null
    _aux_start=$((256 + _auth_sz))
    _pos=$((_aux_start + _desc_off))
    _pos_end=$((_aux_start + _desc_off + _desc_sz))
    while [ $_pos -lt $_pos_end ]; do
      _tag=$(_val "$_part" $_pos)
      _nbf=$(_val "$_part" $((_pos + 8)))
      if [ $_tag -eq 4 ]; then
        _name_sz=$(_val "$_part" $((_pos + 20)) 4)
        _name=$(dd if="$_part" bs=1 skip=$((_pos + 92)) count=$_name_sz 2>/dev/null)
        for _d in "/dev/block/by-name/$_name" "/dev/block/bootdevice/by-name/$_name"; do
          emit_vbmeta "$_d" 2>/dev/null && break
        done
      fi
      _pos=$((_pos + 16 + _nbf))
    done
  ) | sha256sum | cut -d' ' -f1
}

boothash() {
    # Checking Suffix for A/B Partition Device
    suffix=$(getprop ro.boot.slot_suffix)
    
    if [ -n "$suffix" ]; then
        vbpath="/dev/block/by-name/vbmeta$suffix"
    else
        vbpath="/dev/block/by-name/vbmeta"
    fi
    
    vbsize=$(blockdev --getsize64 $vbpath || true)
    vbhash=$(vbmeta_digest "$vbpath" || true)

    # Build boot_hash file
    set_vbhash() {
      local _h="$1"
      echo "$_h" > "$BOOT_HASH_FILE"
      chmod 644 "$BOOT_HASH_FILE" 2>/dev/null || true
      resetprop -n ro.boot.vbmeta.digest "$_h" 2>/dev/null || true
    }
    
    if [ -n "$vbhash" ]; then
        resetprop_if_empty "ro.boot.vbmeta.hash_alg" "sha256"
        resetprop -n "ro.boot.vbmeta.size" "$vbsize"
        set_vbhash "$vbhash"
    else
        echo "! Fail to set VBhash"
    fi
    
}

# ---- ENDED ----