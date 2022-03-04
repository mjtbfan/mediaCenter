; creates a wrapper object over a gui that gets added to mainGuis
; this wrapper supports interactions with the controller using a grid that keeps track of interactable controls
; this obj is used like a gui, but 'Add' supports addition params for interaction settings
class Interface {
    ; attributes
    guiObj := ""
    guiName := ""
    selectColor := ""
    deselectColor := ""
    
    ; 2d grid of interactable controls
    control2D := [[]]
    ; current pos of user selection
    currentX := 1
    currentY := 1

    guiX := 0
    guiY := 0
    guiW := 0
    guiH := 0
    
    scrollVOffset := 0
    scrollHOffset := 0

    ; same as Program
    hotkeys := Map()
    time := 0

    __New(title, options := "", eventObj := "", enableAnalog := false, additionalHotkeys := "") {
        ; create the gui object
        if (eventObj != "") {
            this.guiObj := Gui(options, title, eventObj)
        }
        else {
            this.guiObj := Gui(options, title)
        }

        ; add hotkeys for moving selection around gui
        ; yes these probably shouldn't be hardcoded
        if (enableAnalog) {
            this.hotkeys["[REPEAT]LSY>0.2"] := "gui.up"
            this.hotkeys["[REPEAT]LSY<-0.2"]  := "gui.down"
            this.hotkeys["[REPEAT]LSX<-0.2"] := "gui.left"
            this.hotkeys["[REPEAT]LSX>0.2"]  := "gui.right"

            this.hotkeys["[REPEAT]LSY>0.2&LSX<-0.2"] := "gui.upleft"
            this.hotkeys["[REPEAT]LSY>0.2&LSX>0.2"] := "gui.upright"
            this.hotkeys["[REPEAT]LSY<-0.2&LSX<-0.2"] := "gui.downleft"
            this.hotkeys["[REPEAT]LSY<-0.2&LSX>0.2"] := "gui.downright"
        }

        this.hotkeys["[REPEAT]DU"] := "gui.up"
        this.hotkeys["[REPEAT]DD"] := "gui.down"
        this.hotkeys["[REPEAT]DL"] := "gui.left"
        this.hotkeys["[REPEAT]DR"] := "gui.right"

        this.hotkeys["[REPEAT]DU&DL"] := "gui.upleft"
        this.hotkeys["[REPEAT]DU&DR"] := "gui.upright"
        this.hotkeys["[REPEAT]DD&DL"] := "gui.downleft"
        this.hotkeys["[REPEAT]DD&DR"] := "gui.downright"

        this.hotkeys["A"] := "gui.select"
        ; this.hotkeys["B"] := "gui.back"

        if (additionalHotkeys != "") {
            for key, value in additionalHotkeys {
                this.hotkeys[key] := value
            }
        }

        this.time := A_TickCount
        this.guiName := title
    }

    ; exactly like gui.show except renders the selected item w/ the proper background
    ;  options - see gui.show
    ;
    ; returns null
    Show(options := "") {
        optionsArr := StrSplit(options, A_Space)
        for item in optionsArr {
            if (StrLower(SubStr(item, 1, 1)) = "x") {
                this.guiX := Integer(SubStr(item, 2))
            }
            else if (StrLower(SubStr(item, 1, 1)) = "y") {
                this.guiY := Integer(SubStr(item, 2))
            }
            else if (StrLower(SubStr(item, 1, 1)) = "w") {
                this.guiW := Integer(SubStr(item, 2))
            }
            else if (StrLower(SubStr(item, 1, 1)) = "h") {
                this.guiH := Integer(SubStr(item, 2))
            }
        }

        loop this.control2D.Length {
            x_index := A_Index

            loop this.control2D[x_index].Length {
                y_index := A_Index

                currControl := this.control2D[x_index][y_index].control

                if (currControl != "") {
                    if (this.currentX = x_index && this.currentY = y_Index) {
                        this.guiObj[currControl].Opt("Background" . this.selectColor)
                    }
                    else {
                        this.guiObj[currControl].Opt("Background" . this.deselectColor)
                    }
                }
            }
        }

        this.guiObj.Show(options)
    }

