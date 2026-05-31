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
        getprop | grep "^[$prop]:" && { foundloophole=1; }
    done
    
    echo "$foundloophole"
