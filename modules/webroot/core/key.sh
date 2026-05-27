#!/bin/sh

# key.sh v4.0
# Key retriever by citra-standalone

# Set module path
MODDIR="${0%/*}"
. $MODDIR/../../common_func.sh

# Display header
echo -e "\n=== CIT BBox Retriever ==="

# Set current directory
DIR="$(dirname "$(readlink -f "$0")")"
cd "$DIR" || exit 1

# Get device SDK
current_sdk_version="$(getprop ro.build.version.sdk)"

# Default URL for the key resource
if [ "$current_sdk_version" -gt "31" ];then
    URL="https://raw.githubusercontent.com/citra-standalone/Citra-Standalone/main/zipball/bin.tar"
else
    URL="https://raw.githubusercontent.com/citra-standalone/Citra-Standalone/main/bin.tar"
fi

# Initialize auto-mode flags
AUTO_KEY_MODE="0"
OVERWRITE_BACKUP_CHOICE=""
NOID="0"
NOEC="0"
NORSA="0"

# Parse args
AUTO_KEY_MODE="0"
OVERWRITE_BACKUP_CHOICE=""
CUSTOM_URL=""

POS=1 # Arg position
while [ $# -gt 0 ]; do
    case "$1" in
        --force-overwrite)
            AUTO_KEY_MODE="1"
            OVERWRITE_BACKUP_CHOICE="overwrite"
            echo "Auto: OVERWRITE"
            ;;
        --skip-backup)
            AUTO_KEY_MODE="1"
            OVERWRITE_BACKUP_CHOICE="skip"
            echo "Auto: SKIP"
            ;;
        *)
            # Accept URL only as 1st arg
            if [ "$POS" -eq 1 ]; then
                CUSTOM_URL="$1"
            fi
            ;;
    esac
    POS=$((POS + 1))
    shift
done

# Override default URL
if [ -n "$CUSTOM_URL" ]; then
    URL="$CUSTOM_URL"
fi


# Clean up temporary files
cleaner() {
    [ -f $DIR/key ] && rm -rf "$DIR/key"
    [ -f $DIR/keybox.xml ] && rm -rf "$DIR/keybox.xml"
}

# Generate a random string
random() {
  chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
  length=${1:-8}
  result=""
  while [ "${#result}" -lt "$length" ]; do
    rand=$(od -An -N1 -tu1 /dev/urandom | tr -d ' ')
    result="$result$(echo "$chars" | cut -c $((rand % ${#chars} + 1)))"
  done
  echo "$result"
}

# Handle user input via volume keys
key() {
    local option_name=$1
    local option1=$2
    local option2=$3
    local result_var=$4

    # Handle automated mode
    if [ "$AUTO_KEY_MODE" = "1" ]; then
        if [ "$OVERWRITE_BACKUP_CHOICE" = "overwrite" ]; then
            echo "> Backup overwritten (auto-mode)"
            result=1
            return 1
        elif [ "$OVERWRITE_BACKUP_CHOICE" = "skip" ]; then
            echo "> Backup skipped (auto-mode)"
            result=0
            return 0
        fi
    fi

    # Handle interactive mode
    echo -e "\n[ VOL+ ] = [ $option1 ]"
    echo "[ VOL- ] = [ $option2 ]"
    echo "[ POWR ] = [ ABORT ]"
    echo -e "\nYour selection for $option_name ?"

    local maxtouch=3
    local touches=0

    while true; do
        keys=$(getevent -lqc1)
        
        if [ "$touches" -ge "$maxtouch" ]; then
            echo "! No response"
            echo "> Backup overwritten"
            result=1
            return 1
        fi

        if echo "$keys" | grep -q 'KEY_VOLUMEUP.*DOWN'; then
            echo "> Backup overwritten"
            result=1
            return 1
        elif echo "$keys" | grep -q 'KEY_VOLUMEDOWN.*DOWN'; then
            echo "> Backup skiped"
            result=0
            return 0
        elif echo "$keys" | grep -q 'KEY_POWER.*DOWN'; then
            echo -e "> Power key detected! Aborting..."
            cleaner
            echo "! Aborted"
            sleep 1
            echo "=== ENDED ==="
            exit 0
        fi
        sleep 1
        touches=$((touches + 1))
    done
}

