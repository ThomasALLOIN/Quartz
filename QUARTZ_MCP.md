# Connecter Quartz à Codex ou Claude

Quartz inclut un serveur MCP local en `stdio`. Il ne contacte aucun service en ligne, ne requiert aucune clé et n’écrit jamais directement dans `tasks.json` ou `post-its.json`.

Les deux outils proposés sont :

- `quartz_create_task` : crée une tâche de calendrier, avec date, heure, rappel, récurrence, notes et sous-tâches facultatifs ;
- `quartz_create_note` : crée un post-it jaune `persistent` ou vert `daily`.

Les appels sont mis en attente dans `~/Library/Application Support/Quartz/Inbox` ou `PostItInbox`, puis Quartz les importe de façon atomique. L’application peut donc être fermée au moment de l’appel.

## Installer un chemin stable

Ne référencez pas `dev/Quartz` ou `dist/Quartz.app` dans la configuration de vos assistants : ces chemins peuvent changer. Depuis le projet Quartz, lancez une fois :

```bash
./InstallerMCP.command
```

Cette commande compile le serveur et l’installe ici :

```text
~/Library/Application Support/Quartz/Helpers/quartz-mcp
```

Relancez-la après une mise à jour du serveur MCP. Le projet peut ensuite être déplacé ou le bundle supprimé : Codex et Claude continuent d’utiliser la copie installée.

## Codex

Ajoutez ce bloc dans `~/.codex/config.toml`, puis redémarrez Codex :

```toml
[mcp_servers.quartz]
command = "/Users/thomasalloin/Library/Application Support/Quartz/Helpers/quartz-mcp"
```

## Claude Desktop

Ajoutez ce serveur dans la section `mcpServers` du fichier de configuration de Claude Desktop, puis redémarrez Claude :

```json
{
  "mcpServers": {
    "quartz": {
      "command": "/Users/thomasalloin/Library/Application Support/Quartz/Helpers/quartz-mcp"
    }
  }
}
```

Les clients MCP affichent normalement l’appel avant l’exécution. Vérifiez toujours le titre, la date et le type de post-it proposé avant de l’autoriser.

## Pendant le développement

La copie stable est celle à employer pour Codex et Claude. La sortie standard du serveur appartient exclusivement au protocole MCP ; les diagnostics éventuels ne doivent jamais être écrits sur cette sortie.
