﻿; TODO - there is currently a 4MB/hr memory leak due to bad garbage collection for ComObjects
;      - this could be worse/better depending on usage during runtime, requires more testing

#SingleInstance Force
#WarnContinuableException Off

; ----- DO NOT EDIT: DYNAMIC INCLUDE START -----
#Include lib-custom\boot.ahk
#Include lib-custom\browser.ahk
#Include lib-custom\games.ahk
#Include lib-custom\loadscreen.ahk
#Include lib-custom\pausescreen.ahk
; ----- DO NOT EDIT: DYNAMIC INCLUDE END   -----

#Include lib-mc\confio.ahk
#Include lib-mc\thread.ahk
#Include lib-mc\display.ahk
#Include lib-mc\std.ahk
#Include lib-mc\xinput.ahk
#Include lib-mc\messaging.ahk
#Include lib-mc\program.ahk
#Include lib-mc\backup.ahk

setCurrentWinTitle(MAINNAME)

global dynamicInclude := getDynamicIncludes(A_ScriptFullPath)
global mainMessage := []

; ----- READ GLOBAL CONFIG -----
mainConfig      := Map()
mainStatus      := Map()
mainPrograms    := Map()

globalConfig := readGlobalConfig()

; initialize startup arguments
mainConfig["StartArgs"] := A_Args

; initialize basic status features

; whether or not pause screen is shown 
mainStatus["pause"] := false
; whether or not script is suspended (no actions running, changable in pause menu)
mainStatus["suspendScript"] := false

; map of current programs running & what times they were launched -> used to determine fallback on close
mainStatus["openPrograms"] := Map()

; current name of programs focused & running, used to get config -> setup hotkeys & background actions
mainStatus["currProgram"]  := ""
; name of program overriding the openProgram map -> kept separate for quick actions that should override
; all status, but retain current program stack on close (like checking manual in chrome)
mainStatus["overrideProgram"] := ""

; load screen info
mainStatus["load"] := Map()
mainStatus["load"]["show"] := false
mainStatus["load"]["text"] := "Now Loading..."

; setup status and config as maps rather than config objects for multithreading
for key, value in globalConfig.subConfigs {
    configObj := Map()
    statusObj := Map()
    
    ; if getting monitor config -> convert to monitorH and monitorW
    if (key = "Display") {
        temp := getDisplaySize(globalConfig.subConfigs["Display"])
        configObj["MonitorW"] := temp[1]
        configObj["MonitorH"] := temp[2]

        mainConfig[key] := configObj
        continue
    }
    
    ; for each subconfig (not monitor), convert to appropriate config & status objects
    for key2, value2, in value.items {
        configObj[key2] := value2
    }

    mainConfig[key] := configObj
}

; create required folders
requiredFolders := ["backup"]

if (mainConfig["General"].Has("CustomLibDir") && mainConfig["General"]["CustomLibDir"] != "") {
    requiredFolders.Push(mainConfig["General"]["CustomLibDir"])
}

if (mainConfig["Programs"].Has("ConfigDir") && mainConfig["Programs"]["ConfigDir"] != "") {
    requiredFolders.Push(mainConfig["Programs"]["ConfigDir"])
}

for value in requiredFolders {
    if (!DirExist(value)) {
        DirCreate value
    }
}

; ----- PARSE PROGRAM CONFIGS -----
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
            
            mainPrograms[tempConfig.items["name"]] := tempConfig.toMap()
        }
        else {
            ErrorMsg(A_LoopFileFullPath . " does not have required 'name' parameter")
        }
    }
}

; pre running program thread intialize xinput
xLib := xLoadLib(mainConfig["General"]["XInputDLL"])
mainControllers := xInitialize(xLib, mainConfig["General"]["MaxXInputControllers"])

; adds the list of keys to the map as a string so that the map can be enumerated
; despite being a ComObject in the threads
mainConfig       := addKeyListString(mainConfig)
mainStatus       := addKeyListString(mainStatus)
mainControllers  := addKeyListString(mainControllers)
mainPrograms     := addKeyListString(mainPrograms)

