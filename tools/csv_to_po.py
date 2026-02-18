#!/usr/bin/env python3
"""
CSV to PO File Converter
Converts translations.csv to separate .po files for each language.

Usage:
    python3 csv_to_po.py
"""

import csv
import os
from pathlib import Path

# Configuration
CSV_FILE = "data/translations/translations.csv"
OUTPUT_DIR = "data/translations"
LANGUAGES = {
    "en": "English",
    "es": "Spanish",
    "pt": "Portuguese",
    "fr": "French"
}

def create_po_header(language_name, language_code):
    """Create PO file header."""
    return f'''# Translation file for Match-3 Game
# Language: {language_name} ({language_code})
# 
msgid ""
msgstr ""
"Language: {language_code}\\n"
"Content-Type: text/plain; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"

'''

def convert_csv_to_po():
    """Convert CSV to separate PO files."""
    print(f"📖 Reading CSV: {CSV_FILE}")

    # Read CSV
    with open(CSV_FILE, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    print(f"✅ Loaded {len(rows)} translation keys")

    # Create PO files for each language
    for lang_code, lang_name in LANGUAGES.items():
        po_file = os.path.join(OUTPUT_DIR, f"strings_{lang_code}.po")

        print(f"\n🌍 Creating {lang_name} ({lang_code})...")
        print(f"   File: {po_file}")

        with open(po_file, 'w', encoding='utf-8') as f:
            # Write header
            f.write(create_po_header(lang_name, lang_code))

            # Write translations
            for row in rows:
                key = row['keys']
                value = row.get(lang_code, '')

                if not value:
                    print(f"   ⚠️  Missing translation for: {key}")
                    value = row.get('en', key)  # Fallback to English

                # Write PO entry
                f.write(f'msgid "{key}"\n')
                f.write(f'msgstr "{value}"\n')
                f.write('\n')

        print(f"   ✅ Wrote {len(rows)} translations")

    print(f"\n🎉 Migration complete!")
    print(f"\n📝 Next steps:")
    print(f"   1. Open Godot Editor")
    print(f"   2. Check data/translations/ folder")
    print(f"   3. Godot will auto-import .po files → .translation")
    print(f"   4. Test with: TranslationServer.set_locale('es')")
    print(f"\n💡 Tip: You can now delete translations.csv")

if __name__ == "__main__":
    convert_csv_to_po()