    ; exactly like gui.add, but supports additional params
    ;  type - see gui.add
    ;  options - see gui.add w/ additional support for:
    ;    xpos - xposition of control in gui (for user selection)
    ;         - if -1 -> gui considered in every x @ current y at time of add
    ;    ypos - yposition of control in gui (for user selection)
    ;         - if -1 -> gui considered in every y @ current x at time of add
    ;    f(x) - function string (x) to be ran on select of control using runFunction
    ;  text - see gui.add
    ;
    ; returns null
    Add(type, options := "", text := "") {
        optionsArr := StrSplit(options, A_Space)
        removeArr := []

        addControl := false
        controlName := ""
        controlFunc := ""
        xpos := -1
        ypos := -1

        currItem := ""
        inFunction := false
        for item in optionsArr {
            ; loop to support functions w/ params
            if (inFunction) {
                currItem .= item . A_Space

                if (SubStr(item, -1, 1) = ")") {
                    currItem := RTrim(currItem, A_Space)
                    controlFunc := SubStr(currItem, 3, StrLen(currItem) - 3)

                    removeArr.Push(currItem)
                    inFunction := false
                    addControl := true
                }

                continue
            }

            ; get name of control for key
            if (SubStr(item, 1, 1) = "v") {
                controlName := SubStr(item, 2)
            }

            ; check for a function string
            else if (SubStr(item, 1, 2) = "f(") {
                if (SubStr(item, -1, 1) = ")") {
                    controlFunc := SubStr(item, 3, StrLen(item) - 3)

                    removeArr.Push(item)
                    addControl := true
                }
                else {
                    currItem := item . A_Space
                    inFunction := true
                }
            }

            ; check for a xpos string
            else if (SubStr(item, 1, 4) = "xpos") {
                xpos := Integer(SubStr(item, 5))
                
                removeArr.Push(item)
                addControl := true
            }

            ; check for a xpos string
            else if (SubStr(item, 1, 4) = "ypos") {
                ypos := Integer(SubStr(item, 5))

                removeArr.Push(item)
                addControl := true
            }
        }

        ; if control is interactable
        if (addControl) {
            ; add empty slots if xpos > max xpos
            if (xpos > 0) {
                while (this.control2D.Length < xpos) {
                    this.control2D.Push([])
                }
            }
            
            ; add empty slots if ypos > max ypos
            if (ypos > 0) {
                if (xpos = -1) {
                    loop this.control2D.Length {
                        x_index := A_Index
    
                        while(this.control2D[x_index].Length < ypos) {
                            this.control2D[x_index].Push({control: "", function: ""})
                        }
                    }
                }
                else {
                    while(this.control2D[xpos].Length < ypos) {
                        this.control2D[xpos].Push({control: "", function: ""})
                    }
                }
            }
            
            ; put the interacable data in every slot
            if (xpos = -1 && ypos = -1) {
                loop this.control2D.Length {
                    x_index := A_Index

                    loop this.control2D[x_index].Length {
                        y_index := A_Index

                        if (this.control2D[x_index][y_index].control = "") {
                            this.control2D[x_index][y_index] := {control: controlName, function: controlFunc}
                        }
                    }
                }
            }

            ; put the interacable data in every slot at same ypos
            else if (xpos = -1) {
                loop this.control2D.Length {
                    if (this.control2D[A_Index][ypos].control = "") {
                        this.control2D[A_Index][ypos] := {control: controlName, function: controlFunc}
                    }
                }
            }

            ; put the interacable data in every slot at same xpos
            else if (ypos = -1) {
                loop this.control2D[xpos].Length {
                    if (this.control2D[xpos][A_Index].control = "") {
                        this.control2D[xpos][A_Index] := {control: controlName, function: controlFunc}
                    }
                }
            }

            ; put the interacable data in the requested slot
            else {
                this.control2D[xpos][ypos] := {control: controlName, function: controlFunc}
            }
        }

        cleanOptions := options
        for item in removeArr {
            cleanOptions := StrReplace(cleanOptions, item,,,, 1)
        }

        if (text != "") {
            this.guiObj.Add(type, cleanOptions, text)
        }
        else {
            this.guiObj.Add(type, cleanOptions)
        }
    }

