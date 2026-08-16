# Set module path
MODDIR="${0%/*}"
. $MODDIR/../../common_func.sh

# Define critical paths
CONF="/sdcard/TSupportConfig"

# TEESimulator
TEESIM_DIR="/data/adb/teesim"
TEESIM_CONF="$TEESIM_DIR/config.json"

# Tricky Store
TARGET_DIR="/data/adb/tricky_store"
TARGET_FILE="$TARGET_DIR/target.txt"
TARGET_BACKUP="$TARGET_DIR/target.txt.bak"

# OhMyKeymint
OMK_DIR="/data/misc/keystore/omk"
OMK_TARGET="$OMK_DIR/injector.toml"

# Get all installed package names
packages=$(awk '{print $1}' /data/system/packages.list)

# Merge user customizations from $CONF/customize.txt
merge_on_stop() {
    [ ! -f $CONF/customize.txt ] && return
    
    if head -n 1 $CONF/customize.txt | grep -q "^!$"; then
        echo '- Force "!" detected'
        for package in $packages; do
            liner $package $TARGET_FILE $package!
        done
    elif grep -q "teeBroken=false" "$TARGET_DIR/tee_status" && head -n 1 $CONF/customize.txt | grep -q "^?$"; then
        echo '- Force "?" detected'
        for package in $packages; do
            liner $package $TARGET_FILE $package?
        done
    fi
    
    if [ ! -f "$TARGET_FILE" ]; then
        grep -v '^#' $CONF/customize.txt | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' > "$TARGET_FILE"
        return
    fi
    
    echo '- Running SmartMerge'

    for package in $packages; do
        if grep -q "^$package!$" $CONF/customize.txt; then
            liner $package $TARGET_FILE $package!
        elif grep -q "teeBroken=false" "$TARGET_DIR/tee_status" && grep -q "^$package?$" $CONF/customize.txt; then
            liner $package $TARGET_FILE $package?
        elif grep -q "teeBroken=true" "$TARGET_DIR/tee_status" && grep -q "^$package?$" $CONF/customize.txt; then
            liner $package $TARGET_FILE $package
        elif grep -q "^$package$" $CONF/customize.txt; then
            liner $package $TARGET_FILE $package
        fi
    done
}

merge_toml() {
    local raw_item="$1"
    local file="$2"
    
    local item=${raw_item%%[?!]*}
    
    if ! grep -qF "\"$item\"" "$file"; then
        sed -i "/scoop = \[/,/\]/ {
            /\]/i \    \"$item\",
        }" "$file"
    fi

}

parse_teesim() (
    customize_file=$CONF/customize.txt
    config_file=$TEESIM_CONF
    backup_file=$config_file.bak
    custom_apps=
    depth=0
    in_default=0
    in_apps=0
    found_default=0
    found_keybox=0
    found_apps=0

    [ -r "$customize_file" ] || {
        echo "! Customize file not found: $customize_file"
        exit 1
    }

    [ -f "$config_file" ] || {
        echo "! Config file not found: $config_file"
        exit 1
    }

    if ! grep -qE '"default"[[:space:]]*:[[:space:]]*\{' "$config_file"; then
        echo "! Failed to parse, profile not found!"
        exit 1
    fi

    # Read and normalize custom apps.
    while IFS= read -r item || [ -n "$item" ]; do
        item=$(printf '%s\n' "$item" |
            sed 's/\r$//;s/^[[:space:]]*//;s/[[:space:]]*$//')

        case "$item" in
            ""|\#*) continue ;;
        esac

        item=$(printf '%s\n' "$item" | sed 's/[!?]$//')
        [ -n "$item" ] || continue

        if ! printf '%s\n' "$custom_apps" | grep -qF -x "$item"; then
            [ -n "$custom_apps" ] && custom_apps="$custom_apps
"
            custom_apps="$custom_apps$item"
        fi
    done < "$customize_file"

    update_depth() {
        braces=$(printf '%s\n' "$1" | sed 's/[^{}]//g')

        while [ -n "$braces" ]; do
            first=${braces%"${braces#?}"}

            case "$first" in
                "{") depth=$((depth + 1)) ;;
                "}") depth=$((depth - 1)) ;;
            esac

            braces=${braces#?}
        done
    }

    # Generate the updated config in memory.
    new_config=$(
        while IFS= read -r line || [ -n "$line" ]; do
            if [ "$in_apps" -eq 1 ]; then
                trimmed=$(printf '%s\n' "$line" |
                    sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

                case "$trimmed" in
                    ']'|'],')
                        printf '%s\n' "$line"
                        in_apps=0
                        ;;
                esac

                continue
            fi

            if [ "$found_default" -eq 0 ] &&
                printf '%s\n' "$line" |
                grep -qE '"default"[[:space:]]*:[[:space:]]*\{'
            then
                found_default=1
                in_default=1
                update_depth "$line"
                default_depth=$depth
                printf '%s\n' "$line"
                continue
            fi

            if [ "$in_default" -eq 1 ]; then
                if printf '%s\n' "$line" |
                    grep -qE '"keybox"[[:space:]]*:[[:space:]]*"[^"]*"'
                then
                    line=$(printf '%s\n' "$line" |
                        sed 's/"keybox"[[:space:]]*:[[:space:]]*"[^"]*"/"keybox": "keybox.xml"/')
                    found_keybox=1
                fi

                if printf '%s\n' "$line" |
                    grep -qE '"apps"[[:space:]]*:[[:space:]]*\['
                then
                    printf '%s\n' "$line"
                    indent=$(printf '%s\n' "$line" | sed 's/[^[:space:]].*//')
                    pending=

                    for item in $custom_apps; do
                        if [ -n "$pending" ]; then
                            printf '%s,\n' "$pending"
                        fi

                        pending=$indent'  "'$item'"'
                    done

                    [ -n "$pending" ] && printf '%s\n' "$pending"
                    in_apps=1
                    found_apps=1
                    update_depth "$line"
                    continue
                fi
            fi

            printf '%s\n' "$line"
            update_depth "$line"

            if [ "$in_default" -eq 1 ] && [ "$depth" -lt "$default_depth" ]; then
                in_default=0
            fi
        done < "$config_file"

        if [ "$found_default" -ne 1 ] ||
            [ "$found_keybox" -ne 1 ] ||
            [ "$found_apps" -ne 1 ] ||
            [ "$in_apps" -ne 0 ]
        then
            exit 2
        fi
    ) || {
        echo "! Failed to parse config.json"
        exit 1
    }

    # Keep the original config as config.json.bak only after parsing succeeds.
    cat "$config_file" > "$backup_file" || {
        echo "! Failed to create backup: $backup_file"
        exit 1
    }

    printf '%s\n' "$new_config" > "$config_file" || {
        echo "! Failed to update config: $config_file"
        exit 1
    }

    echo "> Done backup $(basename "$backup_file")"
    echo "> TEESimulator config updated"
)

