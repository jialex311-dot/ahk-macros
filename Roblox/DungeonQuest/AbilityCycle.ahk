#Requires AutoHotkey v2.0

; Dungeon Quest (Roblox) - spell cycler.
;
; Runs the same spell in both slots and staggers them so one is always
; going out: the opener is timed off the cast animation, then the keys
; get spammed so nothing is ever missed by a few ms.
;
; F6 = on/off | F7 = profile | F8 = mode | F10 = hide panel | Shift+Esc = quit

#SingleInstance Force
SetWorkingDir(A_ScriptDir)
SendMode("Input")
ProcessSetPriority("High")
ListLines(False)
KeyHistory(0)
DllCall("Winmm\timeBeginPeriod", "UInt", 1)

; ─────────────────────────── CONFIG ───────────────────────────

; Only fire while Roblox is the focused window. Set to "" to run anywhere.
GAME_WINDOW := "ahk_exe RobloxPlayerBeta.exe"

; Which profile below to start on (1 = Mage, 2 = Warrior)
START_PROFILE := 1

; "cycle" - one press per spell, exactly on cooldown. Tightest, least forgiving.
; "spam"  - timed opener, then taps in a burst around each ready time. Default.
; "mash"  - timed opener, then blind Q/E alternation forever.
START_MODE := "spam"

HOLD_MS   := 40   ; how long each key is held down
MARGIN_MS := 70   ; pad added to every cooldown (ping / server tick slop)
LEAD_MS   := 300  ; spam mode: start tapping this early
GAP_MS    := 70   ; spam mode: delay between taps inside a burst
MASH_MS   := 90   ; mash mode: delay between alternating taps
TICK_MS   := 10   ; scheduler resolution

CLICK_AFTER_CAST := false  ; also left-click after each cast (placement spells)

SHOW_PANEL := true   ; on-screen status panel (drag it anywhere, F10 hides it)
PANEL_X    := 20     ; starting position
PANEL_Y    := 20

; cast = spell activation time, cd = the cooldown listed on the spell.
; Total spell cycle = cast + cd.
PROFILES := [
    {
        name: "Mage - Pulse Waves",
        slots: [
            { key: "q", cast: 1000, cd: 4000 },   ; 1.0s activation + 4s CD = 5.0s
            { key: "e", cast: 1000, cd: 4000 }
        ]
    },
    {
        name: "Warrior - Arrow Rain",
        slots: [
            { key: "q", cast: 500, cd: 4000 },    ; 0.5s activation + 4s CD = 4.5s
            { key: "e", cast: 500, cd: 4000 }
        ]
    }
]

; ─────────────────────────── ENGINE ───────────────────────────

MODES := ["cycle", "spam", "mash"]

ENG := { on: false, p: 0, mode: START_MODE, castUntil: 0, nextAct: 0, mashIdx: 1, slots: [] }

LoadProfile(START_PROFILE)
PANEL := SHOW_PANEL ? BuildPanel() : ""
ENG.panelOn := SHOW_PANEL
ENG.lastState := ""
OnExit(Cleanup)
OnMessage(0x0201, DragPanel)
SetTimer(Tick, TICK_MS)
SetTimer(RefreshPanel, 100)
RefreshPanel()

F6::Toggle()
F7::NextProfile()
F8::NextMode()
F10::TogglePanel()
+Escape::ExitApp()

Tick() {
    static busy := false
    if (busy || !ENG.on)
        return
    if (GAME_WINDOW != "" && !WinActive(GAME_WINDOW))
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

    ; mash: once every slot has fired once the stagger is set, so stop
    ; thinking about it and just alternate.
    if (ENG.mode = "mash" && Primed()) {
        Cast(ENG.slots[ENG.mashIdx].key)
        ENG.mashIdx := Mod(ENG.mashIdx, ENG.slots.Length) + 1
        ENG.nextAct := A_TickCount + MASH_MS
        return
    }

    ; never touch a key while a cast animation is still playing - that is
    ; what keeps the two slots from stepping on each other.
    if (now < ENG.castUntil) {
        ENG.nextAct := ENG.castUntil
        return
    }

    lead := (ENG.mode = "spam") ? LEAD_MS : 0
    pick := 0
    best := 0
    for i, s in ENG.slots {
        due := s.readyAt + MARGIN_MS
        if (now >= due - lead && (pick = 0 || due < best)) {
            pick := i
            best := due
        }
    }
    if (pick = 0) {
        ENG.nextAct := now + TICK_MS
        return
    }

    s := ENG.slots[pick]
    Cast(s.key)
    t := A_TickCount
    due := s.readyAt + MARGIN_MS

    if (t >= due) {
        ; spell was off cooldown, so this press fired it
        s.readyAt := t + s.cast + s.cd
        s.casts += 1
        ENG.castUntil := t + s.cast
        ENG.nextAct := t
    } else {
        ; still on cooldown - keep tapping, but land the next tap exactly on ready
        nxt := t + GAP_MS
        ENG.nextAct := (nxt > due) ? due : nxt
    }
}

