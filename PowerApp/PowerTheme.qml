pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.PowerApp

// The power menu's colors, read from a JSON file of Material color roles — the
// format matugen writes with templates/colors.json:
//
//   { "background": "#1a1110", "primary": "#ffb4a5", ... }
//
// The file is theme.colorsFile in the power menu's config.json, by default
//
//   ~/.config/ml4w-powermenu/colors.json
//
// which ML4W's matugen config generates (see the ml4w_powermenu rule in
// matugen/config.toml). Pointing it elsewhere lets any other generator (pywal,
// wallust, a hand-written file) theme the power menu, as long as it uses the
// same key names.
//
// This is the power menu's own copy of the shared CustomTheme, so it does not
// depend on the rest of the shell. The file is watched: the power menu recolors
// as soon as matugen rewrites it, without a reload call. Keys missing from the
// file, or a missing file, keep the built-in colors below.
Singleton {
    id: root

    // Built-in colors, used until (and unless) the colors file provides them.
    // Only the roles the power menu draws with are listed; other keys in the
    // file are ignored.
    readonly property var defaultColors: ({
        "background": "#0e1514",
        "on_primary": "#003734",
        "primary": "#81d5cd",
        "shadow": "#000000"
    })

    property color background: defaultColors.background
    property color on_primary: defaultColors.on_primary
    property color primary: defaultColors.primary
    property color shadow: defaultColors.shadow

    // theme.colorsFile with a leading "~" or "$HOME" expanded — FileView takes
    // a plain path. Empty (nothing loaded) until the power menu's config.json
    // has been read, so a custom path is never preceded by a load of the default.
    readonly property string defaultColorsFile: Quickshell.env("HOME")
        + "/.config/ml4w-powermenu/colors.json"
    readonly property string colorsFile: {
        if (!PowerSettings.ready)
            return ""
        const raw = `${PowerSettings.settings.theme.colorsFile ?? ""}`.trim()
        if (raw === "")
            return root.defaultColorsFile
        return raw.replace(/^(~|\$HOME)(?=\/|$)/, Quickshell.env("HOME"))
    }

    // Apply the file's colors over the built-in ones. Every role is reset
    // first, so a key removed from the file falls back instead of keeping the
    // previous theme's value.
    function applyColors(text): void {
        let parsed = ({})
        if (text && text.trim() !== "") {
            try {
                parsed = JSON.parse(text)
            } catch (e) {
                console.warn("power menu theme: could not parse "
                    + root.colorsFile + ", using the built-in colors:", e)
            }
        }
        for (let key in root.defaultColors)
            root[key] = (typeof parsed[key] === "string" && parsed[key] !== "")
                ? parsed[key] : root.defaultColors[key]
    }

    // Re-read the colors file. It is watched, so this is only needed when the
    // file did not exist yet when the power menu started (a watch cannot
    // follow a file that is created later). Part of the reload IPC.
    function reload(): void {
        colorsView.reload()
    }

    // Guards the one-time seeding below.
    property bool seeded: false

    FileView {
        id: colorsView
        path: root.colorsFile
        watchChanges: true
        printErrors: false
        onFileChanged: colorsView.reload()
        onLoaded: root.applyColors(colorsView.text())
        onLoadFailed: {
            root.applyColors("")
            // The default file does not exist before the next matugen run. On
            // ML4W, start from the shell's current colors instead of the
            // built-in ones, so the power menu matches the theme right away.
            if (!root.seeded && root.colorsFile === root.defaultColorsFile) {
                root.seeded = true
                Qt.callLater(function() { seedProc.running = true })
            }
        }
    }

    // Copies ML4W's generated colors into the power menu's default colors file
    // when that is missing. Does nothing without ML4W; the built-in colors stay.
    Process {
        id: seedProc
        command: ["bash", "-c",
            'f="$HOME/.config/ml4w-powermenu/colors.json";'
            + ' o="$HOME/.config/ml4w/colors/colors.json";'
            + ' [ -f "$f" ] && exit 0;'
            + ' [ -f "$o" ] || exit 1;'
            + ' mkdir -p "$(dirname "$f")" && cp "$o" "$f"']
        onExited: (code) => { if (code === 0) colorsView.reload() }
    }
}
