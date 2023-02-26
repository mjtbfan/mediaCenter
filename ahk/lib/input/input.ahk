; abstract object that is used as the base for an individual input device
; stores the current state & required functions to check the state of the device
class Input {
    pluginID := ""
    pluginPort := -1
    name := ""

    connected := false
    vibrating := false

    ; connectionType
    ;  -1 -> unknown
    ;   0 -> wired
    ;   1 -> battery
    connectionType := -1

    ; valid range 0 -> 1
    batteryLevel := 0

    ; map object to use for whatever ptrs are created in the initialization
    ; of the device type / individual device
    initResults := Map()

    ; state of input buttons/axis
    buttons := []
    axis := Map()

    __New(initResults, pluginPort, inputConfigRef) {
        inputConfig := ObjDeepClone(inputConfigRef)
        
        this.pluginID := inputConfig["id"]
        this.pluginPort := pluginPort

        this.name := (inputConfig.Has("name")) ? inputConfig["name"] : this.name

        this.initResults := initResults
        
        this.initDevice()
    }

    ; this should only run once to intialize the driver (beginning of script)
    static initialize() {

    }

    ; this should only run once to de-attach the driver (end of script)
    static destroy() {

    }

    ; this should only run once to intialize the controller port instance (after initialize)
    initDevice() { 
        
    } 

    ; this should only run once to remove the controller port instance (before destroy)
    destroyDevice() {

    }

    ; returns the state of the pressed buttons and each axis's current state
    getStatus() {
        return Map("buttons", [], "axis", Map())
    }

    ; returns & sets the connection type of the device
    checkConnectionType() {
        return this.connectionType
    }

    ; returns & sets the battery level of the device
    checkBatteryLevel() { 
        return this.batteryLevel
    }

    ; start vibrating the device if it supports vibrations
    startVibration() {

    }

    ; stop vibrating the device
    stopVibration() {

    }
}

; checks the button & axis status of an input device using the results from getStatus
;  hotkeys - array of hotkeys to check if results from the status satisfy any hotkey
;  statusResults - the results from 1 input device's getStatus
;
; returns true if any hotkey in hotkeys is satisfied
inputCheckStatus(hotkeys, statusResult) {
    hotkeyArr := toArray(hotkeys)

    retVal := true
    for key in hotkeyArr {
        retVal := retVal && (inArray(key, statusResult["buttons"]) || inputCompareAxis(key, statusResult))
    }

    return retVal
}

; checks if a hotkey is an axis comparison, then checks if the input status satisfies the comparison
;  axisComparison - hotkey that will be compared if its in the appropriate format
;  statusResults - the results from 1 input device's getStatus
;
; returns true if the axis comparison is satisfied
inputCompareAxis(axisComparison, statusResult) {
    getAxisVal(axis) {
        for key, value in statusResult["axis"] {
            if (StrLower(axis) = StrLower(key)) {
                return value
            }
        }

        return 0
    }

    if (InStr(axisComparison, ">")) {
        if (InStr(axisComparison, ">=")) {
            compareArr := StrSplit(axisComparison, ">=")
            return (getAxisVal(compareArr[1]) >= Float(compareArr[2]))
        }
        else {
            compareArr := StrSplit(axisComparison, ">")
            return (getAxisVal(compareArr[1]) > Float(compareArr[2]))
        }
    }
    else if (InStr(axisComparison, "<")) {
        if (InStr(axisComparison, "<=")) {
            compareArr := StrSplit(axisComparison, "<=")
            return (getAxisVal(compareArr[1]) <= Float(compareArr[2]))
        }
        else {
            compareArr := StrSplit(axisComparison, "<")
            return (getAxisVal(compareArr[1]) < Float(compareArr[2]))
        }
    }
    else if (InStr(axisComparison, "=")) {
        compareArr := StrSplit(axisComparison, "=")
        return (getAxisVal(compareArr[1]) = Float(compareArr[2]))
    }

    return false
}