; creates an executable generic object that gets added to mainRunning
; this executable object will contain a lot of the generic features taken from executable json files
; each function & more in json files has default version as well
class Program {
    ; attributes
    name    := ""
    dir     := ""
    exe     := ""
    wndw    := ""
    time    := 0

    background := false

    enablePause   := true
    enableTooltip := true

    pauseOptions := Map()
    hotkeys      := Map()

    tooltipInner := ""

    ; functions
    customLaunch      := ""
    customPostTooltip := ""

    customPause  := ""
    customResume := ""

    customExit     := ""
    customRestore  := ""
    customMinimize := ""

    __New(exeConfig) {
        ; set basic attributes
        this.name := (exeConfig.Has("name")) ? exeConfig["name"] : this.name
        this.dir  := (exeConfig.Has("dir"))  ? exeConfig["dir"]  : this.dir
        this.exe  := (exeConfig.Has("exe"))  ? exeConfig["exe"]  : this.exe
        this.wndw := (exeConfig.Has("wndw")) ? exeConfig["wndw"] : this.wndw
        
        this.background := (exeConfig.Has("background")) ? exeConfig["background"] : this.background

        this.time := A_TickCount

        ; set custom functions
        this.customLaunch      := (exeConfig.Has("launch"))       ? exeConfig["launch"]       : this.customLaunch
        this.customPostTooltip := (exeConfig.Has("postTooltip"))  ? exeConfig["postTooltip"]  : this.customPostTooltip
  
        this.customPause       := (exeConfig.Has("pause"))        ? exeConfig["pause"]        : this.customPause
        this.customResume      := (exeConfig.Has("resume"))       ? exeConfig["resume"]       : this.customResume
  
        this.customExit        := (exeConfig.Has("exit"))         ? exeConfig["exit"]         : this.customExit
        this.customRestore     := (exeConfig.Has("restore"))      ? exeConfig["restore"]      : this.customRestore
        this.customMinimize    := (exeConfig.Has("minimize"))     ? exeConfig["minimize"]     : this.customMinimize

        this.hotkeys := (exeConfig.Has("hotkeys")) ? exeConfig["hotkeys"] : this.hotkeys

        ; set pause/tooltip/hotkey attributes
        this.enablePause := (exeConfig.Has("enablePause")) ? exeConfig["enablePause"] : this.enablePause
        this.enableTooltip := (exeConfig.Has("enableTooltip")) ? exeConfig["enableTooltip"] : this.enableTooltip

        ; set pause & tooltip contents if appropriate
        if (this.enablePause) {
            this.pauseOptions := (exeConfig.Has("pauseOptions")) ? exeConfig["pauseOptions"] : this.pauseOptions
        }

        if (this.enableTooltip) {
            this.tooltipInner := (exeConfig.Has("tooltip")) ? toArray(exeConfig["tooltip"]) : this.tooltipInner
        }
    }

    launch(args) {
        ; TODO
        ; take args from externalMessage
        ; set currEXE -> then tooltip -> then postTooltip
        if (this.customLaunch != "") {
            runFunction(this.customLaunch, args)
        }
        else if (this.exe != "") {
            Run validateDir(this.dir) . this.exe . ((args != "" || (args && args.Length > 0)) ? joinArray(args) : ""), validateDir(this.dir), ((this.background) ? "Hide" : "Max")
        }
        else {
            ErrorMsg(this.name . "does not have an exe defined, it cannot be launched with default settings")
            return
        }

        if (this.enableTooltip) {
            Sleep(2000)

            this.tooltip()
            this.postTooltip()
        }
    }

    tooltip() {
        ; TODO
    }

    postTooltip() {
        if (this.customPostTooltip != "") {
            runFunction(this.customPostTooltip)
        }
        
        this.restore()
    }
    
    pause() {
        ; TODO
    }

    resume() {
        ; TODO
    }

    restore() {
        window := (this.wndw != "") ? this.wndw : "ahk_exe " . this.exe
        if (!WinHidden(window)) {
            return
        }

        WinWait window

        if (this.customRestore != "") {
            runFunction(this.customRestore)
            return
        }

        ; TODO - think about removing borders & making fullscreen
        ; for now just gonna restore & activate
        if (!WinActive(window) || WinGetMinMax(window) = -1) {
            WinActivate(window)
            Sleep(100)
            WinMaximize(window)

            this.time := A_TickCount
        }
    }

    minimize() {
        if (this.customMinimize != "") {
            runFunction(this.customMinimize)
            return
        }

        window := (this.wndw != "") ? this.wndw : "ahk_exe " . this.exe

        WinMinimize(window)
    }

    exit() {
        ; TODO - think about if this.wndw -> don't wait for exe to close

        if (this.customExit != "") {
            runFunction(this.customExit)
            return
        }

        window := (this.wndw != "") ? this.wndw : "ahk_exe " . this.exe
        count := 0
        maxCount := 32

        WinClose(window)

        exeExists := (this.exe != "") ? ProcessExist(this.exe) : WinHidden(window)
        while (exeExists && count < maxCount) {
            count += 1
            exeExists := (this.exe != "") ? ProcessExist(this.exe) : WinHidden(window)

            Sleep(250)
        }

        if (exeExists) {
            ProcessWinClose(window)
        }
    }

    exists() {
        ; TODO - think about maybe only checking wndw if this.wndw exists

        ; TODO - think about this
        ; exeStatus := checkEXE(this.exe, (IsObject(this.exe)) ? true : false)
        ; wndwStatus := checkEXE(this.wndw, (IsObject(this.wndw)) ? true : false)

        ; if (Type(exeStatus) = "String") {
        ;     this.exe := exeStatus
        ; }
        
        ; if (Type(wndwStatus) = "String") {
        ;     this.wndw := wndwStatus
        ; }

        ; return (exeStatus || wndwStatus)

        return (checkEXE(this.exe) || checkWNDW(this.wndw))
    }