dummy() {
        cat <<EOF > keybox.xml
<?xml version="1.0" encoding="UTF-8"?>
<AndroidAttestation>
<NumberOfKeyboxes>1</NumberOfKeyboxes>
<Keybox>
#THIS IS JUST A DUMMY KEY.
#Reason : ${ID}
#Citra-Standalone - For the BRAVE to Advance. CITraces - https://t.me/citraintegritytrick - Citra, a standalone implementation, leaves a trace in IoT.
</Keybox>
</AndroidAttestation>

EOF

        cat /data/adb/tricky_store/keybox.xml > /data/adb/tricky_store/keybox.xml.bak
        mv "$DIR/keybox.xml" /data/adb/tricky_store/keybox.xml
}

keybox() {
        echo "- Saving to keybox.xml ..."
        cat <<EOF > keybox.xml
<?xml version="1.0" encoding="UTF-8"?>
<AndroidAttestation>
<NumberOfKeyboxes>1</NumberOfKeyboxes>
<Keybox$DeviceID>
$ecdsa_key
#CIT_${TYPE}
#UNIQUE : ${ID}${STAT}_${random}
#Citra-Standalone - For the BRAVE to Advance. CITraces - https://t.me/citraintegritytrick - Citra, a standalone implementation, leaves a trace in IoT.
$rsa_key
</Keybox>
</AndroidAttestation>

EOF
}

# Download and deobfuscate the key
echo "- Retrieving latest key ..."
wget -q -T 10 -O key --no-check-certificate "$URL" 2>/dev/null || curl --connect-timeout 10 -s -o key --insecure "$URL" 2>&1 || abort "! Download failed"
file_content=$(cat key | tr 'A-Za-z' 'N-ZA-Mn-za-m' | base64 -d)
if [ -z "$file_content" ]; then
    abort "! Something wrong, try again later."
fi

# Extract key details from the decoded content
ID=$(echo "$file_content" | grep '^ID=' | cut -d'=' -f2-)
TYPE=$(echo "$file_content" | grep '^TYPE=' | cut -d'=' -f2-)
ecdsa_key=$(echo "$file_content" | sed -n '/<Key algorithm="ecdsa">/,/<\/Key>/p')
rsa_key=$(echo "$file_content" | sed -n '/<Key algorithm="rsa">/,/<\/Key>/p')
random=$(random)

if [ -z "$rsa_key" ]; then
    NORSA="1"
fi
if [ -z "$ecdsa_key" ]; then
    NOEC="1"
fi

if [ "$NOEC" = "1" ] && echo "$(grep '^author=' "/data/adb/modules/tricky_store/module.prop" | head -n 1 | cut -d'=' -f2 | tr '[:upper:]' '[:lower:]')" | grep -q 'jingmatrix'; then
    NOID="1"
    ID="No Attestation Key Available"
    DeviceID=""
    
    echo -e "- Getting information ~ Key: $ID"
    dummy
    
elif [ "$NOEC" = "1" ] && [ "$NORSA" = "1" ]; then
    NOID="1"
    ID="No Attestation Key Available"
    DeviceID=""
    
    echo -e "- Getting information ~ Key: $ID"
    
elif [ -z "$ID" ]; then
    NOID="1"
    ID="Leaked Hardware Attestation"
    DeviceID=""
    
    echo -e "- Getting information ~ Key: $ID"
fi