    ; exactly like gui.destroy
    ; 
    ; returns null
    Destroy() {
        try this.guiObj.Destroy()
    }

    ; runs the function defined in the selected control's interactable data
    ;
    ; returns null
    select() {    
        if (this.control2D[this.currentX][this.currentY].function != "") {
            runFunction(this.control2D[this.currentX][this.currentY].function)
        }
    }

    ; --- MOVEMENT FUNCTIONS ---
    ; moves the user selection in the requested direction of the gui 
    ; basically just colors the background of a control to be considered selected
    ; skips controls that don't have a key & wraps around both axis

    ; check if the selected control is outside of the wndw & vertically scroll if it is
    checkScrollVertical(selectedControl) {
        y := 0
        h := 0
        
        ControlGetPos(, &y,, &h, selectedControl)

        if (this.currentY = 1) {
            DllCall("ScrollWindow", "Ptr", this.guiObj.Hwnd, "Int", 0, "Int", (-1 * this.scrollVOffset), "Ptr", 0, "Ptr", 0)
            this.scrollVOffset := 0
        }
        else if (y < 0) {
            diff := -1 * (y - percentHeight(0.005))
            DllCall("ScrollWindow", "Ptr", this.guiObj.Hwnd, "Int", 0, "Int", diff, "Ptr", 0, "Ptr", 0)
            this.scrollVOffset += diff
        }
        else if ((y + h) > (this.guiY + this.guiH)) {
            diff := -1 * (Abs((y + h) - (this.guiY + this.guiH)) + percentHeight(0.005))
            DllCall("ScrollWindow", "Ptr", this.guiObj.Hwnd, "Int", 0, "Int", diff, "Ptr", 0, "Ptr", 0)
            this.scrollVOffset += diff
        }
    }

    ; check if the selected control is outside of the wndw & horizontally scroll if it is
    checkScrollHorizontal(selectedControl) {
        x := 0
        w := 0
        
        ControlGetPos(&x,, &w,, selectedControl)

        if (this.currentX = 1) {
            DllCall("ScrollWindow", "Ptr", this.guiObj.Hwnd, "Int", (-1 * this.scrollHOffset), "Int", 0, "Ptr", 0, "Ptr", 0)
            this.scrollHOffset := 0
        }
        else if (x < 0) {
            diff := -1 * (x - percentWidth(0.005))
            DllCall("ScrollWindow", "Ptr", this.guiObj.Hwnd, "Int", diff, "Int", 0, "Ptr", 0, "Ptr", 0)
            this.scrollHOffset += diff
        }
        else if ((x + w) > (this.guiX + this.guiW)) {
            diff := -1 * (Abs((x + w) - (this.guiX + this.guiW)) + percentWidth(0.005))
            DllCall("ScrollWindow", "Ptr", this.guiObj.Hwnd, "Int", diff, "Int", 0, "Ptr", 0, "Ptr", 0)
            this.scrollHOffset += diff
        }
    }

    up() {    
        nextY := 0
        attemptedY := this.currentY - 1
        while (nextY = 0) {
            if (attemptedY < 1) {
                attemptedY := this.control2D[this.currentX].Length
                continue
            }
    
            if (this.control2D[this.currentX][attemptedY].control != "") {
                nextY := attemptedY
            }
    
            if (attemptedY = this.currentY) {
                return
            }
    
            attemptedY -= 1
        }
    
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Opt("Background" . this.unselectColor)
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Redraw()
    
        this.currentY := nextY
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Opt("Background" . this.selectColor)
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Redraw()
        
        this.checkScrollVertical(this.guiObj[this.control2D[this.currentX][this.currentY].control])
    }
    
