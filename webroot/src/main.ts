import { exec } from "kernelsu-alt";

/* =========================
   BASE PATH
========================= */
const BASE = "/data/adb/modules/tsupport-advance/";

/* =========================
   STATE
========================= */
let isRunning = false;

/* =========================
   ELEMENTS
========================= */
const consoleBox = document.getElementById("console") as HTMLDivElement;
const statusBox = document.getElementById("status") as HTMLSpanElement;
const clearBtn = document.getElementById("clearBtn") as HTMLButtonElement;
const scroller = document.querySelector(".scroll-wrapper") as HTMLDivElement;
const pages = document.querySelectorAll(".page");

/* =========================
   DEVICE INFO
========================= */
const warningBox = document.getElementById("warning-box") as HTMLDivElement;
const moduleDescription = document.getElementById("module-description") as HTMLSpanElement;
const rootMode = document.getElementById("rootMode") as HTMLSpanElement;
const tspVersion = document.getElementById("tsp-version") as HTMLSpanElement;
const romSign = document.getElementById("rom-sign") as HTMLSpanElement;
const selinuxStatus = document.getElementById("selinux-status") as HTMLSpanElement;
const teeStatus = document.getElementById("tee-status") as HTMLSpanElement;
const hmaStatus = document.getElementById("hma-status") as HTMLSpanElement;

/* =========================
   Check Function
========================= */
async function syncModuleDescription() {
    const result: any = await exec(`
    grep '^description=' ${BASE}/module.prop | cut -d= -f2-
    `);
    moduleDescription.textContent = String(result.stdout || result).trim();
}

async function checkSuspicousProps() {
    const result: any = await exec(`
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
    `);
    
    const a = String(result.stdout || result).trim()
    
    if ( a === "1" ) {
        warningBox.style.display = "flex";
    } else {
        warningBox.style.display = "none";
    }
    
}

async function checkRootMode() {
    const result: any = await exec(`
    if [ -d "/data/adb/ksu" ]; then
        echo "KernelSU"
    elif [ -f "/data/adb/ap/version" ]; then
        echo "Apatch"
    else
        echo "Magisk"
    fi
    `);
    rootMode.textContent = String(result.stdout || result).trim();
    rootMode.style.color = "#00ff88";
}

async function checkTspVersion() {
    const result: any = await exec(`
    MODDIR=${BASE}
    VERNAME=$(grep 'version=' $MODDIR/module.prop | cut -d '=' -f 2)
    VERCODE=$(grep 'versionCode=' $MODDIR/module.prop | cut -d '=' -f 2)
    echo "$VERNAME($VERCODE)"
    `);
    tspVersion.textContent = String(result.stdout || result).trim();
    tspVersion.style.color = "#00ff88";
}

async function checkRomSign() {
    const result: any = await exec(`
    ROM_SIGN_PATH="/system/etc/security"
    if unzip -l $ROM_SIGN_PATH/otacerts.zip | grep -q "testkey" ; then
        echo -e "testkey"
    elif unzip -l $ROM_SIGN_PATH/otacerts.zip | grep -q "releasekey" ; then
        echo -e "releasekey"
    else
        echo -e "unknown"
    fi
    `);
    status = String(result.stdout || result).trim();
    romSign.textContent = status
    
    if (status === "releasekey") {
        romSign.style.color = "#00ff88";
    } else if (status === "testkey") {
        romSign.style.color = "#ffff00";
    } else {
        romSign.style.color = "#888888";
    }
}

async function checkSelinuxStatus() {
    const result: any = await exec(`getenforce`);
    const status = String(result.stdout || result).trim();
    
    selinuxStatus.textContent = status;

    if (status === "Enforcing") {
        selinuxStatus.style.color = "#00ff88";
    } else if (status === "Permissive") {
        selinuxStatus.style.color = "#ff4444";
    } else {
        selinuxStatus.style.color = "#888888";
    }
}


