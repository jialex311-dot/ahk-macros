#Requires AutoHotkey v2.0

; Dungeon Quest (Roblox) - spell cycler.
;
; Runs the same spell in both slots and staggers them so one is always
; going out: the opener is timed off the cast animation, then both keys
; are spammed so a dropped input never costs you a cast.
;
; F6 = start/stop | F7 = profile | F10 = hide panel | Shift+Esc = quit
; Chat guard pauses it automatically while you type in Roblox.

#SingleInstance Force
SetWorkingDir(A_ScriptDir)
SendMode("Input")
ProcessSetPriority("High")
ListLines(False)
KeyHistory(0)
DllCall("Winmm\timeBeginPeriod", "UInt", 1)

; ─────────────────────────── CONFIG ───────────────────────────

; YOUR ROBLOX PING, in milliseconds.
; Find it in Roblox: Esc > Settings > Performance Stats (or Shift+F3),
; then read the "Ping" figure while you are in a dungeon.
;
; The macro cannot see your real cooldowns, so it pads every one by this
; much before pressing. Too low and your press lands before the server
; agrees the spell is up, and gets eaten. Too high and you donate uptime.
; If casts still get swallowed, add 30-50 to whatever your ping reads.
PING_MS := 70

; Roblox ticks at 60Hz, so the pad never drops below this no matter how
; good your connection is.
MARGIN_FLOOR := 25

; Only fire while Roblox is the focused window. Set to "" to run anywhere.
GAME_WINDOW := "ahk_exe RobloxPlayerBeta.exe"

; Which profile below to start on (1 = Mage, 2 = Warrior)
START_PROFILE := 1

; ── Chat guard ──
; Pauses the macro the moment you open Roblox chat and resumes when you
; are done, so your spell keys never end up in the chat box.
CHAT_GUARD    := true
CHAT_TIMEOUT  := 20000  ; force-resume if chat never reports closing (0 = never)
RESUME_MS     := 300    ; settling time after chat closes, before casting resumes

HOLD_MS := 40   ; how long each key is held down
LEAD_MS := 300  ; start tapping this long before a spell comes up
GAP_MS  := 70   ; delay between taps inside a burst
TICK_MS := 10   ; scheduler resolution

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

ENG := { on: false, p: 0, castUntil: 0, nextAct: 0, slots: [],
         typing: false, typingSince: 0, resumeAt: 0,
         panelOn: true, lastState: "" }

LoadProfile(START_PROFILE)
PANEL := SHOW_PANEL ? BuildPanel() : ""
ENG.panelOn := SHOW_PANEL
OnExit(Cleanup)
OnMessage(0x0201, DragPanel)
SetTimer(Tick, TICK_MS)
SetTimer(RefreshPanel, 100)
RefreshPanel()

F6::Toggle()
F7::NextProfile()
F10::TogglePanel()
+Escape::ExitApp()

; ── chat guard ────────────────────────────────────────────────
; `~` lets the key through to Roblox as normal; we only watch it.
#HotIf CHAT_GUARD && (GAME_WINDOW = "" || WinActive(GAME_WINDOW))
~$/::SetTyping(true)
~$Enter::SetTyping(!ENG.typing)
~$NumpadEnter::SetTyping(!ENG.typing)
~$Escape::SetTyping(false)
#HotIf

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

; The pad added to every cooldown, sized from your ping.
Margin() {
    return (PING_MS > MARGIN_FLOOR) ? PING_MS : MARGIN_FLOOR
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

    ; never touch a key while a cast animation is still playing - that is
    ; what keeps the two slots from stepping on each other.
    if (now < ENG.castUntil) {
        ENG.nextAct := ENG.castUntil
        return
    }

    pad := Margin()
    pick := 0
    best := 0
    for i, slot in ENG.slots {
        due := slot.readyAt + pad
        if (now >= due - LEAD_MS && (pick = 0 || due < best)) {
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
        ENG.castUntil := t + slot.cast
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

LoadProfile(i) {
    ENG.p := i
    ENG.slots := []
    for def in PROFILES[i].slots
        ENG.slots.Push({ key: def.key, cast: def.cast, cd: def.cd, readyAt: 0 })
    ResetCycle()
}

ResetCycle() {
    now := A_TickCount
    ENG.castUntil := now
    ENG.nextAct := now
    for slot in ENG.slots
        slot.readyAt := now
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
    was := ENG.on
    ENG.on := false
    ReleaseKeys()
    LoadProfile(Mod(ENG.p, PROFILES.Length) + 1)
    ENG.on := was
}

; ─────────────────────────── PANEL ────────────────────────────

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
    g.Add("Text", "xm y+3 w206 vPing", "-")

    g.SetFont("s10 Bold cE8EAED", "Consolas")
    g.Add("Text", "xm y+10 w206 h36 vSlots", "")

    g.SetFont("s8 Norm c6C7480", "Segoe UI")
    g.Add("Text", "xm y+8 w206", "F6 start/stop     F7 profile`nF10 hide          Shift+Esc quit")

    g.Show("x" . PANEL_X . " y" . PANEL_Y . " AutoSize NoActivate")
    return g
}

RefreshPanel() {
    if (!IsObject(PANEL) || !ENG.panelOn)
        return

    if (!ENG.on) {
        state := "STOPPED", colour := "cFF5555", note := "press F6 to start"
    } else if (ENG.typing) {
        state := "TYPING", colour := "c58A6FF", note := "chat is open - paused"
    } else if (GAME_WINDOW != "" && !WinActive(GAME_WINDOW)) {
        state := "WAITING", colour := "cFFC542", note := "Roblox is not the active window"
    } else if (A_TickCount < ENG.resumeAt) {
        state := "TYPING", colour := "c58A6FF", note := "resuming..."
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
    PANEL["Ping"].Text := "ping: " . PING_MS . "ms" . (CHAT_GUARD ? "   chat guard: on" : "")

    now := A_TickCount
    pad := Margin()
    lines := ""
    for slot in ENG.slots {
        left := slot.readyAt + pad - now
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
    if (owner && owner.Hwnd = PANEL.Hwnd) {
        try {
            PostMessage(0xA1, 2, 0, , "ahk_id " . PANEL.Hwnd)
        } catch {
            return
        }
    }
}

Cleanup(*) {
    ReleaseKeys()
    DllCall("Winmm\timeEndPeriod", "UInt", 1)
    return 0
}