; configure objects to be used in a thread-safe manner
; TODO - is global necessary / good???
localConfig      := ObjShare(ObjShare(mainConfig))
localStatus      := ObjShare(ObjShare(mainStatus))
localControllers := ObjShare(ObjShare(mainControllers))
localPrograms    := ObjShare(ObjShare(mainPrograms))

threads := Map()

; ----- PARSE START ARGS -----
for key in StrSplit(localConfig["StartArgs"]["keys"], ",") {
    if (localConfig["StartArgs"][key] = "-backup") {
        localStatus := statusRestore(localStatus, localPrograms)
    }
    else if (localConfig["StartArgs"][key] = "-quiet") {
        localConfig["Boot"]["EnableBoot"] := false
    }
}

; ----- START CONTROLLER THEAD -----
; this thread just updates the status of each controller in a loop
threads["controllerThread"] := controllerThread(ObjShare(mainConfig), ObjShare(mainControllers))

; ----- BOOT -----
if (localConfig["Boot"]["EnableBoot"]) {
    runFunction(localConfig["Boot"]["BootFunction"])
}

; ----- START PROGRAM ----- 
; this thread updates the status mode based on checking running programs
threads["programThread"] := programThread(ObjShare(mainConfig), ObjShare(mainStatus), ObjShare(mainPrograms))

; ----- START ACTION -----
; this thread reads controller & status to determine what actions needing to be taken
; (ie. if currExecutable-Game = retroarch & Home+Start -> Save State)
threads["hotkeyThread"] := hotkeyThread(ObjShare(mainConfig), ObjShare(mainStatus), ObjShare(mainControllers))

; ----- ENABLE LISTENER -----
enableMainMessageListener()

; ----- MAIN THREAD LOOP -----
; the main thread monitors the other threads, checks that looper is running
; the main thread launches programs with appropriate settings and does any non-hotkey looping actions in the background
; probably going to need to figure out updating loadscreen?
loopSleep := localConfig["General"]["AvgLoopSleep"] * 3

backupTrigger := (loopSleep > 0) ? Round(10000 / loopSleep) : 10000
backupCount := 0

loop {
    ;perform actions based on mode & main message

    if (mainMessage.Length > 0) {
        ; do something based on main message (like launching app)
        ; style of message should probably be "Run Chrome" or "Run RetroArch Playstation C:\Rom\Crash"
        ; if first word = Run
        ;  -> second word of message would be the name of the program to launch, then all other words
        ;     would be sent to the launch command. 
        ; else 
        ;  -> send whole string to runFunction
        if (StrLower(mainMessage[1]) = "run") {
            mainMessage.RemoveAt(1)
            createProgram(mainMessage, localStatus, localPrograms)
        }
        else {
            runFunction(mainMessage)
        }

        mainMessage := []
    }

    ; need to check that threads are running
    ; i can't figure out how to re-send objshares, so for now error out
    for key, value in threads {
        try {
            value.FuncPtr("")
        }
        catch {
            ErrorMsg((
                "Thread " . key . " has crashed?"
                "I hope this isn't something i need to fix"
            ), true)
        }
    }

    ; write localStatus to file as backup cache?
    ; maybe only do it like every 10ish secs?
    backupCount += 1
    if (backupCount >= backupTrigger) {
        try statusBackup(localStatus)
        
        backupCount := 0
    }

    ; check looper
    if (localConfig["General"]["ForceMaintainMain"] && !localStatus["suspendScript"] && !WinHidden(MAINLOOP)) {
        Run A_AhkPath . " " . "mainLooper.ahk", A_ScriptDir, "Hide"
    }

    ; need sleep in order to 
    Sleep(loopSleep)
}

disableMainMessageListener()
closeAllThreads(threads)
xFreeLib(xLib)

Sleep(100)
ExitApp()