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
    tmp_file=$config_file.tmp
    custom_apps=

    # Remove the fixed temporary file on every exit path.
    trap 'rm -f "$tmp_file"' 0 1 2 3 15

    [ -r "$customize_file" ] || {
        echo "! Customize file not found: $customize_file"
        exit 1
    }
    [ -f "$config_file" ] || {
        echo "! Config file not found: $config_file"
        exit 1
    }

    add_unique() {
        value=$1
        list=$2
        if ! printf '%s\n' "$list" | grep -qF -x "$value"; then
            [ -n "$list" ] && list="$list
"
            list=$list$value
        fi
        printf '%s' "$list"
    }

    append_value() {
        list=$1
        value=$2
        [ -n "$list" ] && list="$list
"
        printf '%s%s' "$list" "$value"
    }

    # Read and normalize customize.txt.
    while IFS= read -r item || [ -n "$item" ]; do
        item=$(printf '%s\n' "$item" |
            sed 's/\r$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
        case "$item" in
            ""|\#*) continue ;;
        esac
        item=$(printf '%s\n' "$item" | sed 's/[!?]$//')
        [ -n "$item" ] || continue
        custom_apps=$(add_unique "$item" "$custom_apps")
    done < "$customize_file"

    # Pass 1: scan every apps array and count package occurrences.
    scan_config() {
        scan_file=$1
        depth=0
        in_apps=0
        in_default=0
        found_default=0
        found_apps=0
        all_packages=
        default_packages=

        update_depth() {
            braces=$(printf '%s\n' "$1" | sed 's/[^{}]//g')
            while [ -n "$braces" ]; do
                first=${braces%${braces#?}}
                case "$first" in
                    "{") depth=$((depth + 1)) ;;
                    "}") depth=$((depth - 1)) ;;
                esac
                braces=${braces#?}
            done
        }

        while IFS= read -r line || [ -n "$line" ]; do
            if [ "$in_apps" -eq 1 ]; then
                trimmed=$(printf '%s\n' "$line" |
                    sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                case "$trimmed" in
                    ']'|'],')
                        in_apps=0
                        continue
                        ;;
                    '"'*)
                        package=$(printf '%s\n' "$trimmed" |
                            sed 's/^"//;s/",[[:space:]]*$//;s/"[[:space:]]*$//')
                        all_packages=$(append_value "$all_packages" "$package")
                        if [ "$in_default" -eq 1 ]; then
                            default_packages=$(add_unique "$package" "$default_packages")
                        fi
                        ;;
                esac
                continue
            fi

            if [ "$found_default" -eq 0 ] &&
                printf '%s\n' "$line" |
                grep -qE '^[[:space:]]*"default"[[:space:]]*:[[:space:]]*\{'; then
                found_default=1
                in_default=1
                update_depth "$line"
                default_depth=$depth
                continue
            fi

            # profiles is depth 2; its direct children are preset objects.
            if [ "$depth" -eq 2 ] &&
                printf '%s\n' "$line" |
                grep -qE '^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*\{'; then
                case "$line" in
                    *'"default"'*) in_default=1 ;;
                    *) in_default=0 ;;
                esac
            fi

            if printf '%s\n' "$line" |
                grep -qE '^[[:space:]]*"apps"[[:space:]]*:[[:space:]]*\['; then
                in_apps=1
                found_apps=1
                continue
            fi

            update_depth "$line"
            if [ "$in_default" -eq 1 ] && [ "$depth" -lt "$default_depth" ]; then
                in_default=0
            fi
        done < "$scan_file"

        [ "$found_default" -eq 1 ] && [ "$found_apps" -eq 1 ] || return 1

        # Only packages absent from every preset are normally added to default.
        item=
        packages_to_default=
        while IFS= read -r item || [ -n "$item" ]; do
            [ -n "$item" ] || continue
            if ! printf '%s\n' "$all_packages" | grep -qF -x "$item"; then
                packages_to_default=$(add_unique "$item" "$packages_to_default")
                all_packages=$(append_value "$all_packages" "$item")
            fi
        done <<EOF_CUSTOM
$custom_apps
EOF_CUSTOM

        # Find packages occurring at least twice after normal insertion.
        seen_packages=
        duplicate_packages=
        package=
        while IFS= read -r package || [ -n "$package" ]; do
            [ -n "$package" ] || continue
            if printf '%s\n' "$seen_packages" | grep -qF -x "$package"; then
                duplicate_packages=$(add_unique "$package" "$duplicate_packages")
            else
                seen_packages=$(append_value "$seen_packages" "$package")
            fi
        done <<EOF_ALL
