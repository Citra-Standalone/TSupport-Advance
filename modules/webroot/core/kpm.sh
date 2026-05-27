# Import common function
MODDIR="${0%/*}"
. $MODDIR/../../common_func.sh

dir="/data/adb/kp-next"
path="$dir/package_config"
applist="
com.android.vending
com.google.android.gms
com.google.android.gms.persistent
com.google.android.gms.unstable
com.google.android.gsf
com.google.android.ims
com.google.android.contactkeys
com.google.android.safetycore
com.google.android.rkpdapp
com.google.android.widevine
com.google.android.apps.messaging
com.google.android.apps.messaging:rcs
com.google.android.apps.walletnfcrel
com.google.android.googlequicksearchbox
"

apply() {
    for package in $applist; do
        uid=$(dumpsys package "$package" 2>/dev/null | grep -m 1 'uid' | cut -d'=' -f2 | cut -d' ' -f1)
    
        if [ -z "$uid" ]; then
            continue
        fi
        
        notExpected="$package,1,1,$uid"
        expected="$package,1,0,$uid"
    
        if grep -q -F "$expected" "$path"; then
            continue
        fi
        
        liner "$notExpected" "$path" "$expected"
    done
}

if [ ! -d "$dir" ]; then
    :
elif [ ! -f "$path" ]; then
    echo "pkg,exclude,allow,uid" > $path
else
    echo -e "\n- Loading KPatch Config"
    apply && echo "- Successfully loaded." || echo "! Fail to load !"
    
fi