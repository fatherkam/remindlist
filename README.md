# remindlist

**Create Apple Reminders lists from the command line** — the verb every CLI reminders tool is missing.

![platform](https://img.shields.io/badge/platform-macOS%2014%2B-black)
![swift](https://img.shields.io/badge/swift-5.9%2B-orange)
![license](https://img.shields.io/badge/license-MIT-blue)
![deps](https://img.shields.io/badge/dependencies-zero-success)

`remindlist` is a single-file Swift CLI (no Package.swift, no SPM, no dependencies) that does two things well:

- **create** a Reminders list, with an optional color
- **list** your existing lists

```console
$ remindlist "Groceries" --color green
Created list "Groceries" [iCloud]

$ remindlist list
Groceries	[iCloud]
Home	  	[iCloud]
Work		[iCloud]
```

## Why this exists

macOS has plenty of ways to *edit* reminders from the CLI — `remindctl`, AppleScript, Shortcuts. It has almost no way to **create a list**:

- CLI reminder tools can complete, reschedule, and edit reminders, but none ship a create-list command.
- `remindctl add -l "New List"` fails with `List not found` — no auto-create.
- AppleScript to Reminders fails with `err -609 (Connection is invalid)` when driven from headless or automation contexts (SSH, CI, background agents).
- The Shortcuts route can't be scripted reliably either.

The fix is a tiny EventKit CLI: `EKEventStore().requestFullAccessToReminders` → `EKCalendar(for: .reminder, eventStore:)` → `saveCalendar(commit: true)`. It works interactively, and — the reason this repo exists — it also works from **background/automation sessions** that already hold Reminders access, where AppleScript consistently fails.

## Install

```console
$ git clone https://github.com/fatherkam/remindlist.git
$ cd remindlist
$ make install          # builds with swiftc and installs to /usr/local/bin
```

Manual build if you prefer:

```console
$ swiftc remindlist.swift -o remindlist -O
$ ./remindlist --help
```

## Usage

```text
USAGE
  remindlist <name> [--color <color>]   Create a list
  remindlist list                       List existing lists
  remindlist --help                     Show this help

COLORS
  blue, green, orange, pink, purple, red, teal, yellow
```

Refuses to create a duplicate list name (case-insensitive). Non-zero exit codes on every failure, so it composes cleanly in scripts:

```console
$ remindlist "Q1 OKRs" && echo ready
```

## Headless / automation note

If you run CLI automations (launchd, SSH, agent frameworks) that already have Reminders permission granted to the parent context, `remindlist` will create lists without surfacing a dialog — which is precisely the gap that AppleScript cannot fill. On a fresh machine, the first interactive run triggers the standard permission prompt once.

Pair it with any reminders editor (e.g. [`remindctl`](https://formulae.brew.sh/formula/remindctl)) to create a list and populate it, all from the shell.

## Requirements

- macOS 14.0+ (`requestFullAccessToReminders`)
- Swift 5.9+ toolchain (Xcode command line tools)

## License

[MIT](LICENSE) © Kam Ahmed
