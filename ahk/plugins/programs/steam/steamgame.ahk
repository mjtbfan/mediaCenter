; run an steam game from steam URI
;  URI - link to launch game
;  args - args to use when running game
;
; returns -1 if launch fails
steamGameLaunch(URI, args*) {
    global globalRunning

    this := globalRunning["steamgame"]

    steamResult := steamGameLaunchHandler(URI)
    if (!steamResult) {
        return -1
    }

    ; custom actions based on game
    switch (URI) {
        case "steam://rungameid/200260": ; Batman Arkham Asylum
            this.launcher := Map("exe", "BmLauncher.exe", "mouseClick", [0.5, 0.666])
        case "steam://rungameid/35140": ; Batman Arkham City
            this.launcher := Map("exe", "BmLauncher.exe", "mouseClick", [0.5, 0.666])
        case "steam://rungameid/489830": ; Skyrim SE
            this.launcher := Map("exe", "SkyrimSELauncher.exe", "mouseClick", [0.925, 0.112])
        case "steam://rungameid/22370": ; Fallout 3
            this.launcher := Map("exe", "FalloutLauncherSteam.exe", "mouseClick", [0.922, 0.278])
        case "steam://rungameid/22380": ; Fallout NV
            this.launcher := Map("exe", "FalloutNVLauncher.exe", "mouseClick", [0.922, 0.278])
        case "steam://rungameid/377160": ; Fallout 4
            this.launcher := Map("exe", "Fallout4Launcher.exe", "mouseClick", [0.922, 0.109])
        case "steam://rungameid/236870": ; HITMAN
            this.launcher := Map("exe", "Launcher.exe", "mouseClick", [0.128, 0.621])
        case "steam://rungameid/55230": ; Saints Row 3
            this.launcher := Map("exe", "game_launcher.exe", "mouseClick", [0.25, 0.441])
        case "steam://rungameid/20920": ; Witcher 2
            this.launcher := Map("exe", "Launcher.exe", "mouseClick", [0.585, 0.875])
        case "steam://rungameid/22330": ; Oblivion
            this.launcher := Map("exe", "OblivionLauncher.exe", "mouseClick", [0.664, 0.25])
        case "steam://rungameid/219150": ; Hotline Miami
            this.launcher := Map("exe", "HotlineMiami.exe", "mouseClick", [0.216, 0.948])
        case "steam://rungameid/322500": ; SUPERHOT
            this.launcher := Map("exe", "SUPERHOT.exe", "mouseClick", [[0.205, 0.5], [0.373, 0.833]])
        case "steam://rungameid/690040": ; SUPERHOT 2
            this.launcher := Map("exe", "SUPERHOTMCD.exe", "mouseClick", [[0.497, 0.5], [0.373, 0.833]])
        case "steam://rungameid/1174180": ; Red Dead Redemption 2
            this.launcher := Map("exe", "Launcher.exe", "mouseClick", [])
        case "steam://rungameid/758330": ; Shenmue 1 & 2
            if (Integer(args[1]) = 1) {
                this.launcher := Map("exe", "SteamLauncher.exe", "mouseClick", [0.25, 0.5])
            }
            else if (Integer(args[1]) = 2) {
                this.launcher := Map("exe", "SteamLauncher.exe", "mouseClick", [0.75, 0.5])
            }
        case "steam://rungameid/107100": ; Bastion
            this.requireFullscreen := false
        case "steam://rungameid/374320": ; Dark Souls III
            this.requireFullscreen := false
        case "steam://rungameid/12140", "steam://rungameid/12150", "steam://rungameid/400", "steam://rungameid/220":
            ; Max Payne / Max Payne 2 / Portal / HL2
            this.mouse := Map("initialPos", [0.5, 0.5])
    }
}

; custom post launch action for steamgame
steamGamePostLaunch() {
    DelayCheckFullscreen(program) {
        if (!program.checkFullscreen()) {
            program.fullscreen()
        }
    }

    global globalRunning

    this := globalRunning["steamgame"]

    ; custom action based on which executable is open
    switch(this.currEXE) {
        case "BioshockHD.exe", "Bioshock2HD.exe": ; Bioshock HD & Bioshock 2 HD
            SetTimer(SendSafe.Bind("{Enter}"), -2000)
        ; case "gta3.exe": ; GTA 3
        ;     SetTimer(SendSafe.Bind("{Enter}"), -2000)
        ;     SetTimer(SendSafe.Bind("{Enter}"), -4000)
        ; case "gta-vc.exe": ; GTA VC
        ;     SetTimer(SendSafe.Bind("{Enter}"), -2000)
        ; case "gta-sa.exe": ; GTA SA
        ;     SetTimer(SendSafe.Bind("^{Enter}"), -2000)
        case "Shenmue.exe", "Shenmue2.exe": ; Shenmue 1 & 2
            SetTimer(SendSafe.Bind("{Enter}"), -500)
        case "Clustertruck.exe": ; Clustertruck
            SetTimer(SendSafe.Bind("{Enter}"), -500)
        case "PROA34-Win64-Shipping.exe": ; Blue Fire                
            SetTimer(DelayCheckFullscreen.Bind(this), -6500)  
        case "DarkSoulsIII.exe": ; Dark Souls III                
            SetTimer(DelayCheckFullscreen.Bind(this), -6500)  
        case "braid.exe": ; Braid
            if (this.checkFullscreen()) {
                Send("!{Enter}")
                Sleep(500)
                this.fullscreen()
            }
        case "UNDERTALE.exe": ; Undertale
            while (!this.checkFullscreen()) {
                Send("{F4}")
                Sleep(500)
                Send("{F4}")
                Sleep(500)
            }          
    }
}

; custom post executable close action for all flavors of windows game
steamGamePostExit() {
    global globalRunning

    this := globalRunning["steamgame"]

    ; custom action based on which executable is open
    switch (this.currEXE) {
        case "Shenmue.exe", "Shenmue2.exe": ; Shenmue 1 & 2
            count := 0
            maxCount := 100

            while (!WinShown("Shenmue Launcher") && count < maxCount) {
                count += 1
                Sleep(100)
            }

            if (WinShown("Shenmue Launcher")) {
                WinClose("Shenmue Launcher")
                Sleep(500)
            }
    }
}