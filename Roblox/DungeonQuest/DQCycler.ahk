#Requires AutoHotkey v2.0

; ╔══════════════════════════════════════════════════════════════╗
; ║  DQ CYCLER  ·  Dungeon Quest (Roblox) spell cycler           ║
; ╚══════════════════════════════════════════════════════════════╝
;
; Runs the same carry spell in both slots and staggers them so one is
; always going out: the opener is timed off the cast animation, then both
; keys are spammed so a dropped input never costs you a cast.
;
;   F6  start / stop          F4   settings
;   F7  next profile          F10  hide panel
;   Shift+Esc  quit
;
; Everything is configurable in the settings window (F4) and saved to
; DQCycler.ini next to this script.

#SingleInstance Force
SetWorkingDir(A_ScriptDir)
SendMode("Input")
ProcessSetPriority("High")
ListLines(False)
KeyHistory(0)
DllCall("Winmm\timeBeginPeriod", "UInt", 1)

; ─────────────────────────── CONSTANTS ────────────────────────

INI_PATH := A_ScriptDir . "\DQCycler.ini"
GAME_WIN := "ahk_exe RobloxPlayerBeta.exe"

MARGIN_FLOOR := 25     ; Roblox ticks at 60Hz, never pad tighter than this
TICK_MS      := 10     ; scheduler resolution
BAR_W        := 148    ; cooldown bar width in px
CHAT_TIMEOUT := 20000  ; force-resume if chat never reports closing
RESUME_MS    := 300    ; settling time after chat closes

PRESETS := [
    { name: "Mage - Pulse Waves",   cast: 1000, cd: 4000 },
    { name: "Warrior - Arrow Rain", cast: 500,  cd: 4000 }
]

CL := { bg:"0E1015", sunk:"1B2029", dim:"4A5162", mid:"6B7280",
        text:"C9CFDA", bright:"E8EAED",
        q:"4C8DFF", e:"FF8A3D", ready:"3DDC84", warn:"FFC542",
        stop:"FF5C5C", chat:"58A6FF" }

; ─────────────────────────── SETTINGS ─────────────────────────

CFG := {
    ping: 70,
    profile: 1,
    slots: [ { key:"q", cast:1000, cd:4000 },
             { key:"e", cast:1000, cd:4000 } ],
    chatGuard: true,
    focusGuard: true,
    clickAfter: false,
    hold: 40,
    lead: 300,
    gap: 70,
    panelX: 20,
    panelY: 20,
    showPanel: true
}

ENG := { on:false, castUntil:0, nextAct:0, slots:[],
         typing:false, typingSince:0, resumeAt:0,
         panelOn:true, lastState:"", set:"" }

LoadIni()
RebuildSlots()
PANEL := CFG.showPanel ? BuildPanel() : ""
ENG.panelOn := CFG.showPanel
OnExit(Cleanup)
OnMessage(0x0201, DragPanel)
SetTimer(Tick, TICK_MS)
SetTimer(RefreshPanel, 80)
RefreshPanel()

F6::Toggle()
F7::NextProfile()
F4::OpenSettings()
F10::TogglePanel()
+Escape::ExitApp()

#HotIf CFG.chatGuard && (!CFG.focusGuard || WinActive(GAME_WIN))
~$/::SetTyping(true)
~$Enter::SetTyping(!ENG.typing)
~$NumpadEnter::SetTyping(!ENG.typing)
~$Escape::SetTyping(false)
#HotIf

; ─────────────────────────── ENGINE ───────────────────────────

Margin() {
    return (CFG.ping > MARGIN_FLOOR) ? CFG.ping : MARGIN_FLOOR
}

SetTyping(state) {
    if (state = ENG.typing)
        return
    ENG.typing := state
    if (state) {
        ENG.typingSince := A_TickCount
        ReleaseKeys()
    } else {
        ENG.resumeAt := A_TickCount + RESUME_MS
    }
}

Tick() {
    static busy := false
    if (busy || !ENG.on)
        return
    if (ENG.typing) {
        if (CHAT_TIMEOUT > 0 && A_TickCount - ENG.typingSince > CHAT_TIMEOUT)
            SetTyping(false)
        return
    }
    if (A_TickCount < ENG.resumeAt)
        return
    if (CFG.focusGuard && !WinActive(GAME_WIN))
        return
    busy := true
    try {
        Step()
    } finally {
        busy := false
    }
}

