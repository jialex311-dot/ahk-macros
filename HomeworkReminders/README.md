# Homework Reminders (iPhone)

An automated homework capture system that runs entirely on your iPhone.
No computer, no server, no subscription, and **no Canvas access token**.

Total setup: about 15 minutes, once.

---

## Why this design

Canvas is not a complete source of truth — teachers announce homework out loud
that never gets posted. A system that only reads Canvas will quietly miss things,
and a system you have to type into every day won't get used.

So this splits the problem in two:

| Layer | Covers | Your daily input |
|---|---|---|
| 1. Canvas calendar subscription | Anything with a due date in Canvas | none |
| 2. Homework Check shortcut | Homework teachers only said out loud | ~3 taps |
| 3. Canvas Sync shortcut | Turns layer 1 into checkable reminders | none |

Layers 1 and 3 run with zero interaction. Layer 2 is the only thing you touch,
and it's a checkbox screen that takes about five seconds.

### No access token needed

An earlier version of this used the Canvas REST API with a personal access token.
That was dropped. Layer 3 reads the **subscribed calendar** created in layer 1
instead, which returns the same assignments with no token, no JSON parsing, and
about half as many actions to build. It also works if your school has disabled
student access tokens, which many do.

The API version is still documented in the appendix if you ever want submitted
vs. unsubmitted filtering, which the calendar feed can't provide.

---

## Before you start

1. Open **Reminders** and create a new list called `School`.
   Every shortcut below writes into this list. The name must match exactly.
2. Make sure the **Shortcuts** app is installed. It ships with iOS; if you
   deleted it, re-download it free from the App Store.
3. You need iOS 17 or newer for automations to run without a confirmation tap.

---

## Layer 1 — Subscribe to your Canvas calendar

This pulls every dated Canvas assignment into Apple Calendar and keeps itself
current forever. Nothing to maintain.

1. Log into Canvas **in a browser**. The Canvas app doesn't have this screen.
   On your phone that means tapping **aA** in Safari's address bar and choosing
   **Request Desktop Website**.
2. Go to **Calendar**. In the right-hand sidebar, tap **Calendar Feed**.
3. Copy the URL that appears. It looks like
   `https://YOURSCHOOL.instructure.com/feeds/calendars/user_XXXXXXXX.ics`
4. On your iPhone: **Settings → Calendar → Accounts → Add Account → Other →
   Add Subscribed Calendar**. Paste the URL and tap **Next**, then **Save**.
5. Name it `Canvas` when prompted. Remember this name — layer 3 looks for it.

To make it refresh often enough to be useful:
**Settings → Calendar → Accounts → Fetch New Data** → turn **Fetch** on and set
the interval to every 15 or 30 minutes.

> Only assignments your teachers gave a **due date** appear in this feed.
> That's the gap layer 2 exists to fill.

---

## Layer 2 — The "Homework Check" shortcut

The core of the system. Once a day it shows you a checklist of your classes;
you tap whichever ones have homework and it creates the reminders.

### Build it

Open **Shortcuts → + (new shortcut)**, name it `Homework Check`, and add these
actions in order. Search for each action by name in the search bar.

**1. `Text`**

Type your class names, one per line. Replace these with your own:

```
Algebra 2
Chemistry
US History
English
Spanish
```

**2. `Split Text`**

- Input: the `Text` from step 1
- Separator: **New Lines**

**3. `Date`**

Tap the date field and type `today at 7:00 pm`. Shortcuts understands plain
language here. This is when your homework reminders will go off — change the
time to whatever actually fits your evening.

**4. `Choose from List`**

- Input: `Split Text`
- Tap the arrow to expand options
- **Select Multiple**: ON
- **Prompt**: `Homework today?`

**5. `If`**

- Input: `Chosen Items`
- Condition: **has any value**

This is what makes "no homework today" a silent no-op instead of an error.

**6. `Repeat with Each`** — place this *inside* the If block

- Input: `Chosen Items`

**7. `Add New Reminder`** — inside the Repeat block

- Title: `Repeat Item` followed by the word ` homework`
  (so it reads `Chemistry homework`)
- List: `School`
- Tap the alert row, turn on **Remind me on a day**, and set the date field to
  the `Date` variable from step 3

**8. `Show Notification`** — inside the If, after the Repeat block ends

- Text: `Homework added to your School list`

### Schedule it

**Shortcuts → Automation tab → + → Time of Day**