    down() {    
        nextY := 0
        attemptedY := this.currentY + 1
        currentX := this.currentX
        while (nextY = 0) {
            if (attemptedY > this.control2D[this.currentX].Length) {
                attemptedY := 1
                continue
            }

            if (this.control2D[this.currentX][attemptedY].control != "") {
                nextY := attemptedY
            }
    
            if (attemptedY = this.currentY) {
                return
            }
    
            attemptedY += 1
        }
    
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Opt("Background" . this.unselectColor)
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Redraw()
    
        this.currentY := nextY
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Opt("Background" . this.selectColor)
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Redraw()
        
        this.checkScrollVertical(this.guiObj[this.control2D[this.currentX][this.currentY].control])
    }
    
    left() {    
        nextX := 0
        nextY := this.currentY
        attemptedX := this.currentX - 1
        while (nextX = 0) {
            if (attemptedX < 1) {
                attemptedX := this.control2D.Length
                continue
            }

            if (this.control2D[attemptedX].Length < this.currentY) {
                nextY := this.control2D[attemptedX].Length
            }
    
            if (this.control2D[attemptedX][nextY].control != "") {
                nextX := attemptedX
            }
    
            if (attemptedX = this.currentX) {
                return
            }
    
            attemptedX -= 1
        }
    
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Opt("Background" . this.unselectColor)
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Redraw()
    
        this.currentX := nextX
        this.currentY := nextY
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Opt("Background" . this.selectColor)
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Redraw()

        this.checkScrollHorizontal(this.guiObj[this.control2D[this.currentX][this.currentY].control])
    }
    
    right() {    
        nextX := 0
        nextY := this.currentY
        attemptedX := this.currentX + 1
        while (nextX = 0) {
            if (attemptedX > this.control2D.Length) {
                attemptedX := 1
                continue
            }

            if (this.control2D[attemptedX].Length < this.currentY) {
                nextY := this.control2D[attemptedX].Length
            }
    
            if (this.control2D[attemptedX][nextY].control != "") {
                nextX := attemptedX
            }
    
            if (attemptedX = this.currentX) {
                return
            }
    
            attemptedX += 1
        }
    
    
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Opt("Background" . this.unselectColor)
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Redraw()
    
        this.currentX := nextX
        this.currentY := nextY
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Opt("Background" . this.selectColor)
        this.guiObj[this.control2D[this.currentX][this.currentY].control].Redraw()

        this.checkScrollHorizontal(this.guiObj[this.control2D[this.currentX][this.currentY].control])
    }

    ; okay look im sorry but it works pretty well
    upleft() {
        this.up()
        this.left()
    }
    upright() {
        this.up()
        this.right()
    }
    downleft() {
        this.down()
        this.left()
    }
    downright() {
        this.down()
        this.right()
    }
}

; creates a gui that gets added to mainGuis
;  guis - current list of open guis
;  title - passed to interface()
;  options - passed to interface() 
;  additionalHotkeys - passed to interface()
;  enableAnalog - passed to interface()
;  setCurrent - sets the new gui as currGui
;  customTime - override the launch time
;
; returns null
createInterface(guis, title, options := "", eventObj := "",  additionalHotkeys := "", enableAnalog := false, setCurrent := true, customTime := "") {
    guis[title] := Interface(title, options, eventObj, enableAnalog, additionalHotkeys)

    if (setCurrent) {
        setStatusParam("currGui", title)
    }

    if (customTime != "") {
        guis[title].time := customTime
    }

    if (guis[title].hotkeys.Count > 0) {
        setStatusParam("currHotkeys", addHotkeys(getStatusParam("currHotkeys"), guis[title].hotkeys))
    }

    return
}

; get the most recently opened gui if it exists, otherwise return blank
;  guis - currently open guis in mainGuis
;
; returns either name of recently opened gui or empty string
getMostRecentGui(guis) {
    prevTime := 0
    prevProgram := ""
    for key, value in guis {
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
checkAllGuis(guis) {
    for key, value in guis {
        if (!WinShown(key)) {
            guis.Delete(key)
        }
    }
}