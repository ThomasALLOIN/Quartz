# Distribution macOS de Quartz

Le design et le parcours fonctionnel de Quartz ont été validés par l’utilisateur le 26 août 2026. La génération du `.app` est donc autorisée.

## Livraison publique notarisée

- version : `1.0.1` (`CFBundleVersion` 2) ;
- identifiant : `com.thomasalloin.Quartz` ;
- cible : macOS 14 ou ultérieur, Apple Silicon ;
- application : `dist/Quartz.app` ;
- installateur recommandé : `dist/Quartz-macOS-1.0.1.dmg` ;
- archive complémentaire : `dist/Quartz-1.0.1-macOS-Apple-Silicon.zip` ;
- signature : `Developer ID Application: Thomas ALLOIN (VH4KX3SZUY)`, avec hardened runtime et horodatage ;
- notarisation : acceptée par Apple et ticket agrafé au DMG ;
- icône : galet de lapis texturé avec les trois obélisques et la faille centrale ;
- ressources incluses : textures, relief du widget et modèle français MLX de 136 Mo ;
- intégration externe : binaires `quartz` et `quartz-mcp` inclus dans `Contents/Helpers`.

L’installateur DMG est destiné à une distribution directe : il est reconnu par Gatekeeper comme provenant d’un « Notarized Developer ID ».

## Construire l’application

Le modèle étant suivi par Git LFS, vérifier d’abord qu’il est présent, puis lancer :

```bash
git lfs pull
./Packager.command
```

`Packager.command` exécute par défaut `Verifier.command`, compile les deux exécutables en mode release, assemble le bundle et ses ressources, applique la signature, vérifie l’architecture puis crée un DMG Finder avec `Quartz.app` et le raccourci **Applications**. Il conserve également le ZIP.

Pour installer Quartz, ouvrir le DMG et glisser l’icône **Quartz** vers **Applications**. L’image disque est ensuite éjectable.

Les valeurs peuvent être adaptées sans modifier le script :

```bash
QUARTZ_VERSION=1.0.1 \
QUARTZ_BUILD_NUMBER=2 \
QUARTZ_BUNDLE_ID=com.thomasalloin.Quartz \
QUARTZ_SIGN_IDENTITY='Developer ID Application: Thomas ALLOIN (VH4KX3SZUY)' \
QUARTZ_NOTARY_PROFILE=QuartzNotary \
./Packager.command
```

`QuartzNotary` est un profil local du trousseau macOS : il référence la clé d’API Apple sans l’exposer dans le projet. Sans identité ni profil, le script conserve le mode de développement ad hoc ; il refuse en revanche une notarisation sans signature Developer ID.

## Fonctionnement du bundle

Les données restent dans `~/Library/Application Support/Quartz`. Au premier lancement du `.app`, Quartz importe les préférences du précédent exécutable `QuartzPreview` lorsque la nouvelle application n’a pas déjà une valeur équivalente.

Les notifications locales sont disponibles parce que l’application possède désormais un bundle macOS et un identifiant stable. L’autorisation est demandée uniquement lorsque l’utilisateur active **Notifications** dans les réglages.

Le modèle spécialisé est embarqué. Le moteur exécutable `mlx_lm.server` reste temporairement une dépendance installée sur le Mac ; Quartz le détecte, le lance sur `127.0.0.1`, refuse un serveur incompatible et arrête uniquement le processus qu’il a créé.

## Points à vérifier pour les prochaines versions

Il reste à :

1. intégrer MLX nativement en Swift ou embarquer proprement son environnement d’exécution ;
2. tester installation, notifications, migration, IA et fermeture du moteur sur un Mac Apple Silicon propre ;
3. décider si une version Intel ou universelle est réellement nécessaire.

Une publication App Store, iCloud et Calendrier Apple reste hors du périmètre actuel.
