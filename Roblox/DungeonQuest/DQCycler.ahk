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
;   F8  measure cooldown      F10  hide panel
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

; Each slot holds its own spell. The normal carry setup is the same spell
; in both slots (pulse + pulse on mage, arrow + arrow on war); the two
; copies hold separate cooldowns, which is what makes cycling worth doing.
;
; Your kit is one class, so both spells must come from that class - a mage
; spell cannot be paired with a warrior one.
;
; Pick Custom and type the activation and cooldown off the spell for
; anything not listed here.
SPELLS := [
    { name: "Pulse Waves", class: "mage", cast: 1000, cd: 4000 },
    { name: "Arrow Rain",  class: "war",  cast: 500,  cd: 4000 },
    { name: "Custom",      class: "any",  cast: 1000, cd: 4000 }
]

CL := { bg:"0E1015", sunk:"1B2029", dim:"4A5162", mid:"6B7280",
        text:"C9CFDA", bright:"E8EAED",
        q:"4C8DFF", e:"FF8A3D", ready:"3DDC84", warn:"FFC542",
        stop:"FF5C5C", chat:"58A6FF" }

; ─────────────────────────── SETTINGS ─────────────────────────

CFG := {
    ping: 70,
    slots: [ { key:"q", spell:"Pulse Waves", cast:1000, cd:4000, on:true },
             { key:"e", spell:"Pulse Waves", cast:1000, cd:4000, on:true } ],
    chatGuard: true,
    focusGuard: true,
    clickAfter: false,
    hold: 40,
    lead: 300,
    gap: 70,
    catchup: 1500,
    panelX: 20,
    panelY: 20,
    showPanel: true,
    ; Roblox claims a lot of function keys (F8 toggles its debug stats, F9 the
    ; dev console, F11 fullscreen), so these are editable - and the tray icon
    ; carries the same actions if a key ever gets swallowed.
    keys: { run:"F6", measure:"F2", settings:"F4", panel:"F10" }
}

ENG := { on:false, castUntil:0, nextAct:0, slots:[],
         typing:false, typingSince:0, resumeAt:0,
         panelOn:true, lastState:"", set:"",
         calT:0, calWas:false, calMsg:"", calSpell:"" }

LoadIni()
RebuildSlots()
PANEL := CFG.showPanel ? BuildPanel() : ""
ENG.panelOn := CFG.showPanel
OnExit(Cleanup)
OnMessage(0x0201, DragPanel)
SetTimer(Tick, TICK_MS)
SetTimer(RefreshPanel, 80)
BindHotkeys()
BuildTray()
RefreshPanel()

+Escape::ExitApp()


#HotIf CFG.chatGuard && (!CFG.focusGuard || WinActive(GAME_WIN))
~$/::SetTyping(true)
~$Enter::SetTyping(!ENG.typing)
~$NumpadEnter::SetTyping(!ENG.typing)
~$Escape::SetTyping(false)
#HotIf

; ─────────────────────────── HOTKEYS ──────────────────────────

; "$" forces the keyboard hook, which intercepts the key reliably inside a
; game instead of letting it fall through to Roblox.
BindHotkeys() {
    static bound := []
    for name in bound {
        try Hotkey(name, "Off")
    }
    bound := []
    pairs := [[CFG.keys.run, Toggle], [CFG.keys.measure, Calibrate],
              [CFG.keys.settings, OpenSettings], [CFG.keys.panel, TogglePanel]]
    for pair in pairs {
        key := Trim(pair[1])
        if (key = "")
            continue
        try {
            Hotkey("$" . key, pair[2], "On")
            bound.Push("$" . key)
        }
    }
}

BuildTray() {
    t := A_TrayMenu
    t.Delete()
    t.Add("Start / stop", TrayRun)
    t.Add("Measure cooldown", TrayMeasure)
    t.Add("Settings", TraySettings)
    t.Add("Show / hide panel", TrayPanel)
    t.Add()
    t.Add("Exit", TrayExit)
    t.Default := "Settings"
    A_IconTip := "DQ Cycler"
}