    getPID() {
        PID := ProcessExist(this.exe)

        if (PID > 0 && this.exe != "") {
            return PID
        }

        if (WinHidden(this.wndw) && this.wndw != "") {
            resetDHW := A_DetectHiddenWindows

            DetectHiddenWindows(false)
            PID := WinGetPID(this.wndw)
            DetectHiddenWindows(resetDHW)

            return PID
        }

        ErrorMsg(this.name . ".getPID() failed")
        return -1
    }

}

; creates a program that gets added to mainRunning
;  params - params to pass to Program(), first element of params must be program name
;  programs - list of programs parsed at start of main
;  launchProgram - if program.launch() should be called
;  setCurrent - if currProgram should be updated
;  customTime - manual time value to set (useful for backup)
;
; returns null
createProgram(params, running, programs, launchProgram := true, setCurrent := true, customTime := "") {   
    newProgram := IsObject(params) ? params : toArray(StrSplit(params, A_Space))

    newName := newProgram.RemoveAt(1)

    for key, value in programs {
        if (key = newName) {
            running[newName] := Program(value)

            if (setCurrent) {
                setStatusParam("currProgram", newName)
            }

            if (launchProgram) {
                running[newName].launch(newProgram)
            }

            if (customTime != "") {
                running[newName].time := customTime
            }

            if (running[newName].hotkeys.Count > 0) {
                setStatusParam("currHotkeys", addHotkeys(getStatusParam("currHotkeys"), running[newName].hotkeys))
            }
        
            return
        }
    }

    ErrorMsg("Program " . newName . " was not found")
}

; cleans up program setting if it is a file, converting it into a newline deliminated list
;   setting - setting
;   dir - directory of settings lists
;
; returns setting or list of values parsed from setting's file
cleanSetting(setting, dir) {
    if (Type(setting) != "String" || setting = "" || dir = "") {
        return setting
    }

    settingFile := validateDir(dir) . setting

    if (FileExist(settingFile)) {
        return readConfig(settingFile, "").items
    }

    return setting
}


; takes a variable amount of exe maps (key=exe) and returns the process exe if its running
;  exe - either an exe or a map with each key being an exe
;  retName - return name rather than boolean
;
; return either "" if the process is not running, or the name of the process
checkEXE(exe, retName := false) {
    if (exe = "") {
        return false
    }

    if (IsObject(exe)) {
        for process in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process") {
            if (exe.Has(process.Name)) {
                if (retName) {
                    return process.Name
                }
                else {
                    return true
                }
            }
        }
    }
    else {
        return ProcessExist(exe) ? true : false
    }

    return false
}

; takes a variable of window maps (key=window) and returns true if any of the functions return
;  wndw - either an wndw name or a map with each key being an wndw
;  retName - return name rather than boolean
;
; return either "" if the process is not running, or the name of the process
checkWNDW(wndw, retName := false) {
    if (wndw = "") {
        return false
    }

    if (IsObject(wndw)) {
        for key, empty in wndw {
            if (WinShown(key)) {
                if (retName) {
                    return key
                }
                else {
                    return true
                }
            }
        }
	}
    else {
        return WinShown(wndw) ? true : false
    }

	return false
}

; get the most recently opened program if it exists, otherwise return blank
;  running - currently running programs in mainRunning
;  checkBackground - boolean if to check background apps as well
;
; returns either name of recently opened program or empty string
getMostRecentProgram(running, checkBackground := false) {
    prevTime := 0
    prevProgram := ""
    for key, value in running {
        if (!checkBackground && value.background) {
            continue
        }

        if (value.time > prevTime) {
            prevTime := value.time
            prevProgram := key
        }
    }

    return prevProgram
}

; checks & updates the running list of programs
; launches missing background programs
;  running - currently running program map
;  programs - list of program configs
;
; returns null
checkAllPrograms(running, programs) {
    for key, value in programs {
        if (!running.Has(key) && ((value.Has("exe") && checkEXE(value["exe"])) || (value.Has("wndw") && checkWNDW(value["wndw"])))) {
            createProgram(key, running, programs, false, false)
        }
    }

    numForeground := 0
    for key, value in running {
        if (!value.exists()) {
            running.Delete(key)
        }
        else if (!value.background) {
            numForeground += 1
        }
    }

    if (globalConfig["Programs"].Has("Default") && globalConfig["Programs"]["Default"] != "" && numForeground = 0) {
        if (!programs.Has(globalConfig["Programs"]["Default"])) {
            ErrorMsg("Default Program" . globalConfig["Programs"]["Default"] . " has no config", true)
        }

        createProgram(globalConfig["Programs"]["Default"], running, programs, true, false)
    }

    if (globalConfig["Programs"].Has("Required") && globalConfig["Programs"]["Required"] != "") {
        checkRequiredPrograms(running, programs)
    }
}

; checks & updates the running list of programs specifically for required programs
;  running - currently running program map
;  programs - list of program configs
;
; returns null
checkRequiredPrograms(running, programs) {
    for item in toArray(globalConfig["Programs"]["Required"]) {
        if (!programs.Has(item)) {
            ErrorMsg("Required Program " . item . "has no config", true)
        }

        if (!running.Has(item)) {
            if ((programs[item].Has("exe") && checkEXE(programs[item]["exe"])) || (programs[item].Has("wndw") && checkWNDW(programs[item]["wndw"]))) {
                createProgram(item, running, programs, false, false)
            }
            else {
                createProgram(item, running, programs, true, false)
            }
        }
    }
}