Step() {
    now := A_TickCount
    if (now < ENG.nextAct)
        return

    ; never touch a key while a cast animation is still playing - that is
    ; what keeps the two slots from stepping on each other
    if (now < ENG.castUntil) {
        ENG.nextAct := ENG.castUntil
        return
    }

    pad := Margin()
    pick := 0
    best := 0
    for i, slot in ENG.slots {
        due := slot.readyAt + pad
        ; no early spam before a slot's first cast - it is genuinely off
        ; cooldown then, so an early tap would fire it and break the spacing
        lead := (slot.casts > 0) ? CFG.lead : 0
        if (now >= due - lead && (pick = 0 || due < best)) {
            pick := i
            best := due
        }
    }
    if (pick = 0) {
        ENG.nextAct := now + TICK_MS
        return
    }

    slot := ENG.slots[pick]
    Cast(slot.key)
    t := A_TickCount
    due := slot.readyAt + pad

    if (t >= due) {
        ; spell was off cooldown, so this press fired it
        slot.readyAt := t + slot.cast + slot.cd
        slot.casts += 1
        ENG.castUntil := t + slot.cast
        ENG.nextAct := t
    } else {
        ; still on cooldown - keep tapping, but land the next tap on ready
        nxt := t + CFG.gap
        ENG.nextAct := (nxt > due) ? due : nxt
    }
}

Cast(key) {
    Send("{" key " down}")
    DllCall("Sleep", "UInt", CFG.hold)
    Send("{" key " up}")
    if (CFG.clickAfter) {
        DllCall("Sleep", "UInt", 15)
        Click()
    }
}

RebuildSlots() {
    ENG.slots := []
    for def in CFG.slots
        ENG.slots.Push({ key:def.key, cast:def.cast, cd:def.cd, readyAt:0, casts:0, tone:"", wide:-1 })
    ResetCycle()
}

ResetCycle() {
    now := A_TickCount
    pad := Margin()
    ENG.castUntil := now
    ENG.nextAct := now

    ; Spread the slots EVENLY across one cycle, so a spell goes out every
    ; cycle/N seconds and a timed buff never has a chance to drop. Firing
    ; them back to back instead would dump both spells inside two seconds
    ; and leave the rest of the cycle dead.
    span := ENG.slots[1].cast + ENG.slots[1].cd + pad
    n := ENG.slots.Length
    for i, slot in ENG.slots {
        slot.readyAt := now + Round((i - 1) * span / n) - pad
        slot.casts := 0
    }
}

ReleaseKeys() {
    for slot in ENG.slots
        Send("{" slot.key " up}")
}

Toggle() {
    ENG.on := !ENG.on
    if (ENG.on)
        ResetCycle()
    else
        ReleaseKeys()
}

NextProfile() {
    nxt := (CFG.profile >= 1 && CFG.profile < PRESETS.Length) ? CFG.profile + 1 : 1
    ApplyPreset(nxt)
    was := ENG.on
    ENG.on := false
    ReleaseKeys()
    RebuildSlots()
    ENG.on := was
    SaveIni()
}

ApplyPreset(i) {
    CFG.profile := i
    for def in CFG.slots {
        def.cast := PRESETS[i].cast
        def.cd := PRESETS[i].cd
    }
}

ProfileName() {
    if (CFG.profile >= 1 && CFG.profile <= PRESETS.Length)
        return PRESETS[CFG.profile].name
    return "Custom setup"
}

; ─────────────────────────── PANEL ────────────────────────────

