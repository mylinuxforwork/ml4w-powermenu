pragma Singleton

import Quickshell
import Quickshell.Io

// The power menu's settings file and its parsed contents.
Singleton {
    id: root

    // One settings file, the usual place for a Linux app's own config:
    //
    //   ~/.config/ml4w-powermenu/config.json
    //
    // It is created (empty) on first start if it does not exist yet, and is
    // merged over the built-in defaults, so a partial or entirely empty file
    // still leaves every value defined — the user only writes down what they
    // want to change. The file is watched, so edits apply as soon as it is
    // saved. PowerApp/config.json documents these defaults and must be kept in
    // sync with them.
    readonly property var defaultSettings: ({
        "powermenu": { "order": ["lock", "suspend", "logout", "reboot", "poweroff"],
                       "marginRight": 0,
                       "editorCommand": "~/.config/ml4w/settings/editor.sh" },
        "commands":  { "lock":     "~/.config/ml4w/scripts/ml4w-power -l",
                       "suspend":  "~/.config/ml4w/scripts/ml4w-power -s",
                       "logout":   "~/.config/ml4w/scripts/ml4w-power -e",
                       "reboot":   "~/.config/ml4w/scripts/ml4w-power -r",
                       "poweroff": "~/.config/ml4w/scripts/ml4w-power -p" },
        "button":    { "size": 50, "iconSize": 22, "spacing": 20, "borderWidth": 1 },
        "pill":      { "radius": 40, "paddingX": 15, "paddingY": 20,
                       "animationDuration": 350 },
        "border":    { "width": 2, "colorTop": "", "colorBottom": "" },
        "opacity":   { "normal": 0.9 },
        "theme":     { "colorsFile": "~/.config/ml4w-powermenu/colors.json" }
    })

    // The buttons the menu knows, with the icon each one shows. The order in
    // which they appear, and which of them appear at all, is powermenu.order.
    readonly property var buttonIcons: ({
        "lock": "icons/lock.svg",
        "suspend": "icons/suspend.svg",
        "logout": "icons/logout.svg",
        "reboot": "icons/reboot.svg",
        "poweroff": "icons/power.svg"
    })

    property var settings: defaultSettings

    // powermenu.order with unknown ids dropped, so the window can build its
    // buttons and keyboard navigation from it without further checks.
    readonly property var buttons: {
        let order = settings.powermenu.order
        if (!Array.isArray(order))
            return []
        return order.filter(function(id) {
            if (root.buttonIcons[id] !== undefined)
                return true
            console.warn("power menu settings: unknown button \"" + id
                + "\" in powermenu.order, skipping it")
            return false
        })
    }

    // The settings file has reported back (loaded, or missing and created), so
    // `settings` holds the values from disk rather than the built-in defaults.
    property bool ready: false

    // Guards the create pass below so a file that cannot be written (read-only
    // home, no permissions) does not retry on every reload.
    property bool seeded: false

    FileView {
        id: settingsFile
        path: Quickshell.env("HOME") + "/.config/ml4w-powermenu/config.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: settingsFile.reload()
        onLoaded: { root.applySettings(); root.ready = true }
        onLoadFailed: {
            // First miss: create the file, then come back through reload().
            // Qt.callLater because this can fire while the component is still
            // being built, before seedProc exists.
            if (!root.seeded) {
                root.seeded = true
                Qt.callLater(function() { seedProc.running = true })
                return
            }
            root.applySettings()
            root.ready = true
        }
    }

    // Creates ~/.config/ml4w-powermenu/config.json when it is missing —
    // FileView only writes files, it does not create the directory holding them.
    Process {
        id: seedProc
        command: ["bash", "-c",
            'd="$HOME/.config/ml4w-powermenu"; f="$d/config.json";'
            + ' mkdir -p "$d" || exit 1;'
            + ' [ -f "$f" ] && exit 0;'
            + ' printf "{\\n}\\n" > "$f"']
        onExited: settingsFile.reload()
    }

    function reloadSettings(): void {
        settingsFile.reload()
        console.log("Power menu reload: re-reading power menu settings")
        applySettings()
    }

    // Parse a settings document that may carry a /* ... */ comment block and —
    // being hand-edited — trailing commas, which strict JSON.parse rejects.
    // Returns undefined when the text is empty or unparseable. Never throws.
    function parseSettings(src) {
        if (!src)
            return undefined
        let raw = src.replace(/\/\*[\s\S]*?\*\//g, "")
        if (raw.trim() === "")
            return undefined
        try {
            return JSON.parse(raw)
        } catch (e) {
            try {
                return JSON.parse(raw.replace(/,(\s*[}\]])/g, "$1"))
            } catch (e2) {
                console.warn("power menu settings: could not parse the settings"
                    + " file, ignoring it:", e2)
                return undefined
            }
        }
    }

    // Merge one settings document (as text) over an already-built settings
    // object, key by key. Empty or unparseable text is ignored so a
    // missing/partial file never clears previously merged values.
    function mergeSettings(merged, src): void {
        let parsed = parseSettings(src)
        if (parsed === undefined)
            return
        for (let group in parsed)
            for (let key in parsed[group])
                if (merged[group] !== undefined)
                    merged[group][key] = parsed[group][key]
    }

    // Rebuild the settings object: built-in defaults with the settings file
    // merged on top, so a file that only carries the keys the user changed
    // keeps the defaults for everything else.
    function applySettings(): void {
        let merged = JSON.parse(JSON.stringify(root.defaultSettings))
        mergeSettings(merged, settingsFile.text())
        root.settings = merged
    }

    // Run the command configured for a button (commands.<id>) through bash, so
    // a leading ~, arguments and pipes all work.
    function runCommand(id): void {
        let cmd = root.settings.commands[id]
        if (typeof cmd !== "string" || cmd.trim() === "") {
            console.warn("power menu: no command configured for \"" + id + "\"")
            return
        }
        Quickshell.execDetached(["bash", "-c", cmd])
    }

    // Open the settings file in powermenu.editorCommand, which gets the file
    // path as its last argument. An empty command, or one whose program is not
    // found (e.g. the ML4W editor script when the menu runs on its own), falls
    // back to xdg-open — the default application for JSON files. The command
    // is passed as an argument rather than spliced into the script, so quotes
    // in it cannot break the fallback logic.
    function editConfig(): void {
        Quickshell.execDetached(["bash", "-c",
            'f="$HOME/.config/ml4w-powermenu/config.json"; c="${1/#\\~/$HOME}";'
            + ' if [ -n "$c" ] && command -v "${c%% *}" >/dev/null 2>&1;'
            + ' then eval "$c \\"\\$f\\""; else exec xdg-open "$f"; fi',
            "powermenu-edit", root.settings.powermenu.editorCommand || ""])
    }
}