# Check Required File.
[ -d "$TARGET_DIR" ] && [ ! -f "$TARGET_FILE" ] && touch "$TARGET_FILE"
[ ! -f "$CONF/customize.txt" ] && touch "$CONF/customize.txt"   
    
if { [ -d $TEESIM_DIR ] || [ -d $TARGET_DIR ] || [ -d $OMK_DIR ]; } && [ -f $CONF/customize.txt ] && ! head -n 1 $CONF/customize.txt | grep -qi "^#disable"; then
    echo -e "\n=== CITarget-SmartMerge ==="
    echo "- All conditions matched"

    if [ -d /data/adb/modules/teesim ]; then
        echo "- TEESimulator ( JingMatrix )"
        parse_teesim
    fi
            
    if [ -d /data/adb/modules/oh_my_keymint ]; then
        cat $OMK_TARGET > $OMK_TARGET.bak && echo "> Done backup injector.toml"
        
        for package in $(cat "$CONF/customize.txt"); do
            case "$package" in
                ""|\#*) continue ;;
            esac
            
            merge_toml "$package" "$OMK_TARGET"
        done
        
        if grep -q '[^[:space:]]' -- "$OMK_TARGET"; then
            echo "- Injector.toml updated."
        else
            echo "- Injector.toml is empty."
        fi        
    fi
    
    if [ -d /data/adb/modules/tricky_store ]; then
        cat $TARGET_FILE > $TARGET_BACKUP && echo "> Done backup target.txt"
        
        if echo "$(grep '^author=' "/data/adb/modules/tricky_store/module.prop" | head -n 1 | cut -d'=' -f2 | tr '[:upper:]' '[:lower:]')" | grep -q 'jingmatrix'; then
    
            echo "- TrickyStore ( JingMatrix Fork )"
    
            for package in $(cat $TARGET_FILE); do  
                if echo "$CRITICAL_PACKAGES" | grep -q "^$package$"; then
                    liner $package $TARGET_FILE
                elif grep -q "^$package$" $CONF/customize.txt; then
                    liner $package $TARGET_FILE
                fi
                reform $TARGET_FILE
            done
    
            apply_custom_list $CONF/customize.txt $TARGET_FILE $HEADER
            
            for package in $CRITICAL_PACKAGES; do  
                if grep -q "^$package$" "$TARGET_FILE"; then
                    liner $package $TARGET_FILE
                    reform $TARGET_FILE
                    liner "" $TARGET_FILE $package
                fi
                reform $TARGET_FILE
            done
                                 
        else
            merge_on_stop
        fi
        
        for package in $(cat $TARGET_FILE); do
            if [ $package = "$HEADER" ] || [ $package = "" ]; then
                continue
            else
                echo "++ $package"
            fi
        done
        
        if grep -q '[^[:space:]]' -- "$TARGET_FILE"; then
            echo "- Target.txt updated."
        else
            echo "- Target.txt is empty."
        fi
    fi
    
    echo "=== ENDED ==="

elif [ -d "$MODULES/TA_utl" ] || [ -d "$MODULES/.TA_utl" ]; then
    echo -e "\n=== CITarget-SUSPENDED ==="
    echo "- Tricky Addon Detected"
    echo "=== ENDED ==="

elif [ -d $TARGET_DIR ] && [ -f $CONF/customize.txt ] && [ "$(head -n 1 $CONF/customize.txt | tr '[:upper:]' '[:lower:]')" = "#disable" ]; then
    echo -e "\n=== CITarget-SUSPENDED ==="
    echo "- Feature Disabled"
    echo "=== ENDED ==="
        
else
    # Display error if Tricky Store is not found
    echo "=== ERROR ==="
    sleep 1
    echo "! TrickyStore folder not detected"
    sleep 0.5
    echo "=== ENDED ==="
fi