async function checkTeeStatus() {
    const result: any = await exec(`
    TARGET_DIR="/data/adb/tricky_store"
    if [ -d "$TARGET_DIR" ] && grep -q "teeBroken=true" "$TARGET_DIR/tee_status" || [ -d "$TARGET_DIR" ] && grep -q "tee_broken=true" "$TARGET_DIR/tee_status.txt"; then
        echo "broken"
    elif [ -d "$TARGET_DIR" ] && grep -q "teeBroken=false" "$TARGET_DIR/tee_status" || [ -d "$TARGET_DIR" ] && grep -q "tee_broken=false" "$TARGET_DIR/tee_status.txt"; then
        echo "normal"
    else
        echo "unknown"
    fi
    `);
    const status = String(result.stdout || result).trim();
    teeStatus.textContent = status;

    if (status === "normal") {
        teeStatus.style.color = "#00ff88";
    } else if (status === "broken") {
        teeStatus.style.color = "#ffff00";
    } else {
        teeStatus.style.color = "#888888";
    }
}

async function checkHmaStatus() {
    const result: any = await exec(`
    if [ -d "/data/data/com.google.android.hmal" ] || [ -d "/data/data/com.tsng.hidemyapplist" ] || [ -d "/data/data/org.frknkrc44.hma_oss" ]; then
        echo "Installed"
    else
        echo "Not Detected"
    fi
    `);
    status = String(result.stdout || result).trim();
    hmaStatus.textContent = status
    
    if (status === "Installed") {
        hmaStatus.style.color = "#00ff88";
    } else {
        hmaStatus.style.color = "#ffff00";
    }
}

/* =========================
   On Web Loaded
========================= */
document.addEventListener("DOMContentLoaded", () => {
    syncModuleDescription();
    checkSuspicousProps();
    checkRootMode();
    checkTspVersion();
    checkRomSign();
    checkSelinuxStatus();
    checkTeeStatus();
    checkHmaStatus();
});

/* =========================
   NEXT FRAME HELPER
========================= */
function nextFrame() {
    return new Promise<void>(resolve => requestAnimationFrame(() => resolve()));
}

/* =========================
   SCROLL TO OUTPUT PAGE
========================= */
function goToOutput() {
    const target = pages[1] as HTMLElement;
    if (!target || !scroller) return;

    scroller.scrollTo({
        top: target.offsetTop,
        behavior: "smooth"
    });
}

/* =========================
   LOG
========================= */
function log(text: string) {
    consoleBox.textContent += text + "\n";
    consoleBox.scrollTop = consoleBox.scrollHeight;
}

/* =========================
   UI LOCK
========================= */
function setUI(state: boolean) {
    document.querySelectorAll(".tool-card").forEach(card => {
        card.classList.toggle("disabled", !state);
    });

    statusBox.textContent = state ? "IDLE" : "RUNNING...";
}

