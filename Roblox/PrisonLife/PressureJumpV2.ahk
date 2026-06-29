#Requires AutoHotkey v2.0

; to use crouch and put head under a part then press keybind to glitch

#SingleInstance Force
SetWorkingDir(A_ScriptDir)
SendMode("Input")
DllCall("Winmm\timeBeginPeriod", "UInt", 1)

; you need to manually set this to a number
CS := 0.135

; ignore, this is the equation to do turn
Spin := Round(180 * 2.5 / CS) ; 180 spin

; EXPERIMENTAL
FREEZE := False ; freeze keybind is middle mouse button

; dont change this!
Spins := 20

; keybind for glitch (default is Q)
Q::{
    Send("c")

    Send("{Space down}")
    if FREEZE
        DllCall("Sleep", "UInt", 20)
    else
        DllCall("Sleep", "UInt", 50)
    Send("{Space up}")

    if (FREEZE)
    {
        DllCall("mouse_event", "UInt", 0x0020, "UInt", 0, "UInt", 0, "UInt", 0, "UPtr", 0)
        DllCall("Sleep", "UInt", 100)
        DllCall("mouse_event", "UInt", 0x0040, "UInt", 0, "UInt", 0, "UInt", 0, "UPtr", 0)
    }

    DllCall("Sleep", "UInt", 14)

    Loop Spins
    {
        DllCall("mouse_event", "UInt", 0x0001, "Int", Spin, "Int", 0, "UInt", 0, "UPtr", 0)

        DllCall("Sleep", "UInt", 8)
    }
}

; exit keybind (default is F3)
F3::{
    DllCall("Winmm\timeEndPeriod", "UInt", 1)
    ExitApp()
}