BuildPanel() {
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000", "DQ Cycler")
    g.BackColor := CL.bg

    g.SetFont("s8 Bold c" . CL.dim, "Segoe UI")
    g.Add("Text", "x16 y12 w110", "DQ CYCLER")
    g.SetFont("s8 Norm c" . CL.dim)
    g.Add("Text", "x126 y12 w108 Right", "F4  settings")

    g.SetFont("s15 Bold c" . CL.stop, "Segoe UI")
    g.Add("Text", "x16 y28 w218 vState", "STOPPED")

    g.SetFont("s8 Norm c" . CL.mid)
    g.Add("Text", "x16 y54 w218 vNote", "press F6 to start")

    g.SetFont("s9 Norm c" . CL.text)
    g.Add("Text", "x16 y74 w218 vProfile", "-")

    Row(g, 1, 100, "Q", CL.q)
    Row(g, 2, 122, "E", CL.e)

    g.SetFont("s8 Norm c" . CL.dim, "Segoe UI")
    g.Add("Text", "x16 y148 w218 vFoot", "-")

    g.Show("x" . CFG.panelX . " y" . CFG.panelY . " w250 h170 NoActivate")
    try WinSetRegion("0-0 w250 h170 R14-14", "ahk_id " . g.Hwnd)
    try WinSetTransparent(247, "ahk_id " . g.Hwnd)
    return g
}

Row(g, n, y, label, tone) {
    g.SetFont("s9 Bold c" . CL.bright, "Consolas")
    g.Add("Text", "x16 y" . y . " w16 vKey" . n, label)
    g.Add("Text", "x38 y" . (y + 3) . " w" . BAR_W . " h9 Background" . CL.sunk . " vTrough" . n, "")
    g.Add("Text", "x38 y" . (y + 3) . " w1 h9 Background" . tone . " vBar" . n, "")
    g.SetFont("s8 Norm c" . CL.mid, "Segoe UI")
    g.Add("Text", "x190 y" . (y + 1) . " w46 Right vTime" . n, "-")
}

RefreshPanel() {
    if (!IsObject(PANEL) || !ENG.panelOn)
        return

    if (!ENG.on) {
        state := "STOPPED", colour := CL.stop, note := "press F6 to start"
    } else if (ENG.typing) {
        state := "TYPING", colour := CL.chat, note := "chat is open - paused"
    } else if (CFG.focusGuard && !WinActive(GAME_WIN)) {
        state := "WAITING", colour := CL.warn, note := "Roblox is not the active window"
    } else if (A_TickCount < ENG.resumeAt) {
        state := "TYPING", colour := CL.chat, note := "resuming..."
    } else {
        state := "RUNNING", colour := CL.ready, note := "casting"
    }

    if (state != ENG.lastState) {
        ENG.lastState := state
        try {
            PANEL["State"].Opt("c" . colour)
            PANEL["State"].Text := state
            PANEL["State"].Redraw()
        } catch {
            PANEL["State"].Text := state
        }
    }
    PANEL["Note"].Text := note
    PANEL["Profile"].Text := ProfileName()
    PANEL["Foot"].Text := "ping " . CFG.ping . "ms      F6 start    F7 profile"

    now := A_TickCount
    pad := Margin()
    for i, slot in ENG.slots {
        if (i > 2)
            break
        left := slot.readyAt + pad - now
        span := slot.cast + slot.cd + pad
        if (!ENG.on) {
            pct := 0, txt := "-", tone := (i = 1) ? CL.q : CL.e
        } else if (slot.casts > 0 && now < slot.readyAt - slot.cd) {
            pct := 1000, txt := "casting", tone := CL.bright
        } else if (left <= 0) {
            pct := 1000, txt := "READY", tone := CL.ready
        } else {
            pct := Round(1000 * (1 - (left / span)))
            txt := Format("{:.1f}s", left / 1000)
            tone := (i = 1) ? CL.q : CL.e
        }
        pct := (pct < 0) ? 0 : ((pct > 1000) ? 1000 : pct)

        PANEL["Key" . i].Text := StrUpper(slot.key)
        PANEL["Time" . i].Text := txt

        wide := Round(BAR_W * pct / 1000)
        wide := (wide < 1) ? 1 : ((wide > BAR_W) ? BAR_W : wide)
        if (slot.wide != wide) {
            slot.wide := wide
            PANEL["Bar" . i].Move( , , wide)
            PANEL["Trough" . i].Redraw()
            PANEL["Bar" . i].Redraw()
        }
        if (slot.tone != tone) {
            slot.tone := tone
            try {
                PANEL["Bar" . i].Opt("Background" . tone)
                PANEL["Bar" . i].Redraw()
            }
        }
    }
}

