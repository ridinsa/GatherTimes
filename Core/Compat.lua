-- Compat.lua : fills in old global functions that the newer clients (Retail, Forever) moved into C_ tables.
-- Only a function that is MISSING is added, so on Classic Era, Season of Discovery, Hardcore, TBC, Cataclysm and
-- Mists nothing changes: the client's own function is used.
local _, GT = ...

local CI = _G.C_Item
if CI then
    if not _G.GetItemCount and CI.GetItemCount then _G.GetItemCount = CI.GetItemCount end
    if not _G.GetItemInfo and CI.GetItemInfo then _G.GetItemInfo = CI.GetItemInfo end
    if not _G.GetItemInfoInstant and CI.GetItemInfoInstant then _G.GetItemInfoInstant = CI.GetItemInfoInstant end
end

-- MouseIsOver(frame) is gone on the newest clients; Frame:IsMouseOver() does the same
if not _G.MouseIsOver then
    _G.MouseIsOver = function(frame)
        return frame and frame.IsMouseOver and frame:IsMouseOver() or false
    end
end

-- client family, for the debug report and for code that must act differently per version
local id = _G.WOW_PROJECT_ID
if id and _G.WOW_PROJECT_MAINLINE and id == _G.WOW_PROJECT_MAINLINE then GT.flavor = "retail"
elseif id and _G.WOW_PROJECT_CAMELOT and id == _G.WOW_PROJECT_CAMELOT then GT.flavor = "forever"
elseif id and _G.WOW_PROJECT_CLASSIC and id == _G.WOW_PROJECT_CLASSIC then GT.flavor = "era"
elseif id and _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC and id == _G.WOW_PROJECT_BURNING_CRUSADE_CLASSIC then GT.flavor = "tbc"
elseif id and _G.WOW_PROJECT_CATACLYSM_CLASSIC and id == _G.WOW_PROJECT_CATACLYSM_CLASSIC then GT.flavor = "cata"
elseif id and _G.WOW_PROJECT_MISTS_CLASSIC and id == _G.WOW_PROJECT_MISTS_CLASSIC then GT.flavor = "mists"
else GT.flavor = "unknown" end
