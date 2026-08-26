# Ajouter des tâches depuis un LLM

Quartz fournit une commande locale indépendante du modèle. Tout agent capable d’exécuter une commande sur ce Mac — ChatGPT avec accès local, Claude Code, Hermes, OpenCode ou un LLM local outillé — peut déposer une tâche sans modifier directement les données de l’application.

## Commande simple

La passerelle locale porte elle aussi le nom Quartz.

```bash
cd "/Users/thomasalloin/dev/Quartz"
./Quartz.command ajouter --titre "Préparer le rendez-vous" --date demain --heure 09:30 --rappel 15m --source claude
```

La réponse est un JSON exploitable par une machine :

```json
{"inbox":"…/Inbox/UUID.json","ok":true,"queued":true,"requestID":"UUID"}
```

La demande est importée en moins d’une seconde si Quartz est ouvert. S’il est fermé, elle reste en attente et sera importée au prochain lancement.

## Options disponibles

- `--titre` / `--title` : titre obligatoire ;
- `--date` : `aujourd’hui`, `demain` ou `AAAA-MM-JJ` ;
- `--heure` / `--time` : `HH:mm` ;
- `--recurrence` : `jamais`, `quotidien`, `ouvres`, `hebdomadaire`, `mensuel` ;
- `--rappel` / `--reminder` : `aucun`, `heure`, `5m`, `15m`, `30m`, `1h` ;
- `--notes` : texte libre ;
- `--sous-tache` / `--subtask` : répétable, avec la forme `Titre :: Description` ;
- `--source` : nom facultatif de l’agent ;
- `--id` : UUID stable facultatif pour rendre une reprise idempotente.

Un rappel nécessite une heure. Les entrées invalides sont refusées avant d’atteindre l’application.


## Entrée JSON pour les agents

```bash
cd "/Users/thomasalloin/dev/Quartz"
printf '%s' '{
  "title": "Préparer la présentation",
  "date": "2026-08-18",
  "time": "14:00",
  "recurrence": "weekly",
  "reminder": "30m",
  "notes": "Réunion avec l’équipe",
  "subtasks": [
    {"title": "Relire les chiffres"},
    {"title": "Exporter le PDF", "description": "Version finale sans annotations"}
  ],
  "source": "opencode"
}' | ./Quartz.command ajouter --json
```

Le schéma formel se trouve dans [`Integrations/quartz-task.schema.json`](Integrations/quartz-task.schema.json).

## Instruction à donner à un agent

> Lorsque je demande d’ajouter une tâche à Quartz, utilise la commande `/Users/thomasalloin/dev/Quartz/Quartz.command ajouter`. Demande confirmation uniquement si la date ou le titre est réellement ambigu. Utilise `--id` avec un UUID stable si tu dois réessayer la même demande.

La passerelle reste entièrement locale : aucun serveur réseau et aucun compte externe ne sont requis. Un ChatGPT ou un autre assistant sans accès aux commandes locales de ce Mac ne peut pas l’appeler directement ; il faut alors lui fournir un outil local ou un connecteur qui exécute cette commande.
