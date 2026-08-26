#!/usr/bin/env python3

"""Évalue le modèle MLX de Quartz sur des formulations françaises réalistes."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


ENDPOINT = "http://127.0.0.1:8080/v1/chat/completions"
MODEL = "default_model"
EXPECTED_KEYS = {"title", "date", "time", "recurrence", "reminder", "notes", "subtasks"}
RECURRENCES = {"none", "daily", "weekdays", "weekly", "monthly"}
REMINDERS = {"none", "at-time", "5m", "15m", "30m", "1h"}
SYSTEM_PROMPT = (
    "Tu convertis une demande française en une seule tâche Écrin. "
    "Réponds uniquement avec un objet JSON valide, sans markdown ni explication. "
    "Utilise exactement les clés title, date, time, recurrence, reminder, notes et subtasks. "
    "date vaut null, aujourd'hui, demain ou AAAA-MM-JJ. "
    "time vaut null ou HH:mm. "
    "recurrence vaut none, daily, weekdays, weekly ou monthly. "
    "Chaque jour ou tous les jours impose recurrence daily et doit être retiré du title. "
    "Toute heure écrite, par exemple à 19h, impose time 19:00 et doit être retirée du title. "
    "Une date française explicite doit être convertie sans rester dans title. "
    "reminder vaut none, at-time, 5m, 15m, 30m ou 1h. "
    "Une demande de rappel explicite doit remplir reminder et être retirée du title. "
    "La demande contient toujours une seule tâche. "
    "subtasks est une liste d'objets avec title et éventuellement description."
)


def arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--minimum-exact", type=float, default=0.70)
    parser.add_argument("--timeout", type=float, default=30)
    return parser.parse_args()


def ask(prompt: str, timeout: float) -> str:
    body = json.dumps(
        {
            "model": MODEL,
            "temperature": 0,
            "max_tokens": 256,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": prompt},
            ],
        }
    ).encode("utf-8")
    request = urllib.request.Request(
        ENDPOINT,
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.load(response)
    return payload["choices"][0]["message"]["content"]


def valid_schema(value: Any) -> bool:
    if not isinstance(value, dict) or set(value) != EXPECTED_KEYS:
        return False
    if not isinstance(value["title"], str) or not value["title"].strip():
        return False
    if value["date"] is not None and not isinstance(value["date"], str):
        return False
    if value["time"] is not None and not isinstance(value["time"], str):
        return False
    if value["recurrence"] not in RECURRENCES or value["reminder"] not in REMINDERS:
        return False
    if not isinstance(value["notes"], str) or not isinstance(value["subtasks"], list):
        return False
    return all(
        isinstance(item, dict)
        and isinstance(item.get("title"), str)
        and set(item).issubset({"title", "description"})
        and ("description" not in item or isinstance(item["description"], str))
        for item in value["subtasks"]
    )


def canonical(value: Any) -> Any:
    """Ignore uniquement la casse, les espaces et la forme de l’apostrophe."""
    if isinstance(value, str):
        return " ".join(value.replace("’", "'").split()).casefold()
    if isinstance(value, list):
        return [canonical(item) for item in value]
    if isinstance(value, dict):
        return {key: canonical(item) for key, item in value.items()}
    return value


def main() -> int:
    options = arguments()
    root = Path(__file__).resolve().parents[1]
    test_file = root / "MLX" / "Dataset" / "realistic.jsonl"
    records = [json.loads(line) for line in test_file.read_text().splitlines() if line]

    counts = Counter()
    category_counts: dict[str, Counter[str]] = defaultdict(Counter)
    failures: list[str] = []

    for index, record in enumerate(records, start=1):
        prompt = record["prompt"]
        expected = record["expected"]
        categories = record.get("categories", ["général"])
        try:
            actual = json.loads(ask(prompt, options.timeout))
            counts["json"] += 1
            schema_ok = valid_schema(actual)
            if schema_ok:
                counts["schema"] += 1
            exact = schema_ok and canonical(actual) == canonical(expected)
            if exact:
                counts["exact"] += 1
            else:
                differing = (
                    [
                        key for key in EXPECTED_KEYS
                        if canonical(actual.get(key)) != canonical(expected.get(key))
                    ]
                    if isinstance(actual, dict) else []
                )
                if len(failures) < 8:
                    failures.append(
                        f"#{index} {prompt}\n"
                        f"  champs : {', '.join(sorted(differing)) or 'schéma invalide'}\n"
                        f"  attendu : {expected}\n"
                        f"  obtenu  : {actual}"
                    )
            for category in categories:
                category_counts[category]["total"] += 1
                category_counts[category]["exact"] += int(exact)
        except (json.JSONDecodeError, KeyError, TimeoutError, urllib.error.URLError) as error:
            for category in categories:
                category_counts[category]["total"] += 1
            if len(failures) < 8:
                failures.append(f"#{index} {prompt}\n  erreur : {error}")

        print(f"\rTest MLX réaliste : {index}/{len(records)}", end="", flush=True)

    total = len(records)
    exact_rate = counts["exact"] / total if total else 0
    print()
    print(f"JSON valides : {counts['json']}/{total} ({counts['json'] / total:.1%})")
    print(f"Schémas valides : {counts['schema']}/{total} ({counts['schema'] / total:.1%})")
    print(f"Réponses sémantiquement exactes : {counts['exact']}/{total} ({exact_rate:.1%})")
    print("Par catégorie :")
    for category, values in sorted(category_counts.items()):
        rate = values["exact"] / values["total"] if values["total"] else 0
        print(f"  {category}: {values['exact']}/{values['total']} ({rate:.1%})")
    if failures:
        print("Premiers écarts :")
        print("\n".join(failures))

    passed = (
        counts["json"] == total
        and counts["schema"] == total
        and exact_rate >= options.minimum_exact
    )
    if not passed:
        print(
            f"Échec : il faut 100 % de JSON/schémas valides et au moins "
            f"{options.minimum_exact:.0%} de réponses exactes.",
            file=sys.stderr,
        )
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
