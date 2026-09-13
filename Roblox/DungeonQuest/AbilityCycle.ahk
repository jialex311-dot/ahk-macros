#Requires AutoHotkey v2.0

; Dungeon Quest (Roblox) - spell cycler.
;
; Runs the same spell in both slots and staggers them so one is always
; going out: the opener is timed off the cast animation, then the keys
; get spammed so nothing is ever missed by a few ms.
;
; F6 = on/off | F7 = profile | F8 = mode | Shift+Esc = quit

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
SHOW_STATUS      := true   ; tooltip on toggle / profile / mode change

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

S := { on: false, p: 0, mode: START_MODE, castUntil: 0, nextAct: 0, mashIdx: 1, slots: [] }

LoadProfile(START_PROFILE)
Status(StatusText("OFF"))
OnExit(Cleanup)
SetTimer(Tick, TICK_MS)

F6::Toggle()
F7::NextProfile()
F8::NextMode()
+Escape::ExitApp()

Tick() {
    static busy := false
    if (busy || !S.on)
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
    if (now < S.nextAct)
        return

    ; mash: once every slot has fired once the stagger is set, so stop
    ; thinking about it and just alternate.
    if (S.mode = "mash" && Primed()) {
        Cast(S.slots[S.mashIdx].key)
        S.mashIdx := Mod(S.mashIdx, S.slots.Length) + 1
        S.nextAct := A_TickCount + MASH_MS
        return
    }

    ; never touch a key while a cast animation is still playing - that is
    ; what keeps the two slots from stepping on each other.
    if (now < S.castUntil) {
        S.nextAct := S.castUntil
        return
    }

    lead := (S.mode = "spam") ? LEAD_MS : 0
    pick := 0
    best := 0
    for i, s in S.slots {
        due := s.readyAt + MARGIN_MS
        if (now >= due - lead && (pick = 0 || due < best)) {
            pick := i
            best := due
        }
    }
    if (pick = 0) {
        S.nextAct := now + TICK_MS
        return
    }

    s := S.slots[pick]
    Cast(s.key)
    t := A_TickCount
    due := s.readyAt + MARGIN_MS

    if (t >= due) {
        ; spell was off cooldown, so this press fired it
        s.readyAt := t + s.cast + s.cd
        s.casts += 1
        S.castUntil := t + s.cast
        S.nextAct := t
    } else {
        ; still on cooldown - keep tapping, but land the next tap exactly on ready
        nxt := t + GAP_MS
        S.nextAct := (nxt > due) ? due : nxt
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
    for s in S.slots {
        if (s.casts < 1)
            return false
    }
    return true
}

LoadProfile(i) {
    S.p := i
    S.slots := []
    for def in PROFILES[i].slots
        S.slots.Push({ key: def.key, cast: def.cast, cd: def.cd, readyAt: 0, casts: 0 })
    ResetCycle()
}

ResetCycle() {
    now := A_TickCount
    S.castUntil := now
    S.nextAct := now
    S.mashIdx := 1
    for s in S.slots {
        s.readyAt := now
        s.casts := 0
    }
}

ReleaseKeys() {
    for s in S.slots
        Send("{" s.key " up}")
}

Toggle() {
    S.on := !S.on
    if (S.on)
        ResetCycle()
    else
        ReleaseKeys()
    Status(StatusText(S.on ? "ON" : "OFF"))
}

NextProfile() {
    was := S.on
    S.on := false
    ReleaseKeys()
    LoadProfile(Mod(S.p, PROFILES.Length) + 1)
    S.on := was
    Status(StatusText(S.on ? "ON" : "OFF"))
}

NextMode() {
    i := 1
    for idx, m in MODES {
        if (m = S.mode) {
            i := idx
            break
        }
    }
    S.mode := MODES[Mod(i, MODES.Length) + 1]
    ResetCycle()
    Status(StatusText(S.on ? "ON" : "OFF"))
}

StatusText(state) {
    keys := ""
    for s in S.slots
        keys .= ((keys = "") ? "" : " / ") . StrUpper(s.key)
    t := "Dungeon Quest cycler: " . state . "`n"
    t .= "Profile: " . PROFILES[S.p].name . "`n"
    t .= "Mode: " . S.mode . "`n"
    t .= "Keys: " . keys . "`n"
    t .= "F6 on/off | F7 profile | F8 mode | Shift+Esc quit"
    return t
}

Status(text) {
    if (!SHOW_STATUS)
        return
    ToolTip(text)
    SetTimer(HideTip, -2000)
}

HideTip() {
    ToolTip()
}

Cleanup(*) {
    ReleaseKeys()
    DllCall("Winmm\timeEndPeriod", "UInt", 1)
    return 0
}
