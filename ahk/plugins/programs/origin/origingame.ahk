; launch game from exectuable path that uses Origin
;  game - full path of game executable
;  args - args to use when running game
;
; returns null
originGameLaunch(game, args*) {
    global globalConfig
    global globalStatus
    global globalRunning

    this := globalRunning["origingame"]

    pathArr := StrSplit(game, "\")
    
    exe := pathArr.RemoveAt(pathArr.Length)
    path := joinArray(pathArr, "\")

    if ((Type(args) = "String" && args != "") || (Type(args) = "Array" && args.Length > 0)) {
        Run game . " " . joinArray(args), path
    }
    else {
        Run game, path
    }

    count := 0
    maxCount := 40

    setLoadScreen("Waiting for Origin...")
    
    resetTMM := A_TitleMatchMode
    SetTitleMatchMode 2

    restoreAllowExit := this.allowExit
    this.allowExit := true

    globalStatus["loadscreen"]["overrideWNDW"] := "Origin"

    ; wait for origin to show
    while (!this.exists(true) && count < maxCount) {
        if (WinShown("Origin")) {            
            count := 0
        }

        if (this.shouldExit) {
            globalStatus["loadscreen"]["overrideWNDW"] := ""
            
            originGamePostExit()
            SetTitleMatchMode(resetTMM)

            return -1
        }

        count += 1
        Sleep(500)
    }

    this.allowExit := restoreAllowExit
    globalStatus["loadscreen"]["overrideWNDW"] := ""
}

; custom post launch action for origin game
originGamePostLaunch() {
    global globalRunning

    this := globalRunning["origingame"]

    ; custom action based on which executable is open
    switch(this.currEXE) {
        case "Madden19.exe": ; Madden 19
            SetTimer(MouseMove.Bind(percentWidth(1, false), percentHeight(1, false)), -10000)
            SetTimer(SendSafe.Bind("{Enter}"), 500)
    }
}

; close origin after game exits
originGamePostExit() {
    count := 0
    maxCount := 100
    ; wait for origin to show
    while (!WinShown("Origin") && count < maxCount) {
        count += 1
        Sleep(100)
    }

    count := 0
    maxCount := 20
    ; try to close origin while open
    while (WinShown("Origin") && count < maxCount) {
        WinActivate("Origin")
        Sleep(100)

        Send("{Alt down}")
        Sleep(50)
        Send("o")
        Sleep(50)
        Send("{Alt up}")
        Sleep(50)
        Send("{Up}")
        Sleep(50)
        Send("{Enter}")

        count += 1
        Sleep(500)
    }

    ; take drastic measures if origin remains
    if (ProcessExist("Origin.exe") && count >= maxCount) {
        ProcessClose("Origin.exe")
    }
}