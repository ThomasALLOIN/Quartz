#!/usr/bin/env python3

"""Génère un petit corpus français déterministe pour le parseur de tâches Quartz."""

from __future__ import annotations

import json
from pathlib import Path


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


TASKS = [
    ("appeler Paul", "Appeler Paul"),
    ("prendre rendez-vous chez le dentiste", "Prendre rendez-vous chez le dentiste"),
    ("envoyer le dossier à Marie", "Envoyer le dossier à Marie"),
    ("acheter du pain", "Acheter du pain"),
    ("réserver le train pour Lyon", "Réserver le train pour Lyon"),
    ("terminer la présentation", "Terminer la présentation"),
    ("arroser les plantes", "Arroser les plantes"),
    ("ranger le bureau", "Ranger le bureau"),
    ("répondre au message de Luc", "Répondre au message de Luc"),
    ("préparer le rendez-vous client", "Préparer le rendez-vous client"),
    ("faire les courses", "Faire les courses"),
    ("relire le contrat", "Relire le contrat"),
    ("mettre à jour le calendrier", "Mettre à jour le calendrier"),
    ("classer les factures", "Classer les factures"),
    ("réserver une table au restaurant", "Réserver une table au restaurant"),
    ("écrire à la mairie", "Écrire à la mairie"),
    ("préparer le sac de voyage", "Préparer le sac de voyage"),
    ("nettoyer la cuisine", "Nettoyer la cuisine"),
    ("vérifier le compte bancaire", "Vérifier le compte bancaire"),
    ("imprimer les billets", "Imprimer les billets"),
    ("renouveler l’abonnement", "Renouveler l’abonnement"),
    ("contacter le propriétaire", "Contacter le propriétaire"),
    ("sauvegarder les photos", "Sauvegarder les photos"),
    ("préparer les documents", "Préparer les documents"),
    ("confirmer l’adresse", "Confirmer l’adresse"),
    ("commander les fournitures", "Commander les fournitures"),
    ("lire le compte rendu", "Lire le compte rendu"),
    ("planifier la semaine", "Planifier la semaine"),
    ("réparer la lampe", "Réparer la lampe"),
    ("appeler le vétérinaire", "Appeler le vétérinaire"),
    ("envoyer la déclaration", "Envoyer la déclaration"),
    ("préparer le déjeuner", "Préparer le déjeuner"),
    ("récupérer le colis", "Récupérer le colis"),
    ("confirmer la réservation", "Confirmer la réservation"),
    ("noter les idées du projet", "Noter les idées du projet"),
    ("vérifier les horaires", "Vérifier les horaires"),
]


def payload(
    title: str,
    *,
    date: str | None = None,
    time: str | None = None,
    recurrence: str = "none",
    reminder: str = "none",
    notes: str = "",
    subtasks: list[dict[str, str]] | None = None,
) -> dict[str, object]:
    return {
        "title": title,
        "date": date,
        "time": time,
        "recurrence": recurrence,
        "reminder": reminder,
        "notes": notes,
        "subtasks": subtasks or [],
    }


def example(user: str, result: dict[str, object]) -> dict[str, object]:
    assistant = json.dumps(result, ensure_ascii=False, separators=(",", ":"))
    return {
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": user},
            {"role": "assistant", "content": assistant},
        ]
    }


def examples_for(raw_title: str, clean_title: str) -> list[dict[str, object]]:
    return [
        example(f"Ajoute {raw_title}", payload(clean_title)),
        example(f"Pour aujourd’hui je dois {raw_title}", payload(clean_title, date="aujourd'hui")),
        example(f"Demain, {raw_title}", payload(clean_title, date="demain")),
        example(f"Mets {raw_title} au 20 août 2026", payload(clean_title, date="2026-08-20")),
        example(f"À 9 h, {raw_title}", payload(clean_title, time="09:00")),
        example(f"Demain à 14h30, {raw_title}", payload(clean_title, date="demain", time="14:30")),
        example(
            f"Aujourd’hui à 18 h {raw_title}, rappelle-moi 5 minutes avant",
            payload(clean_title, date="aujourd'hui", time="18:00", reminder="5m"),
        ),
        example(
            f"Ajoute {raw_title} demain à 9h avec un rappel 15 min avant",
            payload(clean_title, date="demain", time="09:00", reminder="15m"),
        ),
        example(
            f"Le 20 août 2026 à 16 h, {raw_title}, rappel une demi-heure avant",
            payload(clean_title, date="2026-08-20", time="16:00", reminder="30m"),
        ),
        example(
            f"Demain à 8 h {raw_title} et préviens-moi une heure avant",
            payload(clean_title, date="demain", time="08:00", reminder="1h"),
        ),
        example(f"Tous les jours, {raw_title}", payload(clean_title, recurrence="daily")),
        example(f"Chaque jour ouvré je dois {raw_title}", payload(clean_title, recurrence="weekdays")),
        example(f"Une fois par semaine, {raw_title}", payload(clean_title, recurrence="weekly")),
        example(f"Tous les mois, {raw_title}", payload(clean_title, recurrence="monthly")),
        example(
            f"Ajoute {raw_title}, note que c’est prioritaire",
            payload(clean_title, notes="C’est prioritaire"),
        ),
        example(
            f"Demain {raw_title}, avec les étapes relire les notes puis envoyer la confirmation",
            payload(
                clean_title,
                date="demain",
                subtasks=[
                    {"title": "Relire les notes"},
                    {"title": "Envoyer la confirmation"},
                ],
            ),
        ),
        example(
            f"Crée {raw_title} avec une sous-tâche vérifier les informations, description contrôler les noms et les dates",
            payload(
                clean_title,
                subtasks=[
                    {
                        "title": "Vérifier les informations",
                        "description": "Contrôler les noms et les dates",
                    }
                ],
            ),
        ),
        example(
            f"Peux-tu me rappeler de {raw_title} aujourd’hui à 11h ?",
            payload(clean_title, date="aujourd'hui", time="11:00", reminder="at-time"),
        ),
    ]


def write_jsonl(path: Path, records: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as output:
        for record in records:
            output.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")))
            output.write("\n")


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    dataset = root / "MLX" / "Dataset"

    train_tasks = TASKS[:28]
    valid_tasks = TASKS[28:32]
    test_tasks = TASKS[32:]

    train = [item for task in train_tasks for item in examples_for(*task)]
    valid = [item for task in valid_tasks for item in examples_for(*task)]
    test = [item for task in test_tasks for item in examples_for(*task)]

    write_jsonl(dataset / "train.jsonl", train)
    write_jsonl(dataset / "valid.jsonl", valid)
    write_jsonl(dataset / "test.jsonl", test)

    print(f"Dataset Quartz généré : {len(train)} apprentissage, {len(valid)} validation, {len(test)} test")


if __name__ == "__main__":
    main()
