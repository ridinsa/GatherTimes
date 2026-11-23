-- PanelState.lua : shared state and constants for the Panel files (ns.panel, written as P).
-- Panel.lua's window was split into these files; every file reads and writes shared values through P.
local _, ns = ...
ns.panel = ns.panel or {}
local P = ns.panel

P.PAD, P.HEAD_H, P.FOOT_H, P.GROUP_GAP, P.HEADER_H, P.SUB_H = 12, 60, 28, 7, 18, 30
P.TOOL_FULL = 24   -- height of the tab row (0 while it is hidden, see ToolH): Inv / Bank / Mail / Guild. Everything else lives in the Opt menu and the search box
P.MIN_COLS, P.MAX_COLS = 8, 15
P.TOOL_GAP = 4   -- space between the top toolbar buttons
function P.ToolH() return ns.Opt("toolbar") and P.TOOL_FULL or 0 end

P.headers, P.headerRules, P.slotButtons, P.tabButtons = {}, {}, {}, {}
P.headerButtons = {}           -- clickable strips over the category headers (fold / unfold)
P.shown = {}             -- { bag, slot, button, info, liveSlot } currently placed
P.liveParents = {}
P.query = ""

P.manualOrder = {}

P.layoutNote, P.layoutCount = "never ran", 0     -- what the last drawing pass did (for /gtbag draw)
P.slotManageMode = false
P.showHiddenSlots = false   -- right-click the eye button: temporarily show the items in hidden slots (dimmed); right-click again to hide them
P.pinMode = false           -- "Pin items": a +/* control on every item toggles its pin (see Pins.lua)