Cast(key) {
    Send("{" key " down}")
    DllCall("Sleep", "UInt", HOLD_MS)
    Send("{" key " up}")
    if (CLICK_AFTER_CAST) {
        DllCall("Sleep", "UInt", 15)
        Click()
    }
}

Primed() {
    for s in ENG.slots {
        if (s.casts < 1)
            return false
    }
    return true
}

LoadProfile(i) {
    ENG.p := i
    ENG.slots := []
    for def in PROFILES[i].slots
        ENG.slots.Push({ key: def.key, cast: def.cast, cd: def.cd, readyAt: 0, casts: 0 })
    ResetCycle()
}

ResetCycle() {
    now := A_TickCount
    ENG.castUntil := now
    ENG.nextAct := now
    ENG.mashIdx := 1
    for s in ENG.slots {
        s.readyAt := now
        s.casts := 0
    }
}

ReleaseKeys() {
    for s in ENG.slots
        Send("{" s.key " up}")
}

Toggle() {
    ENG.on := !ENG.on
    if (ENG.on)
        ResetCycle()
    else
        ReleaseKeys()
}

NextProfile() {
    was := ENG.on
    ENG.on := false
    ReleaseKeys()
    LoadProfile(Mod(ENG.p, PROFILES.Length) + 1)
    ENG.on := was
}

NextMode() {
    i := 1
    for idx, m in MODES {
        if (m = ENG.mode) {
            i := idx
            break
        }
    }
    ENG.mode := MODES[Mod(i, MODES.Length) + 1]
    ResetCycle()
}

BuildPanel() {
    g := Gui("-Caption +AlwaysOnTop +ToolWindow +E0x08000000", "DQ Cycler")
    g.BackColor := "16181D"
    g.MarginX := 14
    g.MarginY := 12

    g.SetFont("s8 cA0A6B0", "Segoe UI")
    g.Add("Text", "xm ym w206", "DUNGEON QUEST CYCLER")

    g.SetFont("s17 Bold cFF5555")
    g.Add("Text", "xm y+2 w206 vState", "STOPPED")

    g.SetFont("s8 Norm c7A828E")
    g.Add("Text", "xm y+4 w206 h15 vNote", "press F6 to start")

    g.SetFont("s10 Norm cE8EAED")
    g.Add("Text", "xm y+10 w206 vProfile", "-")
    g.SetFont("s9 c9AA2AE")
    g.Add("Text", "xm y+3 w206 vMode", "-")

    g.SetFont("s10 Bold cE8EAED", "Consolas")
    g.Add("Text", "xm y+10 w206 h36 vSlots", "")

    g.SetFont("s8 Norm c6C7480", "Segoe UI")
    g.Add("Text", "xm y+8 w206", "F6 start/stop     F7 profile`nF8 mode           F10 hide")

    g.Show("x" . PANEL_X . " y" . PANEL_Y . " AutoSize NoActivate")
    return g
}

RefreshPanel() {
    if (!IsObject(PANEL) || !ENG.panelOn)
        return

    if (!ENG.on) {
        state := "STOPPED", colour := "cFF5555", note := "press F6 to start"
    } else if (GAME_WINDOW != "" && !WinActive(GAME_WINDOW)) {
        state := "WAITING", colour := "cFFC542", note := "Roblox is not the active window"
    } else {
        state := "RUNNING", colour := "c46D160", note := "casting"
    }

    if (state != ENG.lastState) {
        ENG.lastState := state
        try {
            PANEL["State"].Opt(colour)
            PANEL["State"].Text := state
            PANEL["State"].Redraw()
        } catch {
            PANEL["State"].Text := state
        }
    }
    PANEL["Note"].Text := note
    PANEL["Profile"].Text := PROFILES[ENG.p].name
    PANEL["Mode"].Text := "mode: " . ENG.mode

    now := A_TickCount
    lines := ""
    for slot in ENG.slots {
        left := slot.readyAt + MARGIN_MS - now
        if (!ENG.on)
            bar := "-"
        else if (now < slot.readyAt - slot.cd)
            bar := "casting"
        else if (left <= 0)
            bar := "READY"
        else
            bar := Format("{:.1f}s", left / 1000)
        lines .= ((lines = "") ? "" : "`n") . StrUpper(slot.key) . "   " . bar
    }
    PANEL["Slots"].Text := lines
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
    if (owner && owner.Hwnd = PANEL.Hwnd)
        try {
            PostMessage(0xA1, 2, 0, , "ahk_id " . PANEL.Hwnd)
        } catch {
            return
        }
}

Cleanup(*) {
    ReleaseKeys()
    DllCall("Winmm\timeEndPeriod", "UInt", 1)
    return 0
}
