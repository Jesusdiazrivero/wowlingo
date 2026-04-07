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
├── Core.lua              # Entry point: event handlers, slash commands, namespace init
├── Fonts/
│   └── NotoSansJP-Regular.ttf  # Bundled Japanese font (Noto Sans JP, OFL license)
├── Modules/
│   ├── Config.lua        # SavedVariables management, progress tracking, settings
│   ├── QuestionGenerator.lua  # Quiz logic, Fisher-Yates shuffle, distractor generation
│   ├── UI.lua            # Main quiz frame (BackdropTemplate for TBC Classic)
│   └── ConfigUI.lua      # Settings panel, word status management
├── Languages/
│   ├── Japanese.lua      # Language adapter: display types (kana/kanji), formatting
│   └── Data/
│       └── Japanese/
│           └── Modules/
│               └── N5.lua  # Auto-generated vocabulary (684 entries)
└── tools/                # Development utilities (not loaded by WoW)
    ├── convert_csv.py    # CSV to Lua vocabulary converter
    └── *.csv             # Source vocabulary data
```

### Key Patterns

**Namespace pattern**: All modules attach to `WowLingo` global namespace initialized in Core.lua.

**Language adapter interface** (Languages/*.lua must implement):
- `GetDisplayTypes()` - Returns available display modes (e.g., kana, kanji)
- `GetDatasets()` - Returns available vocabulary sets (e.g., N5, N4)
- `FormatQuestion(entry, displayType, direction)` - Formats question prompt
- `GetAnswerOptions(entry, displayType, direction)` - Returns correct answer and distractors

**SavedVariables structure**:
```lua
WowLingoSavedVars = {
    activeLanguage = "Japanese",
    activeDataset = "N5",
    knownWords = { [language] = { [dataset] = { [displayType] = { [id] = true } } } },
    settings = { questionDirection, onlyKnownWords, framePosition, configFramePosition }
}
```

### Adding New Content

**New vocabulary dataset**:
1. Create CSV with required columns
2. Run `convert_csv.py` to generate Lua file
3. Add file to `WowLingo.toc`
4. Register dataset in the language adapter's `GetDatasets()`

**New language**:
1. Create `Languages/NewLanguage.lua` implementing the adapter interface
2. Create `Languages/Data/NewLanguage/Modules/` directory with vocabulary files
3. Initialize language in `Core.lua` (add to `InitializeLanguages`)
