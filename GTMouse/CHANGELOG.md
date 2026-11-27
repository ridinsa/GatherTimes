# GTMouse

## 0.26.0 (2026-11-27)

- New: standalone mouse-look addon with one key binding (toggle), `/gtmouse` and `/gtm` commands, and an options window with a header, On/Off state and sections for General, Mouse-look, Cursor and Key binding.
- New: options for the cursor trail and cursor spot: colour pickers and opacity sliders (10-100%), and spot size (tiny to large).
- New: a white circle with a crosshair marks where the cursor will return when mouse-look ends.
- New: on-screen notice panel for mouse-look on and off, with the state coloured and a fade-out.
- New: red player arrow on FarmHud, and on the GatherTimes HUD.
- New: without a HUD, an animated ring like the cursor trail marks the centre of the screen (the character) for as long as mouse-look is on. Uses the cursor trail colour and opacity; on or off in Options > AddOns.
- New: optional turn-on when mounted.
- New: the Options > AddOns page holds the sensitivity slider and the general options.
- New: option "Right-click turns mouse-look back on" (off by default): when the game ends mouse-look because of a right-click, the next right-click turns it back on.
- Change: the mouse-look notice reads "Mouse-look ON" / "OFF".
- Change: the master switch is labelled "Enable GTMouse"; it is off by default and remembered across reload and login.
- Fix: the toggle key follows GTMouse's own mouse-look state.
- Fix: clearer `/gtm status` and help text.
- Fix: the red arrow no longer conflicts with GatherTimes' HUD arrow; the stock arrow is restored when mouse-look ends.