TogglePanel() {
    if (!IsObject(PANEL))
        return
    ENG.panelOn := !ENG.panelOn
    if (ENG.panelOn) {
        PANEL.Show("NoActivate")
        RefreshPanel()
    } else {
        PANEL.Hide()
    }
}

DragPanel(wp, lp, msg, hwnd) {
    if (!IsObject(PANEL))
        return
    owner := GuiFromHwnd(hwnd, true)
    if (owner && owner.Hwnd = PANEL.Hwnd) {
        try {
            PostMessage(0xA1, 2, 0, , "ahk_id " . PANEL.Hwnd)
        } catch {
            return
        }
    }
}

; ─────────────────────────── SETTINGS UI ──────────────────────

OpenSettings() {
    if (IsObject(ENG.set)) {
        try {
            ENG.set.Show()
            return
        }
    }
    g := Gui("+AlwaysOnTop +OwnDialogs -MaximizeBox -MinimizeBox", "DQ Cycler  -  Settings")
    g.BackColor := "14161C"
    g.MarginX := 18
    g.MarginY := 16

    Head(g, "SPELL")
    g.SetFont("s9 Norm cD5DAE3", "Segoe UI")
    g.Add("Text", "xm y+6 w70", "Profile")
    list := []
    for pre in PRESETS
        list.Push(pre.name)
    list.Push("Custom setup")
    idx := (CFG.profile >= 1 && CFG.profile <= PRESETS.Length) ? CFG.profile : list.Length
    g.Add("DropDownList", "x+8 yp-4 w228 vDdProfile Choose" . idx, list)

    g.SetFont("s8 Norm c7A828E", "Segoe UI")
    g.Add("Text", "xm y+12 w70", "")
    g.Add("Text", "x+8 yp w54 Center", "key")
    g.Add("Text", "x+6 yp w82 Center", "activation")
    g.Add("Text", "x+6 yp w82 Center", "cooldown")

    Slot(g, 1, "Slot 1")
    Slot(g, 2, "Slot 2")

    Head(g, "CONNECTION")
    g.SetFont("s9 Norm cD5DAE3", "Segoe UI")
    g.Add("Text", "xm y+8 w70", "Your ping")
    g.Add("Edit", "x+8 yp-3 w54 Center Number Background1B2029 cE8EAED vEdPing", CFG.ping)
    g.SetFont("s8 Norm c7A828E", "Segoe UI")
    g.Add("Text", "x+10 yp+2 w170", "Roblox: Esc > Settings > Performance Stats")

    Head(g, "BEHAVIOUR")
    g.SetFont("s9 Norm cD5DAE3", "Segoe UI")
    g.Add("Checkbox", "xm y+8 w320 vCbChat Checked" . (CFG.chatGuard ? 1 : 0),
          "Pause while I'm typing in Roblox chat")
    g.Add("Checkbox", "xm y+6 w320 vCbFocus Checked" . (CFG.focusGuard ? 1 : 0),
          "Only cast while Roblox is the active window")
    g.Add("Checkbox", "xm y+6 w320 vCbClick Checked" . (CFG.clickAfter ? 1 : 0),
          "Left-click after each cast (placement spells)")
    g.Add("Checkbox", "xm y+6 w320 vCbPanel Checked" . (CFG.showPanel ? 1 : 0),
          "Show the on-screen panel")

    Head(g, "ADVANCED")
    g.SetFont("s8 Norm c7A828E", "Segoe UI")
    g.Add("Text", "xm y+6 w320", "Keypress timing. Changes how many keys get sent, never when spells fire.")
    g.SetFont("s9 Norm cD5DAE3", "Segoe UI")
    g.Add("Text", "xm y+10 w40", "hold")
    g.Add("Edit", "x+4 yp-3 w52 Center Number Background1B2029 cE8EAED vEdHold", CFG.hold)
    g.Add("Text", "x+14 yp+3 w34", "lead")
    g.Add("Edit", "x+4 yp-3 w52 Center Number Background1B2029 cE8EAED vEdLead", CFG.lead)
    g.Add("Text", "x+14 yp+3 w30", "gap")
    g.Add("Edit", "x+4 yp-3 w52 Center Number Background1B2029 cE8EAED vEdGap", CFG.gap)

    g.SetFont("s9 Norm", "Segoe UI")
    g.Add("Button", "xm y+20 w104 h30 Default vBtSave", "Save")
    g.Add("Button", "x+8 yp w104 h30 vBtReset", "Reset defaults")
    g.Add("Button", "x+8 yp w104 h30 vBtClose", "Cancel")

    g["DdProfile"].OnEvent("Change", SettingsPreset)
    g["BtSave"].OnEvent("Click", SettingsSave)
    g["BtReset"].OnEvent("Click", SettingsReset)
    g["BtClose"].OnEvent("Click", SettingsClose)
    g.OnEvent("Close", SettingsClose)
    g.OnEvent("Escape", SettingsClose)

    ENG.set := g
    g.Show()
}

