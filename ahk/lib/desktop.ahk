global GUIKBMMODETITLE := "AHKKBMMODE"
global GUIDESKTOPTITLE := "AHKDESKTOPMODE"

; enables kbbmode & displays info splash
;  showDialog - whether or not to show the info splash
;
; returns null
enableKBMMode(showDialog := true) {
    globalStatus["kbmmode"] := true
    MouseMove(percentWidth(0.5, false), percentHeight(0.5, false))

    ; create basic gui dialog showing kb & mouse mode on
    ; TODO - add tooltip for keyboard button
    if (showDialog) {
        guiObj := Gui(GUI_OPTIONS . " +AlwaysOnTop +Disabled +ToolWindow +E0x20", GUIKBMMODETITLE)
        guiObj.BackColor := COLOR1

        guiWidth := percentWidth(0.16)
        guiHeight := percentHeight(0.05)
        guiSetFont(guiObj, "bold s24")

        guiObj.Add("Text", "0x200 Center x0 y0 w" . guiWidth . " h" . guiHeight, "KB && Mouse Mode")
        guiObj.Show("NoActivate w" . guiWidth . " h" . guiHeight 
            . " x" . (percentWidth(1) - (guiWidth + percentWidth(0.01, false))) . " y" . (percentHeight(1) - (guiHeight + percentWidth(0.01, false))))
        
        WinSetTransparent(230, GUIKBMMODETITLE)
    }
}

; disables kbbmode & destroys info splash
;
; returns null
disableKBMMode() {
    global globalGuis

    ; close the keyboard if open
    ; if (globalGuis.Has(INTERFACES["keyboard"]["wndw"])) {
    ;     globalGuis[INTERFACES["keyboard"]["wndw"]].Destroy()
    ; }

    if (keyboardExists()) {
        closeKeyboard()
    }
    
    globalStatus["kbmmode"] := false
    MouseMove(percentWidth(1), percentHeight(1))

    if (WinShown(GUIKBMMODETITLE)) {
        WinClose(GUIKBMMODETITLE)
    }
}

; enables desktop & displays info splash
;  showDialog - whether or not to show the info splash
;
; returns null
enableDesktopMode(showDialog := false) {
    global globalConfig
    global globalStatus
    global globalRunning

    if (globalStatus["kbmmode"]) {
        disableKBMMode()
    }

    for key, value in globalRunning {
        if (value.background || value.minimized) {
            continue
        }

        value.minimize()
        Sleep(100)
    }

    globalStatus["suspendScript"] := true
    globalStatus["desktopmode"]   := true
    MouseMove(percentWidth(0.5, false), percentHeight(0.5, false))

    ; create basic gui dialog showing kb & mouse mode on
    ; TODO - add tooltip for keyboard button
    if (showDialog) {
        guiObj := Gui(GUI_OPTIONS . " +AlwaysOnTop +Disabled +ToolWindow +E0x20", GUIDESKTOPTITLE)
        guiObj.BackColor := COLOR1

        guiWidth := percentWidth(0.31)
        guiHeight := percentHeight(0.05)
        guiSetFont(guiObj, "bold s24")

        guiObj.Add("Text", "0x200 Center x0 y0 w" . guiWidth . " h" . guiHeight, "Press HOME to Disable Desktop Mode")
        guiObj.Show("NoActivate w" . guiWidth . " h" . guiHeight 
            . " x" . (percentWidth(1) - (guiWidth + percentWidth(0.01, false))) . " y" . (percentHeight(1) - (guiHeight + percentWidth(0.01, false))))
        
        WinSetTransparent(230, GUIDESKTOPTITLE)
    }

    globalStatus["loadscreen"]["enable"] := false
}

; disables desktop & destroys info splash
;
; returns null
disableDesktopMode() {
    global globalConfig
    global globalGuis

    ; close the keyboard if open
    ; if (globalGuis.Has(INTERFACES["keyboard"]["wndw"])) {
    ;     globalGuis[INTERFACES["keyboard"]["wndw"]].Destroy()
    ; }

    if (keyboardExists()) {
        closeKeyboard()
    }
    
    globalStatus["suspendScript"] := false
    globalStatus["desktopmode"]   := false
    MouseMove(percentWidth(1), percentHeight(1))

    if (WinShown(GUIDESKTOPTITLE)) {
        WinClose(GUIDESKTOPTITLE)
    }
}

; checks whether the keyboard is open
;
; returns true if the keyboard is visible
keyboardExists() {
    return ProcessExist("osk.exe")

    ; resetDHW := A_DetectHiddenWindows
    ; DetectHiddenWindows(true)

    ; hwnd := DllCall("FindWindowEx", "UInt", 0, "UInt", 0, "Str", "IPTip_Main_Window", "UInt", 0)

    ; DetectHiddenWindows(resetDHW)
    ; return (hwnd != 0)
}

; turns off gui keyboard
;
; returns null
openKeyboard() {
    Run "osk.exe"
    
    ; resetDHW := A_DetectHiddenWindows
    ; resetSTM := A_TitleMatchMode

    ; DetectHiddenWindows(true)
    ; SetTitleMatchMode(3)

    ; try resetA := WinGetTitle("A")

    ; if (resetA = "Search") {
    ;     Run "C:\Program Files\Common Files\microsoft shared\ink\TabTip.exe"
    ; }
    ; else {
    ;     try {
    ;         WinShow("ahk_class Shell_TrayWnd")
    ;         WinActivate("ahk_class Shell_TrayWnd")
    
    ;         Sleep(25)
    ;         Run "C:\Program Files\Common Files\microsoft shared\ink\TabTip.exe"
    ;         Sleep(70)
    ;     }
    ; }

    ; DetectHiddenWindows(resetDHW)
    ; SetTitleMatchMode(resetSTM)

    ; if (resetA && WinShown(resetA)) {
    ;     WinActivate(resetA)
    ; }

    ; Hotkey("Enter", EnterOverrideHotkey)
} 

; turns off gui keyboard
;
; returns null
closeKeyboard() {
    ProcessClose("osk.exe")

    ; resetDHW := A_DetectHiddenWindows
    ; DetectHiddenWindows(true)

    ; hwnd := DllCall("FindWindowEx", "UInt", 0, "UInt", 0, "Str", "IPTip_Main_Window", "UInt", 0)

    ; if (hwnd) {
    ;     WinClose("ahk_id " hwnd)
    ; }
    
    ; DetectHiddenWindows(resetDHW)

    ; try Hotkey("Enter", "Off")
}

; turns on & off gui keyboard
;
; returns null
toggleKeyboard() {
    if (keyboardExists()) {
        closeKeyboard()
    }
    else {
        openKeyboard()
    }
}

; check if keyboard is open when pressing enter to properly close it
EnterOverrideHotkey(*) { 
    Send("{Enter}")

    if (keyboardExists()) {
        closeKeyboard()
    }
}