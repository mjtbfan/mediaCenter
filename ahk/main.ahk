#SingleInstance Force

; ----- DO NOT EDIT: DYNAMIC INCLUDE START -----
#Include lib-custom\boot.ahk
#Include lib-custom\chrome.ahk
#Include lib-custom\games.ahk
#Include lib-custom\load.ahk
; -----  DO NOT EDIT: DYNAMIC INCLUDE END  -----

#Include lib-mc\confio.ahk
#Include lib-mc\std.ahk
#Include lib-mc\xinput.ahk
#Include lib-mc\messaging.ahk
#Include lib-mc\program.ahk
#Include lib-mc\data.ahk
#Include lib-mc\hotkeys.ahk

#Include lib-mc\gui\std.ahk
#Include lib-mc\gui\interface.ahk
#Include lib-mc\gui\loadscreen.ahk
#Include lib-mc\gui\pausemenu.ahk
#Include lib-mc\gui\volumemenu.ahk
#Include lib-mc\gui\controllermenu.ahk
#Include lib-mc\gui\programmenu.ahk

#Include lib-mc\mt\status.ahk
#Include lib-mc\mt\threads.ahk

SetKeyDelay 50, 50

setCurrentWinTitle(MAINNAME)
global MAINSCRIPTDIR := A_ScriptDir

global globalConfig
global globalStatus
global globalControllers
global globalPrograms
global globalRunning
global globalGuis

; ----- INITIALIZE GLOBALCONFIG (READ-ONLY) -----
mainConfig := Map()
mainConfig["StartArgs"] := A_Args

; read from global.cfg
for key, value in readGlobalConfig().subConfigs {
    configObj := Map()
    statusObj := Map()
    
    ; for each subconfig (not monitor), convert to appropriate config & status objects
    for key2, value2, in value.items {
        configObj[key2] := value2
    }

    mainConfig[key] := configObj
}

parseGUIConfig(mainConfig["GUI"])

; create required folders
requiredFolders := [expandDir("data")]

if (mainConfig["General"].Has("CustomLibDir") && mainConfig["General"]["CustomLibDir"] != "") {
    mainConfig["General"]["CustomLibDir"] := expandDir(mainConfig["General"]["CustomLibDir"])
    requiredFolders.Push(mainConfig["General"]["CustomLibDir"])
}
if (mainConfig["General"].Has("AssetDir") && mainConfig["General"]["AssetDir"] != "") {
    mainConfig["General"]["AssetDir"] := expandDir(mainConfig["General"]["AssetDir"])
    requiredFolders.Push(mainConfig["General"]["AssetDir"])
}
if (mainConfig["Programs"].Has("ConfigDir") && mainConfig["Programs"]["ConfigDir"] != "") {
    mainConfig["Programs"]["ConfigDir"] := expandDir(mainConfig["Programs"]["ConfigDir"])
    requiredFolders.Push(mainConfig["Programs"]["ConfigDir"])
}

for value in requiredFolders {
    if (!DirExist(value)) {
        DirCreate value
    }
}

; load process monitoring library for checking process lists
processLib := dllLoadLib("psapi.dll")

; load nvidia library for gpu monitoring
if (mainConfig["GUI"].Has("EnablePauseGPUMonitor") && mainConfig["GUI"]["EnablePauseGPUMonitor"]) { 
    try {
        nvLib := dllLoadLib("nvapi64.dll")
        DllCall(DllCall("nvapi64.dll\nvapi_QueryInterface", "UInt", 0x0150E828, "CDecl UPtr"), "CDecl")
    }
    catch {
        mainConfig["GUI"]["EnablePauseGPUMonitor"] := false
    }
}


; ----- INITIALIZE GLOBALSTATUS -----
mainStatus := statusInitBuffer()

; whether or not pause screen is shown 
setStatusParam("pause", false, mainStatus.Ptr)
; whether or not script is suspended (no actions running, changable in pause menu)
setStatusParam("suspendScript", false, mainStatus.Ptr)
; whether or not script is in keyboard & mouse mode
setStatusParam("kbbmode", false, mainStatus.Ptr)
; current name of programs focused & running, used to get config -> setup hotkeys & background actions
setStatusParam("currProgram", "", mainStatus.Ptr)
; load screen info
setStatusParam("loadShow", false, mainStatus.Ptr)
setStatusParam("loadText", (mainConfig["GUI"].Has("DefaultLoadText")) ? mainConfig["GUI"]["DefaultLoadText"] : "Now Loading...", mainStatus.Ptr)
; error info
setStatusParam("errorShow", false, mainStatus.Ptr)
setStatusParam("errorHwnd", 0, mainStatus.Ptr)
; time to hold a hotkey for it to trigger
setStatusParam("buttonTime", 70, mainStatus.Ptr)
; current hotkeys
setStatusParam("currHotkeys", Map(), mainStatus.Ptr)
; current active gui
setStatusParam("currGui", "", mainStatus.Ptr)
; some function that should be digested by a thread
setStatusParam("internalMessage", "", mainStatus.Ptr)


