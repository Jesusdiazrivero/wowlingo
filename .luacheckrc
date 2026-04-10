-- WoW Addon luacheck configuration
-- Interface: 20505 (TBC Classic)

std = "lua51"
max_line_length = false

-- WoW addon globals
globals = {
    "WowLingo",
    "WowLingoSavedVars",
    "SLASH_WOWLINGO1",
    "SLASH_WOWLINGO2",
    "SlashCmdList",
}

read_globals = {
    "UIParent",
    "DEFAULT_CHAT_FRAME",
    "CreateFrame",
    "CreateFont",
    "PlaySound",
    "SOUNDKIT",
    "FauxScrollFrame_GetOffset",
    "FauxScrollFrame_OnVerticalScroll",
    "FauxScrollFrame_Update",
    "GameTooltip",
}

-- Suppress unused self in WoW callback patterns (e.g., SetScript("OnClick", function(self) ... end))
-- 212 = unused argument, 432 = shadowing upvalue argument
ignore = {
    "212/self",
    "432/self",
}

-- Language adapters implement an interface — unused args are expected
files["Languages/*.lua"] = {
    ignore = { "212" },  -- unused argument
}

-- Generated data files — only check for overwrites (which indicate real CSV bugs)
files["Languages/Data/**/*.lua"] = {
    ignore = { "212" },
}

-- Exclude dev tools from linting
exclude_files = {
    "tools/",
}
