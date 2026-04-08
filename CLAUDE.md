# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

WowLingo is a World of Warcraft TBC Classic addon (Interface 20505) that helps players learn languages through interactive vocabulary quizzes. Written in Lua with a Python data conversion tool.

## Commands

### Data Generation
Convert CSV vocabulary to Lua data files:
```bash
python3 tools/convert_csv.py input.csv output.lua [language] [dataset]
```

Example:
```bash
python3 tools/convert_csv.py tools/n5.csv Languages/Data/Japanese/Modules/N5.lua Japanese N5
```

CSV format: `jmdict_seq,kana,kanji,waller_definition`

### Installation/Testing
Copy this repository to `World of Warcraft/_classic_/Interface/AddOns/WowLingo/` and test in-game using `/wl`, `/wl config`, or `/wl help`.

## Architecture

```
./
├── WowLingo.toc          # Addon manifest (SavedVariables: WowLingoSavedVars)
├── Core.lua              # Entry point: event handlers, slash commands, FontManager, dynamic discovery
├── Fonts/
│   └── NotoSansJP-Regular.ttf  # Bundled Japanese font (Noto Sans JP, OFL license)
├── Modules/
│   ├── Config.lua        # SavedVariables management, progress tracking, module management
│   ├── QuestionGenerator.lua  # Quiz logic, Fisher-Yates shuffle, distractor generation
│   ├── UI.lua            # Main quiz frame (BackdropTemplate for TBC Classic)
│   └── ConfigUI.lua      # Settings panel, word status management, dynamic UI
├── Languages/
│   ├── Japanese.lua      # Language adapter (self-registering)
│   └── Data/
│       └── Japanese/
│           └── Modules/
│               └── N5.lua  # Auto-generated vocabulary (self-registering)
└── tools/                # Development utilities (not loaded by WoW)
    ├── convert_csv.py    # CSV to Lua vocabulary converter
    └── *.csv             # Source vocabulary data
```

### Key Patterns

**Self-Registering Architecture**: Languages and datasets automatically register themselves when loaded. No hardcoded references needed - just add files to the TOC.

**Namespace pattern**: All modules attach to `WowLingo` global namespace initialized in Core.lua.

**FontManager**: Lazy-loads fonts based on language adapter's `fontPath` property. Falls back to default WoW font if not specified.

**Dynamic Discovery**:
- `WowLingo:GetAvailableDatasets(langName)` - Auto-discovers datasets from `WowLingo.Data[langName]`
- `WowLingo:GetFirstAvailableLanguage()` - Gets first registered language
- `WowLingo:GetFirstAvailableDataset(langName)` - Gets first available dataset for a language

**Language adapter interface** (Languages/*.lua must implement):
```lua
WowLingo.Languages["LanguageName"] = {
    name = "LanguageName",
    displayName = "Human Readable (Native)",

    -- Optional: custom font path (defaults to game font if nil)
    fontPath = "Interface\\AddOns\\WowLingo\\Fonts\\CustomFont.ttf",

    -- Required: display types for this language
    displayTypes = {"type1", "type2"},
    displayTypeLabels = {
        type1 = "Type 1 Label",
        type2 = "Type 2 Label",
    },

    -- Required methods
    getDisplayTypes = function(self) return self.displayTypes end,
    getDisplayTypeLabel = function(self, displayType) return self.displayTypeLabels[displayType] or displayType end,
    getDisplayValue = function(self, entry, displayType) return entry[displayType] end,
    hasDisplayType = function(self, entry, displayType) return entry[displayType] and entry[displayType] ~= "" end,
    formatPrompt = function(self, entry, direction, displayType) end,
    formatAnswer = function(self, entry, direction, displayType) end,
}
```

**Data file structure** (Languages/Data/*/Modules/*.lua):
```lua
WowLingo.Data = WowLingo.Data or {}
WowLingo.Data["LanguageName"] = WowLingo.Data["LanguageName"] or {}
WowLingo.Data["LanguageName"]["DatasetName"] = {
    [id] = {
        -- Fields matching language adapter's displayTypes
        type1 = "value1",
        type2 = "value2",
        meaning = "English meaning",
    },
}
```

**SavedVariables structure**:
```lua
WowLingoSavedVars = {
    activeLanguage = nil,  -- Dynamically set to first available
    activeDataset = nil,   -- Dynamically set to first available
    knownWords = { [language] = { [dataset] = { [displayType] = { [id] = true } } } },
    enabledModules = { ["Language:Dataset"] = true },
    settings = { questionDirection, onlyKnownWords, framePosition, configFramePosition }
}
```

### Adding New Content

**New vocabulary dataset** (2 steps):
1. Create data file using `convert_csv.py` - it self-registers to `WowLingo.Data[lang][dataset]`
2. Add file to `WowLingo.toc`

That's it! The UI will auto-discover the new dataset.

**New language** (3 steps):
1. Create `Languages/NewLanguage.lua` implementing the adapter interface (self-registers to `WowLingo.Languages`)
2. Create vocabulary data files in `Languages/Data/NewLanguage/Modules/`
3. Add all files to `WowLingo.toc`

**Separate language addon** (optional):
Languages can be distributed as separate addons:
```
WowLingo-Spanish/
├── WowLingo-Spanish.toc  # Dependencies: WowLingo
├── Languages/
│   └── Spanish.lua
└── Languages/Data/Spanish/Modules/
    └── A1.lua
```

The TOC declares `## Dependencies: WowLingo` and the files self-register into the main WowLingo namespace.