Head(g, title) {
    g.SetFont("s8 Bold c5A6270", "Segoe UI")
    g.Add("Text", "xm y+16 w320", title)
}

Slot(g, n, title) {
    def := CFG.slots[n]
    g.SetFont("s9 Norm cD5DAE3", "Segoe UI")
    g.Add("Text", "xm y+8 w70", title)
    g.Add("Edit", "x+8 yp-3 w54 Center Limit6 Background1B2029 cE8EAED vEdKey" . n, def.key)
    g.Add("Edit", "x+6 yp w82 Center Number Background1B2029 cE8EAED vEdCast" . n, def.cast)
    g.Add("Edit", "x+6 yp w82 Center Number Background1B2029 cE8EAED vEdCd" . n, def.cd)
}

SettingsPreset(ctrl, *) {
    g := ctrl.Gui
    i := ctrl.Value
    if (i < 1 || i > PRESETS.Length)
        return
    loop 2 {
        g["EdCast" . A_Index].Value := PRESETS[i].cast
        g["EdCd" . A_Index].Value := PRESETS[i].cd
    }
}

SettingsSave(ctrl, *) {
    g := ctrl.Gui
    loop 2 {
        n := A_Index
        key := Trim(g["EdKey" . n].Value)
        if (key != "")
            CFG.slots[n].key := key
        CFG.slots[n].cast := Clamp(g["EdCast" . n].Value, 0, 20000, CFG.slots[n].cast)
        CFG.slots[n].cd   := Clamp(g["EdCd" . n].Value, 100, 60000, CFG.slots[n].cd)
    }
    CFG.ping := Clamp(g["EdPing"].Value, 0, 1000, CFG.ping)
    CFG.hold := Clamp(g["EdHold"].Value, 10, 300, CFG.hold)
    CFG.lead := Clamp(g["EdLead"].Value, 0, 2000, CFG.lead)
    CFG.gap  := Clamp(g["EdGap"].Value, 20, 500, CFG.gap)
    CFG.chatGuard  := g["CbChat"].Value ? true : false
    CFG.focusGuard := g["CbFocus"].Value ? true : false
    CFG.clickAfter := g["CbClick"].Value ? true : false
    CFG.showPanel  := g["CbPanel"].Value ? true : false

    sel := g["DdProfile"].Value
    matches := (sel >= 1 && sel <= PRESETS.Length)
               && (CFG.slots[1].cast = PRESETS[sel].cast)
               && (CFG.slots[1].cd = PRESETS[sel].cd)
    CFG.profile := matches ? sel : PRESETS.Length + 1

    was := ENG.on
    ENG.on := false
    ReleaseKeys()
    RebuildSlots()
    ENG.on := was
    ENG.panelOn := CFG.showPanel
    if (IsObject(PANEL)) {
        if (CFG.showPanel)
            PANEL.Show("NoActivate")
        else
            PANEL.Hide()
    }
    SaveIni()
    RefreshPanel()
    SettingsClose(ctrl)
}

SettingsReset(ctrl, *) {
    CFG.ping := 70
    CFG.hold := 40
    CFG.lead := 300
    CFG.gap := 70
    CFG.chatGuard := true
    CFG.focusGuard := true
    CFG.clickAfter := false
    CFG.showPanel := true
    CFG.slots[1].key := "q"
    CFG.slots[2].key := "e"
    ApplyPreset(1)
    RebuildSlots()
    SaveIni()
    SettingsClose(ctrl)
    OpenSettings()
}

