"""Check both gettext catalogs against the keys used in Godot resources."""
from collections import Counter
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
KEY = re.compile(r'"(LOC_[A-Z0-9_]+)"')
FIELD = re.compile(r"\{[a-z_]+\}|%s")
PO_LINE = re.compile(r'^(msgid(?:_plural)?|msgstr(?:\[\d+\])?)\s+(".*")$')
SOURCES = {"Scripts": "*.gd", "Scenes": "*.tscn", "Trinkets": "*.tres"}


def read_catalog(path, plural_forms):
    entries = {}
    for block in re.split(r"\n\s*\n", path.read_text(encoding="utf-8").strip()):
        values = {}
        field = None
        for line in block.splitlines():
            if not line or line.startswith("#"):
                continue
            if match := PO_LINE.fullmatch(line):
                field = match[1]
                values[field] = json.loads(match[2])
            elif line.startswith('"') and field:
                values[field] += json.loads(line)
            else:
                raise ValueError(f"{path.name}: invalid line {line!r}")
        if not (key := values.get("msgid", "")):
            continue
        if key in entries:
            raise ValueError(f"{path.name}: duplicate key {key}")
        if plural := values.get("msgid_plural"):
            forms = [values.get(f"msgstr[{i}]", "") for i in range(plural_forms)]
            if any(not value or FIELD.findall(value) != ["%s"] for value in forms):
                raise ValueError(f"{path.name}: missing plural form or count in {key}")
            entries[plural] = forms[0]
            entries[key] = forms[0]
        else:
            if not values.get("msgstr", "").strip():
                raise ValueError(f"{path.name}: empty translation for {key}")
            entries[key] = values["msgstr"]
    return entries


def check():
    used = set()
    for directory, pattern in SOURCES.items():
        for path in (ROOT / directory).glob(pattern):
            if not path.name.endswith("Verification.gd"):
                used.update(KEY.findall(path.read_text(encoding="utf-8")))
    pl = read_catalog(ROOT / "Locale/pl.po", 3)
    en = read_catalog(ROOT / "Locale/en.po", 2)
    errors = []
    for code, catalog in (("pl", pl), ("en", en)):
        errors.extend(f"{code}: missing {key}" for key in sorted(used - catalog.keys()))
        errors.extend(f"{code}: unused {key}" for key in sorted(catalog.keys() - used))
    for key in sorted(pl.keys() & en.keys()):
        if Counter(FIELD.findall(pl[key])) != Counter(FIELD.findall(en[key])):
            errors.append(f"Different placeholders for {key}")
    if errors:
        raise ValueError("\n".join(errors))
    print(f"Localization: {len(used)} keys, PL / EN, no missing translations.", flush=True)


if __name__ == "__main__":
    check()