# Display key information and privacy notice
sleep 0.5
echo "- Dumping latest key information ..."
sleep 0.5
STAT="PUB"
if echo "$TYPE" | grep -qi "PRIVATE"; then
    echo """
===========================================
Unauthorized data leakage to the public is strictly prohibited.
Data may only be accessed and retrieved through the proper methods provided by the account owner, Citra Standalone.
Any data leakage to the public, regardless of the reason, will result in the deletion of the data and permanent denial of future access.
This is a firm prohibition for anyone granted access to this data.
===========================================
"""
    STAT="PVT"
fi

# Normalize ID for display
if echo "$ID" | grep -qi "Hardware Attestation" ; then
    ID="HW"
else
    ID="SW"
fi

# Validate extracted key components
if [ "$NOID" = "1" ]; then
    echo "! WARNING: ID not found."
    ID="UNKNOWN"
else
    DeviceID=" DeviceID=\"${ID}${STAT}_${random}\""
fi

if [ "$NOEC" = "1" ]; then
    if echo "$(grep '^author=' "/data/adb/modules/tricky_store/module.prop" | head -n 1 | cut -d'=' -f2 | tr '[:upper:]' '[:lower:]')" | grep -q 'jingmatrix'; then
        echo "! ERROR: ECDSA not found."
        cleaner
        exit 0
    else
        echo "! WARNING: ECDSA not found."
    fi
fi

if [ "$NORSA" = "1" ]; then
    echo "! WARNING: RSA not found."
fi

if [ "$NOEC" = "1" ] && [ "$NORSA" = "1" ]; then
    for package in $CRITICAL_PACKAGES; do  
        if grep -q "^$package$" "$TARGET_FILE"; then
            liner $package $TARGET_FILE
        fi
        reform $TARGET_FILE
    done
    cleaner
    exit 0
fi

# Generate the final keybox.xml file
if [ -d /data/adb/tricky_store ]; then

    keybox
    
    # Handle backup and replacement of the existing keybox.xml
    if [ -f /data/adb/tricky_store/keybox.xml ] && [ -f /data/adb/tricky_store/keybox.xml.bak ]; then
        echo "! Backup exist"
        if [ "$AUTO_KEY_MODE" = "0" ]; then
            key backup OVERWRITE SKIP result
        else
            if [ "$OVERWRITE_BACKUP_CHOICE" = "overwrite" ]; then result=1; else result=0; fi
        fi
        
        if [ "$result" -eq 0 ]; then
            mv "$DIR/keybox.xml" /data/adb/tricky_store/keybox.xml
            [ "$NOEC" = "0" ] && cat /data/adb/tricky_store/keybox.xml > /data/adb/tricky_store/locked.xml
            echo "- Moving new keybox.xml"
        elif [ "$result" -eq 1 ]; then
            cat /data/adb/tricky_store/keybox.xml > /data/adb/tricky_store/keybox.xml.bak
            mv "$DIR/keybox.xml" /data/adb/tricky_store/keybox.xml
            [ "$NOEC" = "0" ] && cat /data/adb/tricky_store/keybox.xml > /data/adb/tricky_store/locked.xml
            echo "- Moving new keybox.xml"
        elif [ "$result" -eq 2 ]; then
            cleaner
            exit 2
        else
            exit 0
        fi

    elif [ ! -f /data/adb/tricky_store/keybox.xml.bak ] && [ -f /data/adb/tricky_store/keybox.xml ]; then
        echo "- Creating a backup ..."
        [ "$NOEC" = "0" ] && cat /data/adb/tricky_store/keybox.xml > /data/adb/tricky_store/locked.xml
        cat /data/adb/tricky_store/keybox.xml > /data/adb/tricky_store/keybox.xml.bak
        mv "$DIR/keybox.xml" /data/adb/tricky_store/keybox.xml
    else
        mv "$DIR/keybox.xml" /data/adb/tricky_store/keybox.xml
    fi
    sleep 0.5
    [ -f /data/adb/tricky_store/keybox.xml ] && echo "- Successfully retrieved"
else
    echo "! No tricky store found"
fi

cleaner
killer
echo "=== ENDED ==="
