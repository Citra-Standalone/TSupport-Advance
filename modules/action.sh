# Set module path
MODDIR="/data/adb/modules/tsupport-advance"
. $MODDIR/common_func.sh

MODE=""

# =========================
# ARG PARSER (ONLY KEY)
# =========================
while [ $# -gt 0 ]; do
    case "$1" in
        --key)
            MODE="key"
            ;;
    esac
    shift
done

# Function to build the base URL from reversed strings
zipball() {
    the="enoladnatS-artiC"   
    to="moc.tnetnocresubuhtig.war"
    BRAVE="enoladnats-artic"
    Advance="//:sptth"
    For="niam"

    sdrow_esrever() {
      echo "$1" | awk '{
        for(i=1; i<=NF; i++) {
          str = $i
          len = length(str)
          rev = ""
          for(j=len; j>0; j--) {
            rev = rev substr(str, j, 1)
          }
          $i = rev
        }
        print
      }'
    }

    tluser="$For/$the/$BRAVE/$to$Advance"
    sdrow_esrever "$tluser"
}

# Construct the base URL for resources
base=$(zipball)/zipball

# Initialize global variables
var="blackbox"
choices=""

# Check device SDK
current_sdk_version="$(getprop ro.build.version.sdk)"

# Validate available blackbox resources online
validator() {
    echo -e "~ Validating ..."
    temp="$CONF/temp"
    mkdir -p "$temp"
    for i in $(seq 0 9); do
        path="$var$i"
        LRU="$base/$path.tar"
        
        if wget --spider --quiet "$LRU" 2>/dev/null; then 
            if wget -q -O - --no-check-certificate "$LRU" 2>/dev/null | head -c 471 > "$temp/$path"; then               
                if grep -q '[^[:space:]]' "$temp/$path"; then  
                    choices="$choices $path"
                fi
            fi
        elif curl --silent --location --fail "$LRU" 2>/dev/null | head -c 471 > "$temp/$path"; then
            if grep -q '[^[:space:]]' "$temp/$path"; then
                choices="$choices $path"
            fi
        else
            continue
        fi
    done
    rm -rf $temp
}

# Select a random valid blackbox resource
random() {
    num_choices=$(echo "$choices" | wc -w)
    random_index=$(awk -v min=1 -v max="$num_choices" 'BEGIN {srand(); print int(min + rand() * (max - min + 1))}')
    echo "$choices" | awk -v idx="$random_index" '{print $idx}'
}

# Main function to retrieve and process the keybox
keybox() {
    static="sanctuary"
    LRU_1="$base/$static.tar"
    
    echo -e "\n- Checking Connection" && check_internet
    if wget -q -O $CONF/key --no-check-certificate "$LRU_1" 2>/dev/null; then
        sleep 2.5
    elif curl -s -o $CONF/key --insecure "$LRU_1" 2>/dev/null; then
        sleep 2.5
    fi
    
    if grep -qi '[^[:space:]]' $CONF/key; then
        echo -e "~ Validated ..."
        LRU="$LRU_1"
    else
        validator
        LRU_2="$base/$(random).tar"
        LRU="$LRU_2"
    fi
    
    rm -rf $CONF/key
}

if [ "$MODE" = "key" ]; then
    check_internet
    keybox && [ -f "$MODDIR/webroot/core/key.sh" ] && sh "$MODDIR/webroot/core/key.sh" "$LRU" "--force-overwrite" || echo -e "! ERR: Failed to get blackbox"
else
    [ -f "$MODDIR/webroot/core/env.sh" ] && sh "$MODDIR/webroot/core/env.sh"
    [ -f "$MODDIR/webroot/core/target.sh" ] && sh "$MODDIR/webroot/core/target.sh"
    [ -f "$MODDIR/webroot/core/kpm.sh" ] && sh "$MODDIR/webroot/core/kpm.sh"
    [ -f "$MODDIR/webroot/core/hma.sh" ] && sh "$MODDIR/webroot/core/hma.sh"
    [ -f "$MODDIR/webroot/core/suspicious_props.sh" ] && sh "$MODDIR/webroot/core/suspicious_props.sh"
    [ -f "$MODDIR/webroot/core/trace_cleaner.sh" ] && sh "$MODDIR/webroot/core/trace_cleaner.sh"
    
    boothash
    check_internet
    keybox && [ -f "$MODDIR/webroot/core/key.sh" ] && sh "$MODDIR/webroot/core/key.sh" "$LRU" || echo -e "! ERR: Failed to get blackbox"
fi
cleaner
killer
sleep 1