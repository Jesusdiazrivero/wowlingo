#!/usr/bin/env python3
"""
Convert JLPT vocabulary CSV to WoW Lua table format.
Usage: python convert_csv.py input.csv output.lua
"""

import csv
import sys
import os

def escape_lua_string(s):
    """Escape special characters for Lua string literals."""
    if s is None:
        return None
    # Escape backslashes first, then quotes
    s = s.replace('\\', '\\\\')
    s = s.replace('"', '\\"')
    s = s.replace('\n', '\\n')
    s = s.replace('\r', '')
    return s

def convert_csv_to_lua(input_path, output_path, language="Japanese", dataset="N5"):
    """Convert CSV vocabulary file to Lua table format."""

    entries = []

    with open(input_path, 'r', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)

        for row in reader:
            # Extract fields - handle different possible column names
            jmdict_seq = row.get('jmdict_seq', row.get('id', ''))
            kana = row.get('kana', row.get('reading', ''))
            kanji = row.get('kanji', row.get('expression', ''))
            meaning = row.get('waller_definition', row.get('meaning', row.get('definition', '')))

            # Skip entries without required fields
            if not jmdict_seq or not kana or not meaning:
                continue

            # Clean up meaning - take first definition if multiple
            meaning = meaning.strip()
            if meaning.startswith('['):
                # Remove brackets if present
                meaning = meaning.strip('[]')

            # Handle empty kanji
            if not kanji or kanji.strip() == '' or kanji == kana:
                kanji = None

            entries.append({
                'id': jmdict_seq.strip(),
                'kana': kana.strip(),
                'kanji': kanji.strip() if kanji else None,
                'meaning': meaning
            })

    # Write Lua output
    with open(output_path, 'w', encoding='utf-8') as luafile:
        luafile.write(f'''--[[
    WowLingo - {language} {dataset} Vocabulary Data
    Auto-generated from JLPT vocabulary CSV
    Total entries: {len(entries)}
]]

-- Initialize data structure
WowLingo = WowLingo or {{}}
WowLingo.Data = WowLingo.Data or {{}}
WowLingo.Data["{language}"] = WowLingo.Data["{language}"] or {{}}

-- {dataset} Vocabulary
WowLingo.Data["{language}"]["{dataset}"] = {{
''')

        for entry in entries:
            kanji_str = f'"{escape_lua_string(entry["kanji"])}"' if entry['kanji'] else 'nil'
            luafile.write(f'''    [{entry['id']}] = {{
        kana = "{escape_lua_string(entry['kana'])}",
        kanji = {kanji_str},
        meaning = "{escape_lua_string(entry['meaning'])}",
    }},
''')

        luafile.write('}\n')

    print(f"Converted {len(entries)} entries to {output_path}")
    return len(entries)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python convert_csv.py input.csv output.lua [language] [dataset]")
        print("Example: python convert_csv.py jlpt_n5.csv N5.lua Japanese N5")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]
    language = sys.argv[3] if len(sys.argv) > 3 else "Japanese"
    dataset = sys.argv[4] if len(sys.argv) > 4 else "N5"

    if not os.path.exists(input_file):
        print(f"Error: Input file '{input_file}' not found")
        sys.exit(1)

    convert_csv_to_lua(input_file, output_file, language, dataset)