; ----- INITIALIZE GLOBALCONTROLLERS -----
mainControllers  := xInitBuffer(mainConfig["General"]["MaxXInputControllers"])


; ----- INITIALIZE PROGRAM CONFIGS -----
globalRunning  := Map()
globalPrograms := Map()
globalGuis     := Map()

; read program configs from ConfigDir
if (mainConfig["Programs"].Has("ConfigDir") && mainConfig["Programs"]["ConfigDir"] != "") {
    loop files validateDir(mainConfig["Programs"]["ConfigDir"]) . "*", "FR" {
        tempConfig := readConfig(A_LoopFileFullPath,, "json")
        tempConfig.cleanAllItems(true)

        if (tempConfig.items.Has("name") || tempConfig.items["name"] != "") {

            if (mainConfig["Programs"].Has("SettingListDir") && mainConfig["Programs"]["SettingListDir"] != "") {
                for key, value in tempConfig.items {
                    tempConfig.items[key] := cleanSetting(value, mainConfig["Programs"]["SettingListDir"])
                }
            }

            ; convert array of exe to map for efficient lookup
            if (tempConfig.items.Has("exe") && Type(tempConfig.items["exe"]) = "Array") {
                tempMap := Map()

                for item in tempConfig.items["exe"] {
                    tempMap[item] := ""
                }

                tempConfig.items["exe"] := tempMap
            }

            ; convert array of wndw to map for efficient lookup
            if (tempConfig.items.Has("wndw") && Type(tempConfig.items["wndw"]) = "Array") {
                tempMap := Map()

                for item in tempConfig.items["wndw"] {
                    tempMap[item] := ""
                }

                tempConfig.items["wndw"] := tempMap
            }
            
            globalPrograms[tempConfig.items["name"]] := tempConfig.toMap()
        }
        else {
            ErrorMsg(A_LoopFileFullPath . " does not have required 'name' parameter")
        }
    }
}

; ----- INITIALIZE THREADS -----
; configure objects to be used in a thread-safe manner
;  read-only objects can be used w/ ObjShare 
;  read/write objects must be a buffer ptr w/ custom getters/setters
globalConfig      := ObjShare(ObjShare(mainConfig))
globalStatus      := mainStatus.Ptr
globalControllers := mainControllers.Ptr

; ----- PARSE START ARGS -----
for key, value in globalConfig["StartArgs"] {
    if (value = "-backup") {
        statusRestore()
    }
    else if (value = "-quiet") {
        globalConfig["Boot"]["EnableBoot"] := false
    }
}

if (!globalConfig["StartArgs"].Has("-quiet") && globalConfig["GUI"].Has("EnableLoadScreen") && globalConfig["GUI"]["EnableLoadScreen"]) {
    createLoadScreen()
}

; ----- START CONTROLLER THEAD -----
; this thread just updates the status of each controller in a loop
controllerThreadRef := controllerThread(ObjShare(mainConfig), mainControllers.Ptr)

; ----- START HOTKEY THREAD -----
; this thread reads controller & status to determine what actions needing to be taken
; (ie. if currExecutable-Game = retroarch & Home+Start -> Save State)
hotkeyThreadRef := hotkeyThread(ObjShare(mainConfig), mainStatus.Ptr, mainControllers.Ptr)

; ----- BOOT -----
if (globalConfig["Boot"]["EnableBoot"]) {
    runFunction(globalConfig["Boot"]["BootFunction"])
}

; ----- ENABLE LISTENER -----
; message sent from send2Main
global externalMessage := []

enableMainMessageListener()

; ----- ENABLE BACKUP -----
SetTimer(BackupTimer, 10000)

; ----- MAIN THREAD LOOP -----
; the main thread monitors the other threads, checks that looper is running
; the main thread launches programs with appropriate settings and does any non-hotkey looping actions in the background
; probably going to need to figure out updating loadscreen?

forceMaintain := globalConfig["General"]["ForceMaintainMain"]
forceActivate := globalConfig["General"]["ForceActivateWindow"]

checkErrors   := globalConfig["Programs"].Has("ErrorList") && globalConfig["Programs"]["ErrorList"] != ""

