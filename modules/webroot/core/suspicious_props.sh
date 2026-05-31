# Set module path
MODDIR="${0%/*}"
. $MODDIR/../../common_func.sh

sus_props="
persist.hyperceiler.log.level
persist.sys.vold_app_data_isolation_enabled
persist.zygote.app_data_isolation
persist.com.luckyzyx.luckytool.log.level
persist.com.luckyzyx.luckytool.debug
persist.com.luckyzyx.luckytool.enable
persist.sys.omk.restart.all
persist.sys.omk.restart.injector
persist.sys.omk.restart.keymint
"
foundloophole=0

for prop in $sus_props; do
    getprop | grep -Fq "[$prop]:" && { foundloophole=1; }
done

if [ "$foundloophole" -eq 1 ]; then
    selection=0
    key "Found suspicious prop, you want to fix ?" "YES" "NO" selection
    
    if [ $selection -eq 1 ]; then
        cat "/data/property/persistent_properties" > "/data/property/persistent_properties.bak"
        for prop in $sus_props; do
            delete_target "/data/property/persistent_properties"
        done
    fi
fi