SettingsClose(ctrl, *) {
    if (IsObject(ENG.set)) {
        try ENG.set.Destroy()
    }
    ENG.set := ""
}

Clamp(val, lo, hi, fallback) {
    if (!IsNumber(val))
        return fallback
    n := Integer(val)
    if (n < lo)
        return lo
    if (n > hi)
        return hi
    return n
}

; ─────────────────────────── PERSISTENCE ──────────────────────

LoadIni() {
    if (!FileExist(INI_PATH))
        return
    CFG.ping    := Clamp(IniRead(INI_PATH, "main", "ping", CFG.ping), 0, 1000, CFG.ping)
    CFG.hold    := Clamp(IniRead(INI_PATH, "main", "hold", CFG.hold), 10, 300, CFG.hold)
    CFG.lead    := Clamp(IniRead(INI_PATH, "main", "lead", CFG.lead), 0, 2000, CFG.lead)
    CFG.gap     := Clamp(IniRead(INI_PATH, "main", "gap", CFG.gap), 20, 500, CFG.gap)
    CFG.profile := Clamp(IniRead(INI_PATH, "main", "profile", CFG.profile), 1, 9, CFG.profile)
    CFG.panelX  := Clamp(IniRead(INI_PATH, "main", "panelX", CFG.panelX), -5000, 9999, CFG.panelX)
    CFG.panelY  := Clamp(IniRead(INI_PATH, "main", "panelY", CFG.panelY), -5000, 9999, CFG.panelY)
    CFG.chatGuard  := IniRead(INI_PATH, "main", "chatGuard", "1") = "1"
    CFG.focusGuard := IniRead(INI_PATH, "main", "focusGuard", "1") = "1"
    CFG.clickAfter := IniRead(INI_PATH, "main", "clickAfter", "0") = "1"
    CFG.showPanel  := IniRead(INI_PATH, "main", "showPanel", "1") = "1"
    for i, def in CFG.slots {
        sec := "slot" . i
        key := IniRead(INI_PATH, sec, "key", def.key)
        if (Trim(key) != "")
            def.key := Trim(key)
        def.cast := Clamp(IniRead(INI_PATH, sec, "cast", def.cast), 0, 20000, def.cast)
        def.cd   := Clamp(IniRead(INI_PATH, sec, "cd", def.cd), 100, 60000, def.cd)
    }
}

SaveIni() {
    try {
        IniWrite(CFG.ping, INI_PATH, "main", "ping")
        IniWrite(CFG.hold, INI_PATH, "main", "hold")
        IniWrite(CFG.lead, INI_PATH, "main", "lead")
        IniWrite(CFG.gap, INI_PATH, "main", "gap")
        IniWrite(CFG.profile, INI_PATH, "main", "profile")
        IniWrite(CFG.chatGuard ? 1 : 0, INI_PATH, "main", "chatGuard")
        IniWrite(CFG.focusGuard ? 1 : 0, INI_PATH, "main", "focusGuard")
        IniWrite(CFG.clickAfter ? 1 : 0, INI_PATH, "main", "clickAfter")
        IniWrite(CFG.showPanel ? 1 : 0, INI_PATH, "main", "showPanel")
        IniWrite(CFG.panelX, INI_PATH, "main", "panelX")
        IniWrite(CFG.panelY, INI_PATH, "main", "panelY")
        for i, def in CFG.slots {
            IniWrite(def.key, INI_PATH, "slot" . i, "key")
            IniWrite(def.cast, INI_PATH, "slot" . i, "cast")
            IniWrite(def.cd, INI_PATH, "slot" . i, "cd")
        }
    }
}

Cleanup(*) {
    ReleaseKeys()
    if (IsObject(PANEL)) {
        try {
            WinGetPos(&px, &py, , , "ahk_id " . PANEL.Hwnd)
            CFG.panelX := px
            CFG.panelY := py
        }
    }
    SaveIni()
    DllCall("Winmm\timeEndPeriod", "UInt", 1)
    return 0
}