loopSleep     := Round(globalConfig["General"]["AvgLoopSleep"])

checkAllCount := 0
loop {
    ; --- CHECK MESSAGES ---

    ; do something based on external message (like launching app)
    ; style of message should probably be "Run Chrome" or "Run RetroArch Playstation C:\Rom\Crash"
    if (externalMessage.Length > 0) {
        if (StrLower(externalMessage[1]) = "run") {
            externalMessage.RemoveAt(1)
            createProgram(joinArray(externalMessage))
        }
        else {
            runFunction(externalMessage)
        }

        ; reset message after processing
        externalMessage := []

        continue
    }

    internalMessage := getStatusParam("internalMessage")
    if (internalMessage != "") {
        currProgram := getStatusParam("currProgram")
        currGui     := getStatusParam("currGui")

        if (StrLower(internalMessage) = "pause") {
            if (!globalGuis.Has(GUIPAUSETITLE)) {
                createPauseMenu()
            }
            else {
                destroyPauseMenu()
            }
        }
        else if (StrLower(internalMessage) = "exit") {
            if (getStatusParam("errorShow")) {
                errorHwnd := getStatusParam("errorHwnd")
                errorGUI := getGUI(errorHwnd)

                if (errorGUI) {
                    errorGUI.Destroy()
                }
                else {
                    CloseErrorMsg(errorHwnd)
                }
            }

            else if (currProgram != "") {
                try globalRunning[currProgram].exit()
            }
        }
        else if (StrLower(internalMessage) = "nuclear") {
            killed := false
            if (!killed && getStatusParam("errorShow")) {
                try {
                    errorPID := WinGetPID("ahk_id " getStatusParam("errorHwnd"))
                    ProcessKill(errorPID)

                    killed := true
                }
            }

            if (!killed && currProgram != "") {
                ProcessKill(globalRunning[currProgram].getPID())
                killed := true
            }

            ; TODO - gui notification that drastic measures have been taken

            if (!killed) {
                ProcessKill(WinGetPID(WinHidden(MAINNAME)))
            }
        }
        else if (StrLower(SubStr(internalMessage, 1, 4)) = "gui.") {
            tempArr  := StrSplit(internalMessage, A_Space)
            tempFunc := tempArr.RemoveAt(1)
            
            globalGuis[currGui].%StrReplace(tempFunc, "gui.", "")%(tempArr*)
        }
        else if (StrLower(SubStr(internalMessage, 1, 8)) = "program.") {
            tempArr  := StrSplit(internalMessage, A_Space)
            tempFunc := tempArr.RemoveAt(1)

            globalRunning[currProgram].%StrReplace(tempFunc, "program.", "")%(tempArr*)
        }
        else {
            runFunction(internalMessage)
        }

        if (getStatusParam("internalMessage") != internalMessage) {
            continue
        }

        ; reset message after processing
        setStatusParam("internalMessage", "")

        continue
    }
    
    Sleep(loopSleep)

    activeSet := false
    currHotkeys := defaultHotkeys(globalConfig)

    ; --- CHECK OVERRIDE ---
    currError := getStatusParam("errorShow")

    ; if errors should be detected, set error here
    if (!currError && checkErrors) {
        resetTMM := A_TitleMatchMode

        SetTitleMatchMode 2
        for key, value in globalConfig["Programs"]["ErrorList"] {

            wndwHWND := WinShown(value)
            if (!wndwHWND) {
                wndwHWND := WinShown(StrLower(value))
            }

            if (wndwHWND > 0) {
                setStatusParam("errorShow", true)
                setStatusParam("errorHwnd", wndwHWND)
                
                break
            }
        }
        SetTitleMatchMode resetTMM
    }

    if (currError) {
        errorHwnd := getStatusParam("errorHwnd")

        if (WinShown("ahk_id " errorHwnd)) {
            if (!activeSet) {
                if (forceActivate && !WinActive("ahk_id " errorHwnd)) {
                    WinActivate("ahk_id " errorHwnd)
                }

                currHotkeys := addHotkeys(currHotkeys, errorHotkeys())

                setStatusParam("buttonTime", 25)
                activeSet := true
            }
        }
        else {
            setStatusParam("errorShow", false)
            setStatusParam("errorHwnd", 0)
        }
    }

    ; activate load screen if its supposed to be shown
    if (!activeSet && getStatusParam("loadShow")) {
        updateLoadScreen()
        activeSet := true
    }

    ; --- CHECK ALL OPEN ---
    currProgram := getStatusParam("currProgram")
    currGui     := getStatusParam("currGui")

    if (checkAllCount > 20 || (currProgram = "" && currGui = "")) {
        checkAllGuis()

        mostRecentGui := getMostRecentGui()
        if (mostRecentGui != currGui) {
            setStatusParam("currGui", mostRecentGui)
        }

        checkAllPrograms()

        mostRecentProgram := getMostRecentProgram()
        if (mostRecentProgram != currProgram) {
            setStatusParam("currProgram", mostRecentProgram)
        }

        checkAllCount := 0
    }

    ; --- CHECK OPEN GUIS ---
    if (currGui != "") {
        if (globalGuis.Has(currGui) && WinShown(currGui)) {
            if (!activeSet) {
                if (forceActivate && !WinActive(currGui)) {
                    try WinActivate(currGui)
                }

                if (globalGuis[currGui].hotkeys.Count > 0) {
                    currHotkeys := addHotkeys(currHotkeys, globalGuis[currGui].hotkeys)
                }

                if (!globalGuis[currGui].allowPause) {
                    for key, value in currHotkeys {
                        if (value = "Pause") {
                            currHotkeys.Delete(key)
                            break
                        }
                    }
                }

                setStatusParam("buttonTime", 25)
                activeSet := true
            }
        } 
        else {
            if (globalGuis.Has(currGui)) {
                globalGuis[currGui].Destroy()
                globalGuis.Delete(currGui)
            }

            checkAllGuis()

            mostRecentGui := getMostRecentGui()
            if (mostRecentGui != currGui) {
                setStatusParam("currGui", mostRecentGui)
            }
            else {
                setStatusParam("currGui", "")
            }
        }
    }

    ; --- CHECK OPEN PROGRAMS ---
    if (currProgram != "" && !getStatusParam("suspendScript")) {
        if (globalRunning.Has(currProgram)) {
            if (globalRunning[currProgram].exists()) {
                if (!activeSet) {
                    if (forceActivate) {
                        try globalRunning[currProgram].restore()
                    }

                    if (globalRunning[currProgram].hotkeys.Count > 0) {
                        currHotkeys := addHotkeys(currHotkeys, globalRunning[currProgram].hotkeys)
                    }

                    if (!globalRunning[currProgram].allowPause) {
                        for key, value in currHotkeys {
                            if (value = "Pause") {
                                currHotkeys.Delete(key)
                                break
                            }
                        }
                    }

                    setStatusParam("buttonTime", 70)
                    activeSet := true
                }
            }
            else {
                checkAllPrograms()

                mostRecentProgram := getMostRecentProgram()
                if (mostRecentProgram != currProgram) {
                    setStatusParam("currProgram", mostRecentProgram)
                }
                else {
                    setStatusParam("currProgram", "")
                }
            }
        } 
        else {
            createProgram(currProgram, false, false)
        }
    }

    ; --- CHECK HOTKEYS ---
    statusHotkeys := getStatusParam("currHotkeys")

    statusKeys := []
    statusVals := []
    for key, value in statusHotkeys {
        statusKeys.Push(key)
        statusVals.Push(value)
    }

    currKeys := []
    currVals := []
    for key, value in currHotkeys {
        currKeys.Push(key)
        currVals.Push(value)
    }

    if (!arrayEquals(statusKeys, currKeys) || !arrayEquals(statusVals, currVals)) {
        setStatusParam("currHotkeys", currHotkeys)
    }

    ; --- CHECK THREADS ---
    try {
        controllerThreadRef.FuncPtr("")
    }
    catch {
        controllerThreadRef := controllerThread(ObjShare(mainConfig), globalControllers)
    }
    try {
        hotkeyThreadRef.FuncPtr("")
    }
    catch {
        hotkeyThreadRef := hotkeyThread(ObjShare(mainConfig), globalStatus, globalControllers)
    }

    ; --- CHECK LOOPER ---
    if (forceMaintain && !WinHidden(MAINLOOP)) {
        Run A_AhkPath . A_Space . "mainLooper.ahk", A_ScriptDir, "Hide"
    }
 
    checkAllCount += 1
    Sleep(loopSleep)
}

disableMainMessageListener()

try controllerThreadRef.ExitApp()
try hotkeyThreadRef.ExitApp()

dllFreeLib(processLib)

if (globalConfig["GUI"].Has("EnablePauseGPUMonitor") && globalConfig["GUI"]["EnablePauseGPUMonitor"]) {
    dllFreeLib(nvLib)
}

Sleep(100)
ExitApp()

; write globalStatus/globalRunning to file as backup cache?
; maybe only do it like every 10ish secs?
BackupTimer() {    
    try statusBackup()
    return
}