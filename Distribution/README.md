# Distribution macOS de Quartz

Le design et le parcours fonctionnel de Quartz ont été validés par l’utilisateur le 26 août 2026. La génération du `.app` est donc autorisée.

## Première livraison locale

- version : `1.0.0` (`CFBundleVersion` 1) ;
- identifiant : `com.thomasalloin.Quartz` ;
- cible : macOS 14 ou ultérieur, Apple Silicon ;
- application : `dist/Quartz.app` ;
- archive : `dist/Quartz-1.0.0-macOS-Apple-Silicon.zip` ;
- signature actuelle : ad hoc locale, vérifiée avec `codesign` ;
- icône : galet de lapis texturé avec les trois obélisques et la faille centrale ;
- ressources incluses : textures, relief du widget et modèle français MLX de 136 Mo ;
- intégration externe : binaires `quartz` et `quartz-mcp` inclus dans `Contents/Helpers`.

Cette version est destinée au Mac de développement et à la validation locale. Elle n’est pas encore notarisée pour une diffusion publique.

## Construire l’application

Le modèle étant suivi par Git LFS, vérifier d’abord qu’il est présent, puis lancer :

```bash
git lfs pull
./Packager.command
```

`Packager.command` exécute par défaut `Verifier.command`, compile les deux exécutables en mode release, assemble le bundle et ses ressources, applique la signature, vérifie l’architecture et crée le ZIP.

Les valeurs peuvent être adaptées sans modifier le script :

```bash
QUARTZ_VERSION=1.0.1 \
QUARTZ_BUILD_NUMBER=2 \
QUARTZ_BUNDLE_ID=com.thomasalloin.Quartz \
./Packager.command
```

Une identité Apple peut être fournie plus tard avec `QUARTZ_SIGN_IDENTITY`. Sans cette variable, le script utilise volontairement la signature ad hoc `-`.

## Fonctionnement du bundle

Les données restent dans `~/Library/Application Support/Quartz`. Au premier lancement du `.app`, Quartz importe les préférences du précédent exécutable `QuartzPreview` lorsque la nouvelle application n’a pas déjà une valeur équivalente.

Les notifications locales sont disponibles parce que l’application possède désormais un bundle macOS et un identifiant stable. L’autorisation est demandée uniquement lorsque l’utilisateur active **Notifications** dans les réglages.

Le modèle spécialisé est embarqué. Le moteur exécutable `mlx_lm.server` reste temporairement une dépendance installée sur le Mac ; Quartz le détecte, le lance sur `127.0.0.1`, refuse un serveur incompatible et arrête uniquement le processus qu’il a créé.

## Avant une diffusion à d’autres utilisateurs

Il reste à :

1. intégrer MLX nativement en Swift ou embarquer proprement son environnement d’exécution ;
2. signer avec un certificat Apple Developer ID et activer le hardened runtime ;
3. notariser le ZIP auprès d’Apple puis agrafer le ticket au bundle ;
4. tester installation, notifications, migration, IA et fermeture du moteur sur un Mac Apple Silicon propre ;
5. décider si une version Intel ou universelle est réellement nécessaire.

Une publication App Store, iCloud et Calendrier Apple reste hors du périmètre actuel.