TrayRun(*)      => Toggle()
TrayMeasure(*)  => Calibrate()
TraySettings(*) => OpenSettings()
TrayPanel(*)    => TogglePanel()
TrayExit(*)     => ExitApp()

; ─────────────────────────── ENGINE ───────────────────────────

; The macro cannot see cooldowns, so the player times one for it.
;
; The first F8 casts the spell ITSELF rather than asking the player to
; press F8 and Q together - the clock then starts on the exact keypress,
; which is what the schedule is measured from. The second F8 is when the
; icon lights up again. A late second press only makes the figure slightly
; generous, which is the safe direction to be wrong in.
Calibrate(*) {
    if (!ENG.calT) {
        ENG.calWas := ENG.on
        ENG.on := false
        ReleaseKeys()
        ENG.calMsg := ""
        ENG.calSpell := ""
        if (ENG.slots.Length >= 1) {
            ENG.calSpell := ENG.slots[1].spell
            ENG.calT := A_TickCount
            Cast(ENG.slots[1].key)
        } else {
            ENG.calT := A_TickCount
        }
        return
    }
    span := A_TickCount - ENG.calT
    ENG.calT := 0
    if (span >= 500 && span <= 60000) {
        hit := 0
        for def in CFG.slots {
            ; only rewrite slots holding the spell we actually timed
            if (ENG.calSpell != "" && def.spell != ENG.calSpell)
                continue
            cd := span - def.cast - Margin()
            def.cd := (cd < 100) ? 100 : cd
            hit += 1
        }
        RebuildSlots()
        SaveIni()
        ENG.calMsg := "measured " . Format("{:.2f}", span / 1000) . "s  -  set on "
            . hit . ((hit = 1) ? " slot" : " slots")
    } else {
        ENG.calMsg := "too " . ((span < 500) ? "quick" : "long") . " - try again"
    }
    ENG.on := ENG.calWas
    if (ENG.on)
        ResetCycle()
}

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

    span := CycleSpan()

    ; Each slot fires on its own beat. Beats are a fixed metronome rather
    ; than being rescheduled off the last press, so one swallowed cast can
    ; never push the whole rotation a cycle late.
    for slot in ENG.slots {
        guard := 0
        while (slot.on && now > slot.due + CFG.catchup && guard++ < 200) {
            slot.due += span
            slot.beatDone := false
        }
    }

    if (now < ENG.castUntil) {
        ENG.nextAct := ENG.castUntil
        return
    }

    pick := 0
    best := 0
    for i, slot in ENG.slots {
        ; no early spam before a slot's first cast - it is genuinely off
        ; cooldown then, so an early tap would fire it and break the spacing
        if (!slot.on)
            continue
        lead := (slot.casts > 0) ? CFG.lead : 0
        if (now >= slot.due - lead && now <= slot.due + CFG.catchup
            && (pick = 0 || slot.due < best)) {
            pick := i
            best := slot.due
        }
    }
    if (pick = 0) {
        ENG.nextAct := now + TICK_MS
        return
    }

    slot := ENG.slots[pick]
    Cast(slot.key)
    t := A_TickCount

    if (t >= slot.due && !slot.beatDone) {
        slot.beatDone := true
        slot.casts += 1
        ENG.castUntil := t + slot.cast
    }

    ; keep tapping across the rest of the window. If that press was eaten
    ; because the spell was not actually up yet, the next tap catches it
    ; instead of the cast being lost for a whole cycle.
    nxt := t + CFG.gap
    if (!slot.beatDone && nxt > slot.due)
        nxt := slot.due
    ENG.nextAct := nxt
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
        ENG.slots.Push({ key:def.key, spell:def.spell, cast:def.cast, cd:def.cd,
                         on:def.on, due:0, beatDone:false, casts:0, tone:"", wide:-1 })
    ResetCycle()
}

ActiveCount() {
    n := 0
    for slot in ENG.slots {
        if (slot.on)
            n += 1
    }
    return n
}

