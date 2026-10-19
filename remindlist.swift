// remindlist — create and list Apple Reminders lists from the command line.
//
// Built with EventKit because CLI reminder tools (e.g. remindctl) can read and
// edit reminders but cannot create *lists*, and the AppleScript route fails in
// headless/automation contexts (err -609). A small EventKit CLI works, including
// from background/automation sessions that already hold Reminders access.
//
// Requires macOS 14+ (requestFullAccessToReminders).

import Foundation
import AppKit
import EventKit

let version = "1.0.0"

let colorMap: [String: NSColor] = [
    "red":    NSColor(srgbRed: 0.94, green: 0.26, blue: 0.26, alpha: 1),
    "orange": NSColor(srgbRed: 0.98, green: 0.55, blue: 0.10, alpha: 1),
    "yellow": NSColor(srgbRed: 0.95, green: 0.78, blue: 0.15, alpha: 1),
    "green":  NSColor(srgbRed: 0.24, green: 0.69, blue: 0.31, alpha: 1),
    "teal":   NSColor(srgbRed: 0.13, green: 0.65, blue: 0.62, alpha: 1),
    "blue":   NSColor(srgbRed: 0.22, green: 0.45, blue: 0.92, alpha: 1),
    "purple": NSColor(srgbRed: 0.60, green: 0.36, blue: 0.90, alpha: 1),
    "pink":   NSColor(srgbRed: 0.92, green: 0.38, blue: 0.63, alpha: 1),
]

func help() -> Never {
    print("""
    remindlist \(version) — manage Apple Reminders lists

    USAGE
      remindlist <name> [--color <color>]   Create a list
      remindlist list                       List existing lists
      remindlist --help                     Show this help

    COLORS
      \(colorMap.keys.sorted().joined(separator: ", "))

    NOTES
      The first run triggers a macOS permission prompt for Reminders access
      (System Settings > Privacy & Security > Reminders). Subsequent runs,
      including from scripts and automation sessions, reuse that grant.
    """)
    exit(0)
}

// ---- argument parsing --------------------------------------------------------

let args = Array(CommandLine.arguments.dropFirst())
var colorName: String?
var positional: [String] = []
var i = 0
while i < args.count {
    switch args[i] {
    case "--help", "-h":
        help()
    case "--color", "-c":
        guard i + 1 < args.count else {
            fputs("remindlist: --color needs a value\n", stderr); exit(2)
        }
        colorName = args[i + 1]
        i += 2
    default:
        positional.append(args[i])
        i += 1
    }
}

guard let command = positional.first else { help() }

// ---- EventKit access ----------------------------------------------------------

let store = EKEventStore()
let semaphore = DispatchSemaphore(value: 0)
var accessDenied = false

store.requestFullAccessToReminders { granted, error in
    if !granted {
        accessDenied = true
        if let error {
            fputs("remindlist: Reminders access error — \(error.localizedDescription)\n", stderr)
        }
    }
    semaphore.signal()
}

if semaphore.wait(timeout: .now() + 30) == .timedOut {
    fputs("remindlist: timed out waiting for Reminders access (a permission dialog may be pending)\n", stderr)
    exit(1)
}
if accessDenied {
    fputs("remindlist: Reminders access denied. Grant it in System Settings > Privacy & Security > Reminders.\n", stderr)
    exit(1)
}

// ---- pick a source -------------------------------------------------------------
// calDAV covers iCloud; fall back to a local source. Subscribed calendars are
// .subscribed (not a writable home for new reminder lists), so skip them.

let source = store.sources.first { $0.sourceType == .calDAV }
    ?? store.sources.first { $0.sourceType == .local }

guard let source else {
    fputs("remindlist: no calDAV or local source available for Reminders\n", stderr)
    exit(1)
}

// ---- commands -------------------------------------------------------------------

if command == "list" || command == "--list" || command == "-l" {
    let lists = store.calendars(for: .reminder)
        .sorted { $0.title.lowercased() < $1.title.lowercased() }
    if lists.isEmpty {
        print("No Reminders lists found.")
        exit(0)
    }
    for list in lists {
        print("\(list.title)\t[\(list.source.title)]")
    }
    exit(0)
}

// create mode: everything left is the list name
let name = positional.joined(separator: " ")
guard !name.hasPrefix("-") else {
    fputs("remindlist: unknown command '\(command)' — try --help\n", stderr)
    exit(2)
}

if store.calendars(for: .reminder)
    .contains(where: { $0.title.caseInsensitiveCompare(name) == .orderedSame }) {
    fputs("remindlist: a list named \"\(name)\" already exists\n", stderr)
    exit(1)
}

// EKCalendar(for:eventStore:) is non-optional — no guard-let needed here.
let list = EKCalendar(for: .reminder, eventStore: store)
list.title = name
list.source = source

if let colorName {
    guard let color = colorMap[colorName.lowercased()] else {
        fputs("remindlist: unknown color '\(colorName)' — choose from: \(colorMap.keys.sorted().joined(separator: ", "))\n", stderr)
        exit(2)
    }
    list.color = color
}

do {
    try store.saveCalendar(list, commit: true)
    print("Created list \"\(name)\" [\(source.title)]")
} catch {
    fputs("remindlist: could not save list — \(error.localizedDescription)\n", stderr)
    exit(1)
}
