(function(){let e=document.createElement(`link`).relList;if(e&&e.supports&&e.supports(`modulepreload`))return;for(let e of document.querySelectorAll(`link[rel="modulepreload"]`))n(e);new MutationObserver(e=>{for(let t of e)if(t.type===`childList`)for(let e of t.addedNodes)e.tagName===`LINK`&&e.rel===`modulepreload`&&n(e)}).observe(document,{childList:!0,subtree:!0});function t(e){let t={};return e.integrity&&(t.integrity=e.integrity),e.referrerPolicy&&(t.referrerPolicy=e.referrerPolicy),e.crossOrigin===`use-credentials`?t.credentials=`include`:e.crossOrigin===`anonymous`?t.credentials=`omit`:t.credentials=`same-origin`,t}function n(e){if(e.ep)return;e.ep=!0;let n=t(e);fetch(e.href,n)}})();var e=0;function t(t){return`${t}_callback_${Date.now()}_${e++}`}function n(e,n={}){return new Promise((r,i)=>{let a=t(`exec`);window[a]=(e,t,n)=>{r({errno:e,stdout:t,stderr:n}),o(a)};function o(e){delete window[e]}try{typeof ksu<`u`?ksu.exec(e,JSON.stringify(n),a):r({errno:1,stdout:``,stderr:`ksu is not defined`})}catch(e){i(e),o(a)}})}var r=`/data/adb/modules/tsupport-advance/`,i=!1,a=document.getElementById(`console`),o=document.getElementById(`status`),s=document.getElementById(`clearBtn`),c=document.querySelector(`.scroll-wrapper`),l=document.querySelectorAll(`.page`),u=document.getElementById(`warning-box`),d=document.getElementById(`module-description`),f=document.getElementById(`rootMode`),p=document.getElementById(`tsp-version`),m=document.getElementById(`rom-sign`),h=document.getElementById(`selinux-status`),g=document.getElementById(`tee-status`),_=document.getElementById(`hma-status`);async function v(){let e=await n(`
    grep '^description=' ${r}/module.prop | cut -d= -f2-
    `);d.textContent=String(e.stdout||e).trim()}async function y(){let e=await n(`
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
    
    echo "$foundloophole"
    `);String(e.stdout||e).trim()===`1`?u.style.display=`flex`:u.style.display=`none`}async function b(){let e=await n(`
    if [ -d "/data/adb/ksu" ]; then
        echo "KernelSU"
    elif [ -f "/data/adb/ap/version" ]; then
        echo "Apatch"
    else
        echo "Magisk"
    fi
    `);f.textContent=String(e.stdout||e).trim(),f.style.color=`#00ff88`}async function x(){let e=await n(`
    MODDIR=${r}
    VERNAME=$(grep 'version=' $MODDIR/module.prop | cut -d '=' -f 2)
    VERCODE=$(grep 'versionCode=' $MODDIR/module.prop | cut -d '=' -f 2)
    echo "$VERNAME($VERCODE)"
    `);p.textContent=String(e.stdout||e).trim(),p.style.color=`#00ff88`}async function S(){let e=await n(`
    ROM_SIGN_PATH="/system/etc/security"
    if unzip -l $ROM_SIGN_PATH/otacerts.zip | grep -q "testkey" ; then
        echo -e "testkey"
    elif unzip -l $ROM_SIGN_PATH/otacerts.zip | grep -q "releasekey" ; then
        echo -e "releasekey"
    else
        echo -e "unknown"
    fi
    `);status=String(e.stdout||e).trim(),m.textContent=status,status===`releasekey`?m.style.color=`#00ff88`:status===`testkey`?m.style.color=`#ffff00`:m.style.color=`#888888`}async function C(){let e=await n(`getenforce`),t=String(e.stdout||e).trim();h.textContent=t,t===`Enforcing`?h.style.color=`#00ff88`:t===`Permissive`?h.style.color=`#ff4444`:h.style.color=`#888888`}async function w(){let e=await n(`
    TARGET_DIR="/data/adb/tricky_store"
    if [ -d "$TARGET_DIR" ] && grep -q "teeBroken=true" "$TARGET_DIR/tee_status" || [ -d "$TARGET_DIR" ] && grep -q "tee_broken=true" "$TARGET_DIR/tee_status.txt"; then
        echo "broken"
    elif [ -d "$TARGET_DIR" ] && grep -q "teeBroken=false" "$TARGET_DIR/tee_status" || [ -d "$TARGET_DIR" ] && grep -q "tee_broken=false" "$TARGET_DIR/tee_status.txt"; then
        echo "normal"
    else
        echo "unknown"
    fi
    `),t=String(e.stdout||e).trim();g.textContent=t,t===`normal`?g.style.color=`#00ff88`:t===`broken`?g.style.color=`#ffff00`:g.style.color=`#888888`}async function T(){let e=await n(`
    if [ -d "/data/data/com.google.android.hmal" ] || [ -d "/data/data/com.tsng.hidemyapplist" ] || [ -d "/data/data/org.frknkrc44.hma_oss" ]; then
        echo "Installed"
    else
        echo "Not Detected"
    fi
    `);status=String(e.stdout||e).trim(),_.textContent=status,status===`Installed`?_.style.color=`#00ff88`:_.style.color=`#ffff00`}document.addEventListener(`DOMContentLoaded`,()=>{v(),y(),b(),x(),S(),C(),w(),T()});function E(){return new Promise(e=>requestAnimationFrame(()=>e()))}function D(){let e=l[1];!e||!c||c.scrollTo({top:e.offsetTop,behavior:`smooth`})}function O(e){a.textContent+=e+`
`,a.scrollTop=a.scrollHeight}function k(e){document.querySelectorAll(`.tool-card`).forEach(t=>{t.classList.toggle(`disabled`,!e)}),o.textContent=e?`IDLE`:`RUNNING...`}function A(e){return new Promise(t=>setTimeout(t,e))}async function j(e,t){if(!i){i=!0,k(!1),O(`- ${t}`),D();try{await E(),await A(500);let t=await n(`cd ${r} && ${e}`);typeof t==`string`?O(t):(t?.stdout&&O(t.stdout),t?.stderr&&O(`
ERR:
`+t.stderr))}catch(e){O(`ERROR: `+String(e))}finally{await A(600),i=!1,k(!0),O(`
[✓] DONE
`)}}}var M;document.getElementById(`warning-box`)?.addEventListener(`click`,()=>{let e=document.querySelector(`.scroll-wrapper`),t=document.getElementById(`popup-overlay`),n=document.getElementById(`btn-yes`);t.style.display=`flex`,e&&(e.style.overflow=`hidden`);let r=5;n.disabled=!0,n.textContent=`YES (${r})`,clearInterval(M),M=setInterval(()=>{r--,r>0?n.textContent=`YES (${r})`:(clearInterval(M),n.disabled=!1,n.textContent=`YES`)},1e3)}),document.getElementById(`btn-no`)?.addEventListener(`click`,()=>{let e=document.querySelector(`.scroll-wrapper`),t=document.getElementById(`popup-overlay`);t.style.display=`none`,e&&(e.style.overflow=`auto`),clearInterval(M)}),document.getElementById(`btn-yes`)?.addEventListener(`click`,async()=>{let e=document.getElementById(`btn-no`),t=document.getElementById(`btn-yes`),r=document.getElementById(`text-original`),i=document.getElementById(`text-loading`);e.style.display=`none`,t.style.display=`none`,r.style.display=`none`,i.style.display=`block`,i.style.color=`#00c6ff`;let a=await n(`
    
    delete_target() {
        [ -n "$1" ] && rm -rf "$1" 2>/dev/null
    }
    
    sus_props="
    persist.hyperceiler.log.level
    persist.sys.vold_app_data_isolation_enabled
    persist.zygote.app_data_isolation
    persist.com.luckyzyx.luckytool.log.level
    persist.com.luckyzyx.luckytool.debug
    persist.com.luckyzyx.luckytool.enable
    "
    
    cat "/data/property/persistent_properties" > "/data/property/persistent_properties.bak"    
    delete_target "/data/property/persistent_properties"

    echo "- Cleaning is successful, reboot to take effect."
    `),o=typeof a==`string`?a:a?.stdout||`Done.`;i.style.color=`#00ff88`,i.innerHTML=o.trim().replace(/\n/g,`<br>`);let s=document.getElementById(`btn-close`);s&&(s.style.display=`block`)}),document.getElementById(`btn-close`)?.addEventListener(`click`,()=>{let e=document.querySelector(`.scroll-wrapper`),t=document.getElementById(`popup-overlay`),n=document.getElementById(`warning-box`),r=document.getElementById(`text-original`),i=document.getElementById(`text-loading`),a=document.getElementById(`btn-no`),o=document.getElementById(`btn-yes`),s=document.getElementById(`btn-close`);n.style.display=`none`,t.style.display=`none`,i.style.display=`none`,r.style.display=`block`,a.style.display=`block`,o.style.display=`block`,s.style.display=`none`,i.textContent=`Please wait, script running ...`,e&&(e.style.overflow=`auto`)}),document.getElementById(`btnTarget`)?.addEventListener(`click`,()=>{j(`sh webroot/core/target.sh`,`Sync Target.txt`)}),document.getElementById(`btnKPM`)?.addEventListener(`click`,()=>{j(`sh webroot/core/kpm.sh`,`Sync KPM`)}),document.getElementById(`btnHMA`)?.addEventListener(`click`,()=>{j(`sh webroot/core/hma.sh`,`Sync HMA`)}),document.getElementById(`btnKeybox`)?.addEventListener(`click`,()=>{j(`sh action.sh --key`,`Retrieve Keybox`)}),s?.addEventListener(`click`,()=>{a.textContent=``});