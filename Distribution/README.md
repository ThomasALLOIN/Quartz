# Préparation de la distribution macOS

Quartz reste volontairement un aperçu SwiftPM jusqu’à la validation explicite de son design et de ses fonctions. Ce dossier décrit le passage au `.app` sans déclencher cette étape prématurément.

## État préparatoire

- cible actuelle : macOS 14 minimum ;
- cœur de l’application : SwiftUI + AppKit, sans service distant ;
- IA : modèle français embarqué, exécution limitée aux Mac Apple Silicon et dépendance temporaire à `mlx_lm.server` installé sur le Mac ;
- données : `~/Library/Application Support/Quartz`, avec sauvegarde précédente et quarantaine `Recovery` ;
- modèle de 136 Mo : suivi par Git LFS ;
- notifications : code prêt, mais livraison réelle à valider dans un bundle signé ;
- synchronisation cloud et publication App Store : hors périmètre tant qu’elles ne sont pas demandées.

## Décisions requises avant de générer le `.app`

1. Valider le design et le parcours fonctionnel dans les tailles 400 × 400 et 600 × 600, ainsi que le widget 74 × 42.
2. Confirmer macOS 14 et Apple Silicon comme première cible de diffusion.
3. Choisir si le moteur MLX doit être embarqué, remplacé par une intégration Swift native ou installé au premier lancement.
4. Confirmer l’identifiant de bundle proposé : `com.thomasalloin.Quartz`.
5. Choisir une diffusion directe signée/notarisée ou une future publication App Store.

## Étapes du jalon `.app`

1. Installer ou mettre à jour Xcode complet et sélectionner son outil développeur.
2. Créer la cible macOS `Quartz` à partir du package existant sans dupliquer le moteur `QuartzKit`.
3. Ajouter l’AppIcon final, l’identifiant de bundle, les numéros de version et les réglages de signature.
4. Embarquer les textures et le modèle LFS dans les ressources de la cible.
5. Choisir puis intégrer le moteur MLX autonome.
6. Tester l’autorisation, la planification et la livraison des notifications.
7. Vérifier migration, sauvegarde, mode hors ligne et fermeture de MLX sur un Mac propre.
8. Archiver, signer, notariser puis seulement produire l’exécutable validé.

## Contrôle avant diffusion

Exécuter `./Verifier.command`, puis faire un essai manuel complet sans données de développement. Une version ne doit pas être diffusée si une récupération de données, une notification ou le démarrage/arrêt de l’IA n’a pas été vérifié dans le bundle final.