; Both slots are locked to the SLOWEST spell's period. Firing each as fast
; as it can go would let the two drift in and out of phase; a shared period
; holds the spacing at period/N forever, which is what keeps a buff up.
CycleSpan() {
    span := 0
    for slot in ENG.slots {
        if (slot.on && slot.cast + slot.cd > span)
            span := slot.cast + slot.cd
    }
    span += Margin()
    return (span < 200) ? 200 : span
}

SetupName() {
    parts := ""
    for slot in ENG.slots {
        if (!slot.on)
            continue
        parts .= ((parts = "") ? "" : " + ") . slot.spell
    }
    return (parts = "") ? "no slots enabled" : parts
}

ResetCycle() {
    now := A_TickCount
    ENG.castUntil := now
    ENG.nextAct := now
    span := CycleSpan()
    n := ActiveCount()
    if (n < 1)
        n := 1
    j := 0
    for slot in ENG.slots {
        slot.beatDone := false
        slot.casts := 0
        if (!slot.on) {
            slot.due := now + span * 999
            continue
        }
        slot.due := now + Round(j * span / n)
        j += 1
    }
}

ReleaseKeys() {
    for slot in ENG.slots
        Send("{" slot.key " up}")
}

Toggle(*) {
    ENG.on := !ENG.on
    if (ENG.on)
        ResetCycle()
    else
        ReleaseKeys()
}

; ─────────────────────────── PANEL ────────────────────────────

