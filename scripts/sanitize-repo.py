#!/usr/bin/env python3

from pathlib import Path
import re

repo_root = Path(__file__).resolve().parent.parent
config_root = repo_root / "system-config"

real_home = str(Path.home())
replacements = {
    real_home: "__HOME__",
    "Versailles": "__WEATHER_LOCATION__",
    "iPhone": "__DEVICE_NAME__",
}

changed_files = []

for path in config_root.rglob("*"):
    if not path.is_file():
        continue

    try:
        original = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

    sanitized = original

    for private_value, placeholder in replacements.items():
        sanitized = sanitized.replace(private_value, placeholder)

    # Autres chemins /home/utilisateur éventuellement présents.
    sanitized = re.sub(
        r"/home/[A-Za-z0-9._-]+",
        "__HOME__",
        sanitized,
    )

    if sanitized != original:
        path.write_text(sanitized, encoding="utf-8")
        changed_files.append(path.relative_to(repo_root))

print("Fichiers anonymisés :")

for path in changed_files:
    print(f"  - {path}")

if not changed_files:
    print("  aucun changement nécessaire")
