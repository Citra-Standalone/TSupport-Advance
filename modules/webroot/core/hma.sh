#!/bin/sh
MODDIR="${0%/*}"
. $MODDIR/../../common_func.sh
CONFIG_FILE_HMA="/data/data/com.tsng.hidemyapplist/files/config.json"
CONFIG_FILE_HMAOSS="/data/data/org.frknkrc44.hma_oss/files/config.json"
CONFIG_FILE_HMAL="/data/data/com.google.android.hmal/files/config.json"
TEMPLATE_NAME="TSupport-Advance"
IS_WHITELIST="false"
HMA_SCOPE_FILE="$CONF/hma.txt"
APP_LIST="
com.topjohnwu.magisk
com.rifsxd.ksunext
com.google.android.hmal
com.tsng.hidemyapplist
com.coderstory.toolkit
deltazero.amarok
io.github.vvb2060.magisk
io.github.a13e300.fusefixer
me.bmax.apatch
me.weishu.kernelsu
com.wmods.wppenhacer
org.frknkrc44.hma_oss
ru.maximoff.apktool
com.termux
bin.mt.plus
moe.shizuku.privileged.api
com.sevtinge.hyperceiler
com.rajmani7584.payloaddumper
com.fankes.apperrorstracking
"


touch "$HMA_SCOPE_FILE"

process() {
    CONFIG_FILE="$1"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "! Configuration file not found."
        echo "=== ENDED ==="
        exit 1
    fi
    
    sed -i 's/"aggressiveFilter":false/"aggressiveFilter":true/' "$CONFIG_FILE"
    
    if [ -n "$APP_LIST" ]; then
        JSON_APP_LIST=$(for app in $APP_LIST; do printf '"%s",' "$app"; done | sed 's/,$//')
    else
        JSON_APP_LIST=""
    fi
    TEMPLATE_CONTENT="\"$TEMPLATE_NAME\":{\"isWhitelist\":$IS_WHITELIST,\"appList\":[$JSON_APP_LIST]}"
    
    if grep -q "\"$TEMPLATE_NAME\":" "$CONFIG_FILE"; then
        ESCAPED_CONTENT=$(printf '%s\n' "$TEMPLATE_CONTENT" | sed 's:[\\/&]:\\&:g;$!s/$/\\/')
        sed -i "s~\"$TEMPLATE_NAME\":{[^}]*}~$ESCAPED_CONTENT~" "$CONFIG_FILE"
    else
        if grep -q '"templates":{}' "$CONFIG_FILE"; then
            sed -i "s~\"templates\":{}~\"templates\":{$TEMPLATE_CONTENT}~" "$CONFIG_FILE"
        else
            sed -i "s~\"templates\":{~\"templates\":{$TEMPLATE_CONTENT,~" "$CONFIG_FILE"
        fi
        echo "- Template created."
    fi
    
    if ! grep -q '"scope":' "$CONFIG_FILE"; then
        sed -i 's/}$/,"scope":{}}/' "$CONFIG_FILE"
    fi
    
    if [ ! -s "$HMA_SCOPE_FILE" ]; then
        :
    else
        SCOPE_SETTINGS="{\"useWhitelist\":false,\"excludeSystemApps\":true,\"hideInstallationSource\":true,\"applyTemplates\":[\"$TEMPLATE_NAME\"],\"applyPresets\":[\"root_apps\",\"sus_apps\",\"xposed\"],\"applySettingsPresets\":[\"dev_options\"],\"extraAppList\":[]}"
            
        while IFS= read -r package_name || [ -n "$package_name" ]; do
            if [ -z "$package_name" ] || [ "$(echo "$package_name" | cut -c1)" = "#" ]; then
                continue
            fi
        
            if [ "$(echo "$package_name" | sed 's/.*\(.\)$/\1/')" = "!" ]; then
                
                clean_package_name=$(echo "$package_name" | sed 's/!$//')
                target_package="\"$clean_package_name\":{\"useWhitelist\":false,\"excludeSystemApps\":true,\"applyTemplates\":[\"$TEMPLATE_NAME\"]"
                escaped=$(echo "$target_package" | sed -e 's/[&/\]/\\&/g')
                if grep -Fq "$target_package" "$CONFIG_FILE"; then
                    sed -i "s/,\"$clean_package_name\":{[^}]*}//g" "$CONFIG_FILE"
                    sed -i "s/\"$clean_package_name\":{[^}]*},//g" "$CONFIG_FILE"
                    sed -i "s/\"$clean_package_name\":{[^}]*}//g" "$CONFIG_FILE"
                    echo "-- $clean_package_name"
                else
                    echo "!- $clean_package_name"
                fi
                
            else
                
                local SCOPE_LINE
                SCOPE_LINE="\"$package_name\":$SCOPE_SETTINGS"
        
                if grep -q "\"$package_name\":" "$CONFIG_FILE"; then
                    sed -i "s|\"$package_name\":{[^}]*}|$SCOPE_LINE|" "$CONFIG_FILE"
                    echo "++ $package_name"
                else
                    sed -i "s/\"scope\":{/\"scope\":{$SCOPE_LINE,/" "$CONFIG_FILE"
                    echo "=+ $package_name"
                fi
            fi
        done < "$HMA_SCOPE_FILE"

        sed -i 's/,}/}/g' "$CONFIG_FILE"
        sed -i 's/{,/{/g' "$CONFIG_FILE"

    fi
}

echo -e "\n=== HMA'L LOADER ==="
if [ ! -d "/data/data/com.google.android.hmal" ] && [ ! -d "/data/data/com.tsng.hidemyapplist" ] && [ ! -d "/data/data/org.frknkrc44.hma_oss" ]; then
    echo "! HMA'L not detected"
    echo "- Please Install HMA or HMAL"
    echo "=== ENDED ==="
    exit 1
fi

if [ -d "/data/data/com.google.android.hmal" ]; then
        echo "- Working with HMAL."
        process $CONFIG_FILE_HMAL
elif [ -d "/data/data/org.frknkrc44.hma_oss" ]; then
        echo "- Working with HMA-OSS."
        process $CONFIG_FILE_HMAOSS
else
    if [ -d "/data/data/com.tsng.hidemyapplist" ]; then
        echo "- Working with HMA."
        process $CONFIG_FILE_HMA
    fi
fi

if [ $? -ne 0 ]; then
    echo "! Failed to modify the configuration file."
    echo "=== ENDED ==="
    exit 1
fi

echo "- Template updated."
echo "=== ENDED ==="