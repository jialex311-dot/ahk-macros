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

**This step uses two apps.** You get a link in Safari, then paste it into the
Calendar app. Neither step happens in the Canvas app — it doesn't have this
screen at all.

### Part 1 — Get the link (Safari)

1. Open **Safari** and go to your Canvas site. Log in.
2. Tap **aA** on the left side of the address bar and choose
   **Request Desktop Website**. The page shrinks and looks like a computer
   screen. This matters — the button in step 4 doesn't exist on the mobile
   layout.
3. In the narrow vertical menu on the far left (Account, Dashboard, Courses,
   Calendar, Inbox), tap **Calendar**.
4. Look at the **right-hand column** and scroll it all the way to the bottom —
   past the small month grid, past the list of your course names. The last
   thing in that column is a button labelled **Calendar Feed**.
5. Tap it. A box appears containing a long link starting `https://` and ending
   in `.ics`
6. Press and hold the link and choose **Copy**.

The link is personal to you and doesn't expire. It's the only thing you need
out of Canvas for this entire system.

### Part 2 — Add it (Calendar app)

1. Open the built-in **Calendar** app — the white icon showing today's date.
2. Tap **Calendars** at the bottom center of the screen.
3. Scroll to the bottom of that list and tap **Add Calendar**, then
   **Add Subscription Calendar**.
4. Paste your link into the URL box and tap **Subscribe**.
5. A Name field appears with something ugly pre-filled. Delete it, type
   `Canvas`, and tap **Add**.

> If **Add Subscription Calendar** isn't in that menu, your iOS version puts it
> somewhere else instead:
> **Settings → Calendar → Accounts → Add Account → Other → Add Subscribed Calendar**.
> Same result.

Name it exactly `Canvas` — capital C, nothing after it. Layer 3's first action
searches for a calendar by that literal name, so `canvas` or `Canvas Calendar`
will silently match nothing.

### Part 3 — Make it refresh often

**Settings → Calendar → Accounts → Fetch New Data** → turn **Fetch** on and set
the interval to every 15 or 30 minutes. Without this, iOS updates subscribed
calendars on its own lazy schedule and new assignments can take hours to show up.

> Only assignments your teachers gave a **due date** appear in this feed.
> That's the gap layer 2 exists to fill.

---

## Layer 2 — The "Homework Check" shortcut

The core of the system. Once a day it shows you a checklist of your classes;
you tap whichever ones have homework and it creates the reminders.

### Build it

Open **Shortcuts → + (new shortcut)**, name it `Homework Check`, and add these
actions in order. Search for each action by name in the search bar.

**1. `List` — your classes**

Add a `List` action. Tap **Add new item** and type a class name, then tap it
again for the next one, until all your classes are there:

```
Algebra 2
Chemistry
US History
English
Spanish
```

Each class is its own row you can see and edit. Adding a class next semester is
one tap on **Add new item**.

> An older version of this guide used a `Text` action holding one class per
> line, followed by `Split Text` with the separator set to **New Lines**. That
> works too — `Text` produces one blob of text, and `Split Text` cuts it at each
> line break into separate items. The `List` action is just already a list, so
> it saves an action and a concept. If you use the `Text` route, make sure the
> separator says **New Lines** and not **Spaces**, or `US History` becomes two
> classes.

**2. `Date`**

Tap the date field and type `today at 7:00 pm`. Shortcuts understands plain
language here. This is when your homework reminders will go off — change the
time to whatever actually fits your evening.

**3. `Choose from List`**

- Input: `List`
- Tap the arrow to expand options
- **Select Multiple**: ON
- **Prompt**: `Homework today?`

**4. `Repeat with Each`**

- Input: `Chosen Items`

It appears as a pair — `Repeat with Each` on top, `End Repeat` below, with a gap
between them.

**5. `Add New Reminder`** — inside the Repeat block

Newly added actions usually land *below* `End Repeat`, which is wrong. Press and
hold it and drag it up into the gap so it sits between the two and looks
indented.

- Title: tap the field, tap `Repeat Item` from the variable bar above the
  keyboard, then type a space and the word `homework` — so it reads
  `Repeat Item homework` and produces *Chemistry homework* at run time
- List: `School`
- Tap the action's ⌄ arrow to expand it, turn on **Remind me on a day**, and set
  the date field to the `Date` variable from step 2

> An earlier version of this guide wrapped these two actions in an `If` checking
> that `Chosen Items` **has any value**, followed by a `Show Notification`. Both
> were dropped. `Repeat with Each` over an empty selection already runs zero
> times and ends silently, so the `If` bought nothing but a second level of
> drag-and-drop nesting, which is genuinely painful to arrange on a phone.

### Test it

Tap **▶** at the bottom. Pick two classes, tap Done, then open Reminders — both
should be sitting in `School` with an alert set for your chosen time.

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
- Add a second filter: **Start Date** `is in the next` `7` `days`

**2. `Repeat with Each`**

- Input: `Calendar Events`

Everything below goes inside this block. Newly added actions land at the bottom
of the shortcut, so you'll drag each one up into place. A shortcut: add all the
actions first, then drag `End Repeat` down to the very bottom — one drag puts
everything inside the loop at once.

**3. `Get Details of Calendar Events`**

- Detail: **Title**
- Input: `Repeat Item`

If the input auto-fills as `Repeat Results`, change it — that's the collected
output of the whole finished loop, not the event you're currently on. `Repeat
Item` only appears as an option once the action is inside the loop, so move it
first and set the variable second.

**4. `Find Reminders`**

- Filter: **List** `is` `School`
- Filter: **Name** `is` the `Title` variable from action 3

**5. `Count`**

- Input: `Reminders`

**6. `If`** — the duplicate check

- Input: `Count`, condition **is** `0`

Action 7 goes inside this block. Leave the `Otherwise` branch empty — "a reminder
already exists, do nothing" is the correct behavior.

**7. `Add New Reminder`** — inside the If

- Title: the `Title` variable from action 3
- List: `School`
- Alert: **No Alert**

> **Why no alert.** Setting the alert from the event's own date does not work:
> Shortcuts rejects it with *"The alert time provided was invalid"* even when the
> date passed in is valid and in the future (confirmed with a `Quick Look` — a
> real date went in and was still refused). Neither `Adjust Date` nor rebuilding
> the date through `Format Date` fixes it.
>
> Nothing is actually lost. Layer 1 already puts every Canvas due date in the
> **Calendar** app, so Calendar answers *when* and this list answers *what*.
> Reminders you log yourself through layer 2 keep their 7:00 PM alert, since that
> path sets the alert from a `Date` action and works fine.

### Test it

Tap **▶** and check Reminders. Your Canvas assignments should be in `School`.

Then **run it a second time**. The count must not double — that's the duplicate
check in action 6 doing its job. If items do duplicate, the `Name` filter in
action 4 isn't matching the `Title` variable.

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
Open `Homework Check` and tap **Add new item** on the `List` action in step 1. That one list is the
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