- Time: `3:30 PM` (or whenever you're reliably done with class)
- Repeat: **Weekly**, with **Mon–Fri** selected
- Next → choose `Homework Check`
- Set it to **Run Immediately**

Because this shortcut has to show you something, iOS will post a notification
you tap to open it. That tap is unavoidable for any interactive automation.

### Also run it on demand

Homework gets announced at random times, so give yourself faster ways in:

- **Back Tap** — Settings → Accessibility → Touch → Back Tap → Double Tap →
  scroll to the Shortcuts section → `Homework Check`.
  Double-tap the back of your phone walking out of class.
- **Siri** — say "Hey Siri, Homework Check". Works because the shortcut's name
  is the phrase.
- **Lock Screen or Home Screen widget** — long-press → add a Shortcuts widget →
  point it at `Homework Check`.

---

## Layer 3 — The "Canvas Sync" shortcut

Turns the calendar events from layer 1 into checkable reminders in the same
`School` list, so everything lives in one place. This one is fully automatic —
you never see it run.

### Build it

New shortcut, named `Canvas Sync`:

**1. `Find Calendar Events`**

- Filter: **Calendar** `is` `Canvas`
- Add a second filter: **Start Date** `is within` `the next` `7` `days`
- Sort by: **Start Date**

**2. `Repeat with Each`**

- Input: `Calendar Events`

Everything below goes inside the Repeat block.

**3. `Get Details of Calendar Events`**

- Detail: **Title**
- Input: `Repeat Item`

**4. `Find Reminders`**

- Filter: **List** `is` `School`
- Add a second filter: **Name** `is` the `Title` variable from step 3

**5. `Count`**

- Input: `Reminders` (the result of step 4)

**6. `If`**

- Input: `Count`
- Condition: **is** `0`

Steps 7 and 8 go inside this If block. This is the duplicate check — if a
reminder with that exact name already exists, nothing happens.

**7. `Get Details of Calendar Events`**

- Detail: **Start Date**
- Input: `Repeat Item`

**8. `Add New Reminder`**

- Title: the `Title` variable from step 3
- List: `School`
- Notes: `From Canvas`
- Alert: **Remind me on a day**, set to the `Start Date` variable from step 7

### Schedule it

**Automation tab → + → Time of Day**

- Time: `7:00 AM`
- Repeat: **Daily**
- Choose `Canvas Sync`, set to **Run Immediately**
- Turn **Notify When Run** off — this one has nothing to show you

Morning timing means the day's Canvas work is already sitting in Reminders
before you leave the house.

---

## Using it day to day

- **Morning**: Canvas assignments appear in your `School` list on their own.
- **After school**: a notification asks what has homework. Tap it, tap your
  classes, done.
- **Any time**: double-tap the back of your phone to log something you just
  found out about.
- **Evening**: Reminders alerts you at your chosen time for everything due.

Everything ends up in one list you can check off. Nothing needs a computer.

---

## Troubleshooting

**Reminders reappear after I check them off.**
Layer 3's duplicate check looks for a reminder by name. Depending on your iOS
version, completed reminders may not be found, so the item gets re-added while
it's still inside the 7-day window. Fix it by narrowing step 1's window from
`7 days` to `3 days`, which shortens how long an item can come back.

**Canvas assignments show up late.**
iOS refreshes subscribed calendars on its own schedule. Set
**Settings → Calendar → Accounts → Fetch New Data → Fetch** to every 15 minutes.

**The automation didn't run.**
Check that **Run Immediately** is on — automations default to asking first.
Low Power Mode can also delay a scheduled automation by several minutes.

**A class is missing from the checklist.**
Open `Homework Check` and edit the `Text` action in step 1. That one list is the
only thing you ever need to change between semesters.

**Nothing at all comes from Canvas.**
Confirm the subscribed calendar is named exactly `Canvas`, and that it's checked
as visible in the Calendar app. Assignments with no due date never appear in the
feed at all.

---

## Appendix — the Canvas API version

Only worth building if you specifically want assignments you've already
submitted to be excluded automatically. The calendar feed doesn't carry
submission status; the API does.

Get a token: Canvas (in a browser) → **Account → Settings → Approved
Integrations → + New Access Token**. Copy it immediately, it's shown once. If
that button isn't there, your school has disabled student tokens and this
appendix isn't available to you.

Replace steps 1–3 of `Canvas Sync` with:

**1. `Format Date`** — Date: `Current Date`, Format: **Custom**, `yyyy-MM-dd`

**2. `Text`**

```
https://YOURSCHOOL.instructure.com/api/v1/planner/items?start_date=FORMATTED_DATE&per_page=50
```

with the `Formatted Date` variable dropped in place of `FORMATTED_DATE`.

**3. `Get Contents of URL`**

- Method: **GET**
- Headers: `Authorization` → `Bearer YOUR_TOKEN_HERE`

Then repeat over the returned list, reading `plannable` → `title` and
`plannable` → `due_at` with `Get Dictionary Value`, and skipping any item whose
`submissions` → `submitted` is `true`.

Treat the token like your Canvas password. Keep it inside the shortcut, never
share the shortcut with it embedded, and delete it from that same Approved
Integrations page if it ever leaks.
