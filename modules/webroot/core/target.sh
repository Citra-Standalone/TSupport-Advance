# Set module path
MODDIR="${0%/*}"
. $MODDIR/../../common_func.sh

# Define critical paths
CONF="/sdcard/TSupportConfig"
TARGET_DIR="/data/adb/tricky_store"
TARGET_FILE="$TARGET_DIR/target.txt"
TARGET_BACKUP="$TARGET_DIR/target.txt.bak"
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




# Check Required File.
[ ! -f "$TARGET_FILE" ] && touch "$TARGET_FILE"
[ ! -f "$CONF/customize.txt" ] && touch "$CONF/customize.txt"   
    
if { [ -d $TARGET_DIR ] || [ -d $OMK_DIR ]; } && [ -f $CONF/customize.txt ] && ! head -n 1 $CONF/customize.txt | grep -qi "^#disable"; then
    echo -e "\n=== CITarget-SmartMerge ==="
    echo "- All conditions matched"
    
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