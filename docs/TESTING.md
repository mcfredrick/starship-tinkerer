# Testing plan

Work in two passes: automation first, so machine-checkable problems never reach a play-test, then a
structured play-test of what only a person can judge (feel, fun, pacing, clarity).

## 1. Automated checks

| Check | How | When |
| --- | --- | --- |
| Everything below except the sweep | `./test.sh` (repo root) | Before every commit; CI runs it before every deploy and a failure blocks the deploy |
| Compile every script | part of `test.sh` | |
| Logic tests (`tests/run_tests.gd`, every `test_` method) | part of `test.sh` | |
| Autoplay soak (`tools/soak.tscn`): three seeded 40-day runs | part of `test.sh` | |
| Race balance (`tools/race_report.gd`): every race, three Kettle builds | run by hand after touching race stats or tracks | |
| Screen sweep (`tools/sweep.sh`): every screen, desktop and phone, contact sheets | run by hand before a play-test or after UI changes (needs a display) | |
| Live web boot | headless Chrome command in `CLAUDE.md` | after a deploy |

### What the automation guarantees

- **Content can't strand the story.** Every beat, letter and dialogue branch waits on a flag the game
  can actually set; every beat, job, storylet, event, race, drawer and gift points at real scenes,
  tracks, parts and items.
- **The web build can draw every character** shown anywhere (data, dialogue, script strings).
- **Every authored job is winnable**: a search over market parts and tuning finds a build that meets
  all its stat, rating and gadget wants.
- **Generated work is fair.** Every walk-in job is winnable with market parts and tuning; flipping a
  junker only pays if you fix it; the yard's stock and carts are stable for their day.
- **Racing rules hold.** Empty boost can't be held on; the tow magnet pulls, the foghorn startles
  and bubbles block it; AI racers lap every track without touching a wall.
- **Long play is stable.** Over 40 days and three seeds: pebs never go negative, stacks never go
  empty or negative, spark and Sprocket's affection stay in range, every save loads back unchanged,
  and bought cart offers stay sold after a reload (a real bug the soak test found).

### What it can't judge (that's the play-test)

Feel of minigames and racing, whether text is clear, pacing, difficulty, fun, and how things look in
motion. The bot also skips minigames, so it never earns skill XP the way you will.

## 2. Things to look at first

The soak test's economy summary says walk-in jobs pay about 460 to 500 pebs each, and a bot that never
buys parts ends day 40 with over 20,000 pebs. A real player spends some of that on parts, but money
likely stops mattering by midgame. Please note how it feels by day 7 and day 14; budgets are one line
in `scripts/core/walkins.gd` to tune.

## 3. Play-test checklist

Play on desktop first, then a phone. For each item note: works / confusing / not fun / bug.

**Days 1 to 3 (the authored start)**
- [ ] New game form, pronouns, intro, meeting Sprocket
- [ ] Odessa's job: scan, weld and calibrate, parts, paint, handoff, payment
- [ ] Brindle's job: the two-step wiring repair, washing with the drone, tuning
- [ ] Crake's job: haggling, the three-step coupling, the breach, pearl finish, mischief
- [ ] Club race: steering, drift, boost (and that it stops when empty), pause, quit

**Days 4 to 15 (arcs and events)**
- [ ] Ilse's tenth of a second; Odessa's roots-or-roam choice; Brindle's Garden Dash prep; Crake's mother
- [ ] The cups on their days (3 Night Run, 5 Garden Dash, 7 Slow Sunday) and the rating caps
- [ ] Tow magnet and foghorn in a race
- [ ] The Close Pass on day 11: does it land emotionally? Do your earlier choices show?
- [ ] The novel chapters, Themba's letter, and the Lumen Reach lighthouse on day 15
- [ ] Your past: the bag choice in the intro, a letter on day 2, Halloran's "Why you" on day 6, a visitor from your past on day 9, and Halloran coming home on day 21 (try each of the three bags)
- [ ] Dock gossip and the Who's who page; the pets in their owners' scenes
- [ ] From day 12: Pip (two jobs, then the Night Run), the Okafors (restaurant or cart), Dr. Yaneva (the ember fern)

**The evergreen game**
- [ ] Job board: varied, readable, fairly priced walk-ins? A storylet's three beats over two days?
- [ ] A regular returning; Sprocket's helpful and mischief days, petting, sharing cake
- [ ] Market news and drifting prices; restoring a worn part; a hawker's cart and a mystery crate
- [ ] Salvage yard: buy a junker, fix it, sell it; race a fixed project
- [ ] Halloran's drawers as skills grow; the "For later" letter on day 7; your finds on the tablet

**Phone-specific**
- [ ] Button pill tucks away and comes back; full screen (Android) or home-screen tip (iPhone)
- [ ] Text size, minigames by finger, race touch pads with two fingers, frame rate on the space tracks
- [ ] Keyboard on the name form leaves no offset

**Feel and pacing (the important part)**
- [ ] Is each day the right length? Does spark run out too soon or never?
- [ ] Money by day 7 and 14 (see section 2)
- [ ] Which minigames are fun, which are chores?
- [ ] Any moment you didn't know what to do next?

Send findings as a list. Each becomes a fix and, wherever a machine could have caught it, a new
automated check.

## 4. Pre-release content review

Before launch, review every piece of content once, with the screen sweep's contact sheets and the
tablet open. For each, check it reads well, looks right, and isn't too close to anything else.

- **Characters and pets**: Odessa, Ilse, Brindle, Crake, Pip, Tam, Juniper, Dr. Yaneva, Halloran,
  Captain Rook, Professor Ashgrove, Nan Tallow, Sprocket, the three hawkers; Biscuit, Hob, Lord
  Pemberton, Flutter, Chili, Gerald. Every portrait expression, every voice consistent.
- **Places and scenes**: the hangar, tea nook, market, yard, drawers, job board, three race tracks,
  the Moon-plum Harvest, the Close Pass, Lumen Reach, and the four field-guide plates.
- **Ships**: all nine hulls and every named ship, at each livery.
- **Writing**: every dialogue file, letter, storylet and gossip line, read through once for tone,
  typos, pronoun tokens and the house style.
- **Originality**: names and premises searched against existing works. Known and handled: the cat
  is Sprocket (shares a name with Fraggle Rock's dog; accepted), Brindle's motif reworked away from
  Monk and Robot's Mosscap, and the peb credited to Monk and Robot on the Credits page. Still to note:
  Crake (also a character in *Oryx and Crake*) and Halloran (*The Shining*) are common names, kept.

## 5. Launch (after the play-test)

Point `starship-tinkerer.crap.games` at the game (CNAME and DNS), set the `REGISTRY_UPDATE_TOKEN`
secret, then run the register workflow.
