#!/usr/bin/env python3
"""Validates DivineAtlas/Resources/SeedData/*.json against docs/schema/*.schema.json.

Development-only tool for content editors. The app's own SeedDataValidator
(run by the unit tests) remains the authoritative check, including referential
integrity that JSON Schema cannot express. Requires the `jsonschema` package:

    python3 -m venv .venv && .venv/bin/pip install jsonschema
    .venv/bin/python scripts/validate_seed_schema.py
"""
import json
import pathlib
import sys

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCHEMA_DIR = ROOT / "docs" / "schema"
DATA_DIR = ROOT / "DivineAtlas" / "Resources" / "SeedData"


def main() -> int:
    schemas = {path.name: json.loads(path.read_text()) for path in SCHEMA_DIR.glob("*.schema.json")}
    registry = Registry().with_resources((name, Resource.from_contents(s)) for name, s in schemas.items())

    failed = False
    for name in ["sources", "religions", "entities"]:
        validator = Draft202012Validator(schemas[f"{name}.schema.json"], registry=registry)
        errors = list(validator.iter_errors(json.loads((DATA_DIR / f"{name}.json").read_text())))
        print(f"{name}.json:", "OK" if not errors else f"{len(errors)} error(s)")
        for error in errors[:20]:
            print("   at", "/".join(str(p) for p in error.path), "-", error.message[:200])
        failed = failed or bool(errors)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
