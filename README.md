# WowLingo

A World of Warcraft addon that helps players learn languages through interactive vocabulary quizzes displayed in-game.

**Note:** This addon was vibe coded - built quickly with AI assistance to get a working prototype. It works, but the code could benefit from cleanup, better error handling, and more rigorous testing. See the [Contributing](#contributing) section if you'd like to help improve it.

## Features

- Interactive multiple-choice vocabulary quizzes
- Japanese JLPT N5 vocabulary (684 words)
- Track progress separately for kana and kanji
- Bi-directional questions (Japanese → English or English → Japanese)
- Searchable vocabulary browser
- Draggable, position-saving UI
- Classic Era compatible (Vanilla WoW 1.12.x API)

## Installation

1. Download or clone this repository
2. Copy the `WowLingo/` folder to your WoW addons directory:
   ```
   World of Warcraft/_classic_era_/Interface/AddOns/
   ```
3. Restart World of Warcraft or type `/reload` in-game
4. Verify the addon is enabled in the character select AddOns menu

Your folder structure should look like:
```
Interface/AddOns/WowLingo/
├── WowLingo.toc
├── Core.lua
├── Data/
├── Languages/
└── Modules/
```

## Usage

### Getting Started

1. Open the vocabulary configuration panel:
   ```
   /wl config
   ```
2. Check the boxes next to words you want to learn:
   - Left checkbox = Kana (hiragana reading)
   - Right checkbox = Kanji (if available)
3. Start quizzing:
   ```
   /wl
   ```
4. Click the correct answer from 4 options
5. Green = correct, Red = incorrect
6. Quiz auto-advances after each answer

### Commands

| Command | Description |
|---------|-------------|
| `/wl` or `/wowlingo` | Toggle the quiz window |
| `/wl config` | Open vocabulary configuration panel |
| `/wl reset confirm` | Reset all progress (cannot be undone) |
| `/wl help` | Show available commands |

### Configuration Options

In the config panel (`/wl config`):

- **Search box** - Filter vocabulary by kana, kanji, or meaning
- **Direction toggle** - Cycle between:
  - `Both` - Random mix of JP→EN and EN→JP questions
  - `JP → EN` - See Japanese, answer with English meaning
  - `EN → JP` - See English, answer with Japanese
- **All Kana ✓** - Mark all kana as known
- **All Kanji ✓** - Mark all kanji as known
- **Reset All** - Clear all progress

## File Structure

```
WowLingo/
├── WowLingo.toc              # Addon metadata
├── Core.lua                  # Initialization, events, slash commands
├── Data/
│   └── Japanese/
│       └── N5.lua            # JLPT N5 vocabulary (684 words)
├── Languages/
│   └── Japanese.lua          # Japanese language adapter
├── Modules/
│   ├── Config.lua            # Settings & SavedVariables
│   ├── ConfigUI.lua          # Vocabulary browser UI
│   ├── QuestionGenerator.lua # Quiz logic
│   └── UI.lua                # Quiz frame UI
└── tools/
    └── convert_csv.py        # CSV to Lua converter
```

## Contributing

All contributions are appreciated! This project welcomes help in several areas:

### Priority Areas

1. **More Languages & Vocabulary**
   - Add new language modules (Spanish, German, Korean, etc.)
   - Add more JLPT levels (N4, N3, N2, N1)
   - Improve or expand existing vocabulary data

2. **De-vibe-codifying**
   - Add proper error handling throughout
   - Write documentation and code comments
   - Add input validation
   - Improve code organization and naming
   - Add unit tests (if feasible for WoW addons)
   - Fix edge cases and potential bugs
   - Performance optimizations

3. **Features**
   - Spaced repetition system (SRS)
   - Progress statistics and tracking
   - Import/export word lists
   - More question types
   - Audio support (if possible)

### Adding a New Language

1. Create a language adapter in `Languages/YourLanguage.lua`:
   ```lua
   WowLingo.Languages["YourLanguage"] = {
       name = "YourLanguage",
       datasets = {"Beginner", "Intermediate"},
       getDisplayForms = function(self, entry) ... end,
       formatPrompt = function(self, entry, direction, displayType) ... end,
       formatAnswer = function(self, entry, direction, displayType) ... end,
   }
   ```

2. Create vocabulary data in `Data/YourLanguage/Dataset.lua`:
   ```lua
   WowLingo.Data["YourLanguage"]["Dataset"] = {
       [1] = { word = "hello", meaning = "a greeting" },
       ...
   }
   ```

3. Update `WowLingo.toc` to include your new files

### Vocabulary Data Source

Japanese N5 vocabulary sourced from [coolmule0/JLPT-N5-N1-Japanese-Vocabulary-Anki](https://github.com/coolmule0/JLPT-N5-N1-Japanese-Vocabulary-Anki) - thank you for making this data available!

## License

This project is open source. Vocabulary data is subject to its original license (see source repository).

## Troubleshooting

**Quiz won't open / "No known words" message**
- Open `/wl config` and check some words first

**Japanese characters not displaying**
- WoW has built-in CJK font support; ensure your client language supports it

**Settings not saving**
- Make sure you exit the game cleanly (don't force-quit)
- Check that SavedVariables folder is writable

**Addon not appearing in AddOns list**
- Verify folder structure matches installation instructions
- Check that `WowLingo.toc` is in the `WowLingo/` folder (not nested deeper)
