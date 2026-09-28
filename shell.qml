//@ pragma UseQApplication

import Quickshell
import qs.PowerApp

// Entry point of the ML4W Power Menu. Start it with:
//
//   qs -p ~/.local/share/ml4w-powermenu
//
// and control it over IPC (qs ipc show lists the functions):
//
//   qs -p ~/.local/share/ml4w-powermenu ipc call power toggle
ShellRoot {
    PowerWindow {}
}