/* =========================
   SLEEP
========================= */
function sleep(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

/* =========================
   RUN COMMAND
========================= */
async function run(cmd: string, actionName: string) {

    if (isRunning) return;

    isRunning = true;
    setUI(false);

    log(`- ${actionName}`);

    goToOutput();

    try {
        await nextFrame();
        
        await sleep(500);

        const result: any = await exec(`cd ${BASE} && ${cmd}`);

        if (typeof result === "string") {
            log(result);
        } else {
            if (result?.stdout) log(result.stdout);
            if (result?.stderr) log("\nERR:\n" + result.stderr);
        }

    } catch (e) {
        log("ERROR: " + String(e));
    } finally {
        await sleep(600);

        isRunning = false;
        setUI(true);

        log("\n[✓] DONE\n");
    }
}

/* =========================
   BUTTON EVENTS
========================= */
let countdownTimer: any;

document.getElementById("warning-box")?.addEventListener("click", () => {
    const scroller = document.querySelector(".scroll-wrapper") as HTMLDivElement;
    const popup = document.getElementById("popup-overlay") as HTMLDivElement;
    const btnYes = document.getElementById("btn-yes") as HTMLButtonElement;
    
    popup.style.display = "flex";
    if (scroller) scroller.style.overflow = "hidden";
    let timeLeft = 5;        
    btnYes.disabled = true;
    btnYes.textContent = `YES (${timeLeft})`;
    clearInterval(countdownTimer);
    countdownTimer = setInterval(() => {
        timeLeft--;
            
        if (timeLeft > 0) {
            btnYes.textContent = `YES (${timeLeft})`;
        } else {
           clearInterval(countdownTimer);
            btnYes.disabled = false;
            btnYes.textContent = "YES";
        }
    }, 1000);
});

document.getElementById("btn-no")?.addEventListener("click", () => {
    const scroller = document.querySelector(".scroll-wrapper") as HTMLDivElement;
    const popup = document.getElementById("popup-overlay") as HTMLDivElement;
    
    popup.style.display = "none";
    if (scroller) scroller.style.overflow = "auto";
    clearInterval(countdownTimer); 
});


document.getElementById("btn-yes")?.addEventListener("click", async () => {
    const buttonNo = document.getElementById("btn-no") as HTMLButtonElement;
    const buttonYes = document.getElementById("btn-yes") as HTMLButtonElement; 
    const textOriginal = document.getElementById("text-original") as HTMLSpanElement;
    const textLoading = document.getElementById("text-loading") as HTMLSpanElement;
    
    buttonNo.style.display = "none";
    buttonYes.style.display = "none";
    textOriginal.style.display = "none";
    textLoading.style.display = "block";
    textLoading.style.color = "#00c6ff"; 
    
    const result: any = await exec(`
    
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
    `);
    

    const output = typeof result === "string" ? result : (result?.stdout || "Done.");
    
    textLoading.style.color = "#00ff88"; 
    textLoading.innerHTML = output.trim().replace(/\n/g, "<br>");
    
    const buttonClose = document.getElementById("btn-close") as HTMLButtonElement;
    if (buttonClose) buttonClose.style.display = "block";
});

document.getElementById("btn-close")?.addEventListener("click", () => {
    const scroller = document.querySelector(".scroll-wrapper") as HTMLDivElement;
    const popup = document.getElementById("popup-overlay") as HTMLDivElement;
    const warningBox = document.getElementById("warning-box") as HTMLDivElement;
    const textOriginal = document.getElementById("text-original") as HTMLSpanElement;
    const textLoading = document.getElementById("text-loading") as HTMLSpanElement;
    const buttonNo = document.getElementById("btn-no") as HTMLButtonElement;
    const buttonYes = document.getElementById("btn-yes") as HTMLButtonElement;
    const buttonClose = document.getElementById("btn-close") as HTMLButtonElement;

    warningBox.style.display = "none";
    popup.style.display = "none";
    
    textLoading.style.display = "none";
    textOriginal.style.display = "block";
    buttonNo.style.display = "block";
    buttonYes.style.display = "block";
    buttonClose.style.display = "none";
    
    textLoading.textContent = "Please wait, script running ..."; 
    if (scroller) scroller.style.overflow = "auto";
});

// document.querySelector(".module-info")?.addEventListener("click", () => {
    // warningBox.style.setProperty("display", "flex");
// });

document.getElementById("btnTarget")?.addEventListener("click", () => {
    run("sh webroot/core/target.sh", "Sync Target.txt");
});

document.getElementById("btnKPM")?.addEventListener("click", () => {
    run("sh webroot/core/kpm.sh", "Sync KPM");
});

document.getElementById("btnHMA")?.addEventListener("click", () => {
    run("sh webroot/core/hma.sh", "Sync HMA");
});

document.getElementById("btnKeybox")?.addEventListener("click", () => {
    run("sh action.sh --key", "Retrieve Keybox");
});

/* =========================
   CLEAR
========================= */
clearBtn?.addEventListener("click", () => {
    consoleBox.textContent = "";
});
