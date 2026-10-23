# Testing plan

Work in two passes: automation first, so machine-checkable things never reach a play-test, then a
structured play-test of what only a person can judge (feel, fun, pacing, clarity).

## 1. Automated checks (run before every play-test and every commit)

| Check | Command | Catches |
| --- | --- | --- |
| Compile + logic tests | `./test.sh` (repo root) | Script errors, broken rules: grading, economy, walk-in generation, storylets, cat moods, race physics, glyph coverage, data references |
| Race balance | `godot --headless --script res://tools/race_report.gd` | Rivals too fast or slow, AI hitting walls |
| Screen sweep | Screenshot commands in `CLAUDE.md` with each fixture, at `1280x720` and phone `1170x540 --phone` | Layout overflow, missing art, text off screen |
| Web boot | Headless Chrome command in `CLAUDE.md` against the live URL | Export problems, console errors |

What the tests already guarantee: every shown character has a glyph on the web; every generated job
is winnable; flipping a junker only pays if you fix it; storylet, drawer and dialogue references
point at real scenes, items and parts; empty boost can't be held on; doll layers exist for every look.

### Still to automate (next steps)

1. **Autoplay soak test.** A headless script that plays 30 seeded days through `GameState`
   (take a board job, mark repairs done with random scores, grade, pay, sleep, buy and sell at the
   market, flip a junker) and asserts no errors, pebs stay sane, and every screen script loads.
2. **Screen sweep script.** One command that renders every screen and fixture at both sizes into a
   folder for a quick visual scan.
3. **CI.** Run `./test.sh` in the deploy workflow so a failing test blocks a deploy.

## 2. Play-test checklist (you)

Play on desktop first, then a phone. For each item note: works / confusing / not fun / bug.

**Days 1 to 3 (the authored start)**
- [ ] New game form, pronouns, intro, meeting Grommet
- [ ] Odessa's job: scan, weld and calibrate, parts, paint, handoff, payment
- [ ] Brindle's job: the two-step wiring repair, washing with the drone, tuning
- [ ] Crake's job: haggling, the three-step coupling, the breach, pearl finish, mischief
- [ ] Club race: steering, drift, boost (and that it stops when empty), pause, quit

**Day 4 onward (the evergreen game)**
- [ ] Job board: are walk-ins varied, readable, fairly priced?
- [ ] A walk-in job end to end, including a storylet's three beats over two days
- [ ] A regular returning
- [ ] Grommet: a helpful day, a mischief day, petting, sharing cake
- [ ] Market news and drifting prices; restoring a worn part
- [ ] A hawker's cart; a mystery crate (with and without Diagnostics 2)
- [ ] Salvage yard: buy a junker, fix it, sell it; race a fixed project
- [ ] Halloran's drawers as skills grow; the "For later" letter on day 7

**Phone-specific**
- [ ] Button pill tucks away and comes back; full screen (Android) or home-screen tip (iPhone)
- [ ] Text size, minigames by finger, race touch pads with two fingers
- [ ] Keyboard on the name form leaves no offset

**Feel and pacing (the important part)**
- [ ] Is each day the right length? Does spark run out too soon or never?
- [ ] Is money too tight or too loose by day 7? Are walk-in budgets sensible?
- [ ] Which minigames are fun, which are chores?
- [ ] Any moment you didn't know what to do next?

File findings as a list; I'll turn them into fixes and new automated checks where possible.

## 3. Launch prep (not done yet; you asked to stop short)

Custom domain (`CNAME`, DNS at the registrar), the `REGISTRY_UPDATE_TOKEN` secret, then the
register workflow. Do these after the play-test pass.