BuildPanel() {
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000", "DQ Cycler")
    g.BackColor := CL.bg

    g.SetFont("s8 Bold c" . CL.dim, "Segoe UI")
    g.Add("Text", "x16 y12 w110", "DQ CYCLER")
    g.SetFont("s8 Norm c" . CL.dim)
    g.Add("Text", "x126 y12 w108 Right vHelp", "settings")

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

    if (ENG.calT) {
        state := "TIMING", colour := CL.warn
        note := Format("{:.1f}", (A_TickCount - ENG.calT) / 1000)
            . "s - press " . CFG.keys.measure . " when the icon lights up"
    } else if (!ENG.on) {
        state := "STOPPED", colour := CL.stop
        note := (ENG.calMsg != "") ? ENG.calMsg : "press F6 to start"
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
    PANEL["Profile"].Text := SetupName()
    PANEL["Help"].Text := CFG.keys.settings . "  settings"
    PANEL["Foot"].Text := "ping " . CFG.ping . "ms      cycle "
        . Format("{:.2f}", CycleSpan() / 1000) . "s      " . CFG.keys.run . " start/stop"

    now := A_TickCount
    span := CycleSpan()
    for i, slot in ENG.slots {
        if (i > 2)
            break
        left := slot.due - now
        if (!slot.on) {
            pct := 0, txt := "off", tone := CL.sunk
        } else if (!ENG.on) {
            pct := 0, txt := "-", tone := (i = 1) ? CL.q : CL.e
        } else if (slot.beatDone && now < slot.due + slot.cast) {
            pct := 1000, txt := "casting", tone := CL.bright
        } else if (left <= 0) {
            pct := 1000, txt := "FIRING", tone := CL.ready
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

TogglePanel(*) {
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

OpenSettings(*) {
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

    Head(g, "SPELLS")
    g.SetFont("s8 Norm c7A828E", "Segoe UI")
    g.Add("Text", "xm y+6 w64", "")
    g.Add("Text", "x+6 yp w132 Center", "spell")
    g.Add("Text", "x+6 yp w44 Center", "key")
    g.Add("Text", "x+6 yp w62 Center", "activation")
    g.Add("Text", "x+6 yp w62 Center", "cooldown")
    g.SetFont("s8 Norm c7A828E", "Segoe UI")

    SlotRow(g, 1)
    SlotRow(g, 2)

    g.SetFont("s8 Norm c7A828E", "Segoe UI")
    g.Add("Text", "xm y+10 w380 h44",
        "These are guesses and the real cooldown is longer - activation, server tick and`n"
        . "ping all add on. Even 300ms off breaks the rhythm, so measure it instead: the`n"
        . "button below casts the spell, then you press the measure key when it lights up.")
    g.SetFont("s9 Norm", "Segoe UI")
    g.Add("Button", "xm y+10 w186 h28 vBtCal", "Measure cooldown now")
    g.SetFont("s8 Norm cFFC542", "Segoe UI")
    g.Add("Text", "xm y+10 w380 h30 vWarn", "")

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

    Head(g, "HOTKEYS")
    g.SetFont("s8 Norm c7A828E", "Segoe UI")
    g.Add("Text", "xm y+6 w380", "Roblox uses F8 for its debug stats and F9 for the console. "
        . "Right-click the tray icon if a key ever stops responding.")
    g.SetFont("s9 Norm cD5DAE3", "Segoe UI")
    g.Add("Text", "xm y+10 w66", "start/stop")
    g.Add("Edit", "x+4 yp-3 w54 Center Limit12 Background1B2029 cE8EAED vEdKeyRun", CFG.keys.run)
    g.Add("Text", "x+12 yp+3 w54", "measure")
    g.Add("Edit", "x+4 yp-3 w54 Center Limit12 Background1B2029 cE8EAED vEdKeyMeas", CFG.keys.measure)
    g.Add("Text", "xm y+9 w66", "settings")
    g.Add("Edit", "x+4 yp-3 w54 Center Limit12 Background1B2029 cE8EAED vEdKeySet", CFG.keys.settings)
    g.Add("Text", "x+12 yp+3 w54", "panel")
    g.Add("Edit", "x+4 yp-3 w54 Center Limit12 Background1B2029 cE8EAED vEdKeyPanel", CFG.keys.panel)

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
    g.SetFont("s9 Norm cD5DAE3", "Segoe UI")
    g.Add("Text", "xm y+10 w150", "catch-up window")
    g.Add("Edit", "x+4 yp-3 w52 Center Number Background1B2029 cE8EAED vEdCatch", CFG.catchup)
    g.SetFont("s8 Norm c7A828E", "Segoe UI")
    g.Add("Text", "xm y+8 w320", "How long to keep retrying after a spell should be up. Raise this if casts get skipped.")

    g.SetFont("s9 Norm", "Segoe UI")
    g.Add("Button", "xm y+20 w104 h30 Default vBtSave", "Save")
    g.Add("Button", "x+8 yp w104 h30 vBtReset", "Reset defaults")
    g.Add("Button", "x+8 yp w104 h30 vBtClose", "Cancel")

    g["DdSpell1"].OnEvent("Change", SettingsPreset)
    g["DdSpell2"].OnEvent("Change", SettingsPreset)
    g["CbOn1"].OnEvent("Click", (c, *) => SettingsWarn(c.Gui))
    g["CbOn2"].OnEvent("Click", (c, *) => SettingsWarn(c.Gui))
    SettingsWarn(g)
    g["BtCal"].OnEvent("Click", SettingsMeasure)
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

SlotRow(g, n) {
    def := CFG.slots[n]
    names := []
    for sp in SPELLS
        names.Push(sp.name)
    idx := names.Length
    for i, nm in names {
        if (nm = def.spell)
            idx := i
    }
    g.SetFont("s9 Norm cD5DAE3", "Segoe UI")
    g.Add("Checkbox", "xm y+9 w64 vCbOn" . n . " Checked" . (def.on ? 1 : 0), "Slot " . n)
    g.Add("DropDownList", "x+6 yp-4 w132 vDdSpell" . n . " Choose" . idx, names)
    g.Add("Edit", "x+6 yp w44 Center Limit6 Background1B2029 cE8EAED vEdKey" . n, def.key)
    g.Add("Edit", "x+6 yp w62 Center Number Background1B2029 cE8EAED vEdCast" . n, def.cast)
    g.Add("Edit", "x+6 yp w62 Center Number Background1B2029 cE8EAED vEdCd" . n, def.cd)
}

SpellClass(name) {
    for sp in SPELLS {
        if (sp.name = name)
            return sp.class
    }
    return "any"
}

SettingsWarn(g) {
    if (!(g["CbOn1"].Value && g["CbOn2"].Value)) {
        g["Warn"].Text := ""
        return
    }
    a := g["DdSpell1"].Text
    b := g["DdSpell2"].Text
    ca := SpellClass(a)
    cb := SpellClass(b)
    if (ca != "any" && cb != "any" && ca != cb) {
        g["Warn"].Text := a . " is a " . ca . " spell and " . b . " is a " . cb . " spell. "
            . "Your kit is one class, so you cannot equip both."
    } else {
        g["Warn"].Text := ""
    }
}

SettingsPreset(ctrl, *) {
    g := ctrl.Gui
    n := (ctrl.Name = "DdSpell1") ? 1 : 2
    i := ctrl.Value
    if (i >= 1 && i < SPELLS.Length) {        ; the last entry is "Custom"
        g["EdCast" . n].Value := SPELLS[i].cast
        g["EdCd" . n].Value := SPELLS[i].cd
    }
    SettingsWarn(g)
}

SettingsSave(ctrl, *) {
    g := ctrl.Gui
    loop 2 {
        n := A_Index
        key := Trim(g["EdKey" . n].Value)
        if (key != "")
            CFG.slots[n].key := key
        CFG.slots[n].spell := g["DdSpell" . n].Text
        CFG.slots[n].cast  := Clamp(g["EdCast" . n].Value, 0, 20000, CFG.slots[n].cast)
        CFG.slots[n].cd    := Clamp(g["EdCd" . n].Value, 100, 60000, CFG.slots[n].cd)
        CFG.slots[n].on    := g["CbOn" . n].Value ? true : false
    }
    CFG.ping := Clamp(g["EdPing"].Value, 0, 1000, CFG.ping)
    CFG.hold := Clamp(g["EdHold"].Value, 10, 300, CFG.hold)
    CFG.lead := Clamp(g["EdLead"].Value, 0, 2000, CFG.lead)
    CFG.gap  := Clamp(g["EdGap"].Value, 20, 500, CFG.gap)
    CFG.catchup := Clamp(g["EdCatch"].Value, 0, 4000, CFG.catchup)
    CFG.chatGuard  := g["CbChat"].Value ? true : false
    CFG.focusGuard := g["CbFocus"].Value ? true : false
    CFG.clickAfter := g["CbClick"].Value ? true : false
    CFG.showPanel  := g["CbPanel"].Value ? true : false
    CFG.keys.run      := KeyOr(g["EdKeyRun"].Value, CFG.keys.run)
    CFG.keys.measure  := KeyOr(g["EdKeyMeas"].Value, CFG.keys.measure)
    CFG.keys.settings := KeyOr(g["EdKeySet"].Value, CFG.keys.settings)
    CFG.keys.panel    := KeyOr(g["EdKeyPanel"].Value, CFG.keys.panel)
    BindHotkeys()

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
    CFG.catchup := 1500
    CFG.chatGuard := true
    CFG.focusGuard := true
    CFG.clickAfter := false
    CFG.showPanel := true
    CFG.slots[1].key := "q", CFG.slots[1].spell := "Pulse Waves"
    CFG.slots[1].cast := 1000, CFG.slots[1].cd := 4000, CFG.slots[1].on := true
    CFG.slots[2].key := "e", CFG.slots[2].spell := "Pulse Waves"
    CFG.slots[2].cast := 1000, CFG.slots[2].cd := 4000, CFG.slots[2].on := true
    CFG.keys.run := "F6", CFG.keys.measure := "F2"
    CFG.keys.settings := "F4", CFG.keys.panel := "F10"
    BindHotkeys()
    RebuildSlots()
    SaveIni()
    SettingsClose(ctrl)
    OpenSettings()
}

SettingsMeasure(ctrl, *) {
    SettingsClose(ctrl)
    Calibrate()
}

SettingsClose(ctrl, *) {
    if (IsObject(ENG.set)) {
        try ENG.set.Destroy()
    }
    ENG.set := ""
}

KeyOr(val, fallback) {
    v := Trim(val)
    if (v = "")
        return fallback
    try {
        Hotkey("$" . v, (*) => 0, "Off")     ; reject anything AHK cannot bind
        return v
    }
    return fallback
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
    CFG.catchup := Clamp(IniRead(INI_PATH, "main", "catchup", CFG.catchup), 0, 4000, CFG.catchup)
    CFG.panelX  := Clamp(IniRead(INI_PATH, "main", "panelX", CFG.panelX), -5000, 9999, CFG.panelX)
    CFG.panelY  := Clamp(IniRead(INI_PATH, "main", "panelY", CFG.panelY), -5000, 9999, CFG.panelY)
    CFG.chatGuard  := IniRead(INI_PATH, "main", "chatGuard", "1") = "1"
    CFG.focusGuard := IniRead(INI_PATH, "main", "focusGuard", "1") = "1"
    CFG.clickAfter := IniRead(INI_PATH, "main", "clickAfter", "0") = "1"
    CFG.showPanel  := IniRead(INI_PATH, "main", "showPanel", "1") = "1"
    CFG.keys.run      := IniRead(INI_PATH, "keys", "run", CFG.keys.run)
    CFG.keys.measure  := IniRead(INI_PATH, "keys", "measure", CFG.keys.measure)
    CFG.keys.settings := IniRead(INI_PATH, "keys", "settings", CFG.keys.settings)
    CFG.keys.panel    := IniRead(INI_PATH, "keys", "panel", CFG.keys.panel)
    for i, def in CFG.slots {
        sec := "slot" . i
        key := IniRead(INI_PATH, sec, "key", def.key)
        if (Trim(key) != "")
            def.key := Trim(key)
        def.cast := Clamp(IniRead(INI_PATH, sec, "cast", def.cast), 0, 20000, def.cast)
        def.cd   := Clamp(IniRead(INI_PATH, sec, "cd", def.cd), 100, 60000, def.cd)
        sp := IniRead(INI_PATH, sec, "spell", def.spell)
        if (Trim(sp) != "")
            def.spell := Trim(sp)
        def.on := IniRead(INI_PATH, sec, "on", "1") = "1"
    }
}

SaveIni() {
    try {
        IniWrite(CFG.ping, INI_PATH, "main", "ping")
        IniWrite(CFG.hold, INI_PATH, "main", "hold")
        IniWrite(CFG.lead, INI_PATH, "main", "lead")
        IniWrite(CFG.gap, INI_PATH, "main", "gap")
        IniWrite(CFG.catchup, INI_PATH, "main", "catchup")
        IniWrite(CFG.chatGuard ? 1 : 0, INI_PATH, "main", "chatGuard")
        IniWrite(CFG.focusGuard ? 1 : 0, INI_PATH, "main", "focusGuard")
        IniWrite(CFG.clickAfter ? 1 : 0, INI_PATH, "main", "clickAfter")
        IniWrite(CFG.showPanel ? 1 : 0, INI_PATH, "main", "showPanel")
        IniWrite(CFG.panelX, INI_PATH, "main", "panelX")
        IniWrite(CFG.panelY, INI_PATH, "main", "panelY")
        IniWrite(CFG.keys.run, INI_PATH, "keys", "run")
        IniWrite(CFG.keys.measure, INI_PATH, "keys", "measure")
        IniWrite(CFG.keys.settings, INI_PATH, "keys", "settings")
        IniWrite(CFG.keys.panel, INI_PATH, "keys", "panel")
        for i, def in CFG.slots {
            IniWrite(def.key, INI_PATH, "slot" . i, "key")
            IniWrite(def.cast, INI_PATH, "slot" . i, "cast")
            IniWrite(def.cd, INI_PATH, "slot" . i, "cd")
            IniWrite(def.spell, INI_PATH, "slot" . i, "spell")
            IniWrite(def.on ? 1 : 0, INI_PATH, "slot" . i, "on")
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