$all_packages
EOF_ALL
    }

    scan_config "$config_file" || {
        echo "! Failed to scan config.json"
        exit 1
    }

    # Pass 2: remove only duplicate packages from every preset, then restore
    # each duplicate package and each newly requested package in default only.
    render_config() {
        render_file=$1
        depth=0
        in_apps=0
        in_default=0
        found_default=0
        found_apps=0
        apps_indent=
        apps_is_default=0
        kept_apps=

        update_depth_render() {
            braces=$(printf '%s\n' "$1" | sed 's/[^{}]//g')
            while [ -n "$braces" ]; do
                first=${braces%${braces#?}}
                case "$first" in
                    "{") depth=$((depth + 1)) ;;
                    "}") depth=$((depth - 1)) ;;
                esac
                braces=${braces#?}
            done
        }

        emit_apps() {
            pending=
            package=
            while IFS= read -r package || [ -n "$package" ]; do
                [ -n "$package" ] || continue
                if [ -n "$pending" ]; then
                    printf '%s,\n' "$pending"
                fi
                pending=$apps_indent'  "'$package'"'
            done <<EOF_KEPT
$kept_apps
EOF_KEPT

            if [ "$apps_is_default" -eq 1 ]; then
                package=
                restore_list=$duplicate_packages
                restore_list=$(append_value "$restore_list" "$packages_to_default")
                while IFS= read -r package || [ -n "$package" ]; do
                    [ -n "$package" ] || continue
                    if ! printf '%s\n' "$kept_apps" | grep -qF -x "$package"; then
                        if [ -n "$pending" ]; then
                            printf '%s,\n' "$pending"
                        fi
                        pending=$apps_indent'  "'$package'"'
                        kept_apps=$(add_unique "$package" "$kept_apps")
                    fi
                done <<EOF_RESTORE
$restore_list
EOF_RESTORE
            fi

            [ -n "$pending" ] && printf '%s\n' "$pending"
        }

        while IFS= read -r line || [ -n "$line" ]; do
            if [ "$in_apps" -eq 1 ]; then
                trimmed=$(printf '%s\n' "$line" |
                    sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
                case "$trimmed" in
                    ']'|'],')
                        emit_apps
                        printf '%s\n' "$line"
                        in_apps=0
                        apps_is_default=0
                        kept_apps=
                        continue
                        ;;
                    '"'*)
                        package=$(printf '%s\n' "$trimmed" |
                            sed 's/^"//;s/",[[:space:]]*$//;s/"[[:space:]]*$//')
                        if ! printf '%s\n' "$duplicate_packages" |
                            grep -qF -x "$package"; then
                            kept_apps=$(add_unique "$package" "$kept_apps")
                        fi
                        ;;
                esac
                continue
            fi

            if [ "$found_default" -eq 0 ] &&
                printf '%s\n' "$line" |
                grep -qE '^[[:space:]]*"default"[[:space:]]*:[[:space:]]*\{'; then
                found_default=1
                in_default=1
                update_depth_render "$line"
                default_depth=$depth
                printf '%s\n' "$line"
                continue
            fi

            # Detect the current preset before changing keybox or apps.
            if [ "$depth" -eq 2 ] &&
                printf '%s\n' "$line" |
                grep -qE '^[[:space:]]*"[^"]+"[[:space:]]*:[[:space:]]*\{'; then
                case "$line" in
                    *'"default"'*) in_default=1 ;;
                    *) in_default=0 ;;
                esac
            fi

            if [ "$in_default" -eq 1 ] &&
                printf '%s\n' "$line" |
                grep -qE '"keybox"[[:space:]]*:[[:space:]]*"[^"]*"'; then
                line=$(printf '%s\n' "$line" |
                    sed 's/"keybox"[[:space:]]*:[[:space:]]*"[^"]*"/"keybox": "keybox.xml"/')
            fi

            if printf '%s\n' "$line" |
                grep -qE '^[[:space:]]*"apps"[[:space:]]*:[[:space:]]*\['; then
                printf '%s\n' "$line"
                apps_indent=$(printf '%s\n' "$line" | sed 's/[^[:space:]].*//')
                apps_is_default=$in_default
                kept_apps=
                in_apps=1
                found_apps=1
                continue
            fi

            printf '%s\n' "$line"
            update_depth_render "$line"
            if [ "$in_default" -eq 1 ] && [ "$depth" -lt "$default_depth" ]; then
                in_default=0
            fi
        done < "$render_file"

        [ "$found_default" -eq 1 ] && [ "$found_apps" -eq 1 ] || return 1
    }

    new_config=$(render_config "$config_file") || {
        echo "! Failed to render config.json"
        exit 1
    }

    cp -p "$config_file" "$backup_file" || {
        echo "! Failed to create backup: $backup_file"
        exit 1
    }

    rm -f "$tmp_file" || exit 1
    printf '%s\n' "$new_config" > "$tmp_file" || exit 1
    mv -f "$tmp_file" "$config_file" || exit 1

    echo "> Done backup $(basename "$backup_file")"
    echo "> Duplicate packages repaired across all profiles"
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