# Quartz — aperçu macOS

Quartz est une petite application française de calendrier et de tâches quotidiennes, conçue comme un objet minéral discret sur le bureau.

Le nom Quartz est utilisé dans toute l’application : interface, modules Swift, exécutables, scripts, modèle MLX et dossier de données. Les anciennes données sont migrées automatiquement au premier lancement.

## État actuel

Cette étape livre un **aperçu natif**, pas un fichier `.app` :

- fenêtre dépliée redimensionnable par ses bords de `400 × 400 px` à `600 × 600 px`, chrome macOS compris, avec mémorisation de la dernière taille ;
- pierre réduite sans chrome de `74 × 42 px`, sculptée comme un petit sanctuaire d’obélisques aux plans arrière ombrés, semi-transparente au repos et entièrement opaque au survol, sans date, panneau de fond ni plaque translucide sur le relief ;
- calendrier hebdomadaire et vue mensuelle ;
- tâches de calendrier avec sous-tâches, descriptions facultatives, échéances et progression journalière ; au survol, quatre boutons compacts permettent de modifier, supprimer, terminer toutes les sous-tâches ou les déplier ;
- signal d’échéance immédiat : pendant la minute exacte d’une tâche non terminée, sa carte devient orange ; si Quartz est réduit, une pastille orange affiche son nom sur la pierre, avec un compteur lorsque plusieurs tâches arrivent ensemble ;
- mode post-it séparé avec deux types : les jaunes restent visibles tous les jours ; les verts « daily » sont liés à une seule date ; les saisies manuelles, MLX ou déposées par un agent suivent le type actif et ne touchent ni au calendrier ni à sa progression ;
- récurrences quotidienne, jours ouvrés, hebdomadaire et mensuelle ;
- planification des rappels locaux via le système de notifications Apple dans le futur bundle validé ;
- stockage local sur le Mac ;
- deux textures minérales réelles mises en cache pour une transition fluide : **Lapis nuit** bleu et **Marbre noir** veiné gris perle ;
- réduction/dépliage rapides, avec retour automatique à la dernière position de la pierre compacte ;
- toujours visible, sons et menu de barre macOS avec l’option « Afficher le widget ».
- passerelle locale `Quartz.command` pour permettre aux agents et LLM outillés d’ajouter des tâches sans modifier directement les données.
- composeur relié à un unique petit modèle local MLX spécialisé en français, inclus dans les ressources de Quartz et démarré automatiquement en arrière-plan au premier envoi, sans Terminal ni fournisseur distant ; chaque proposition ouvre l’éditeur pour confirmation avant création.
- interrupteur « IA locale » mémorisé dans le composeur et les réglages : le couper annule l’analyse en cours, empêche tout nouvel envoi et arrête le moteur démarré par Quartz.

Le `.app`, l’icône finale, la signature et la distribution sont volontairement reportés jusqu’à validation fonctionnelle et visuelle.

## Ouvrir l’aperçu

Depuis Finder, double-cliquer sur `Apercu.command`, ou depuis Terminal :

```bash
./Apercu.command
```

Le premier lancement compile les sources, puis ouvre la fenêtre. Les lancements suivants sont plus rapides.

Pour créer une tâche avec le modèle local :

1. ouvrir Quartz avec `Apercu.command` ;
2. cliquer sur la petite icône message dans l’en-tête ;
3. écrire par exemple « Demain à 9 h appeler Paul, rappel 15 minutes avant » ;
4. cliquer sur la flèche : Quartz démarre MLX silencieusement lors du premier envoi ;
5. vérifier la fiche préremplie, puis choisir **Enregistrer**.

`MLX.command` reste disponible uniquement comme outil de diagnostic pour le développement ; il n’est plus nécessaire dans l’utilisation normale.

Le modèle ne crée jamais une tâche de calendrier directement : l’écran de vérification reste obligatoire. Les formulations françaises explicites de date, d’heure, de récurrence et de rappel sont relues par le moteur de Quartz ; « demain, chaque jours à 19h, rappel 15 minutes avant » conserve donc ces quatre informations même si le petit modèle les oublie. Une demande contenant manifestement plusieurs tâches est refusée avec une invitation à les envoyer une par une. La destination tâche, post-it jaune ou post-it vert est figée au moment où la flèche est pressée.

Le bouton **Active / Coupée** dans le panneau message contrôle l’IA locale. Le même choix est disponible dans **Réglages → Assistant** et reste mémorisé après la fermeture de Quartz.

Pour créer des notes hors calendrier, cliquer sur le bouton **post-it** dans l’en-tête. Il suit un cycle sans ouvrir de fenêtre : premier clic, jaune **toujours** ; deuxième clic, vert **daily** ; troisième clic, désactivé. Le texte **Quartz** et le bouton prennent la couleur du type actif. Survoler Quartz affiche le panneau accolé à gauche : en jaune, il montre les notes permanentes ; en vert, uniquement les daily du jour sélectionné. Une note jaune et son repère apparaissent dans chaque journée ; une note verte n’apparaît que sur sa date. Survoler une petite carte dans la journée révèle une corbeille permettant de la supprimer directement. L’ajout rapide, `⌘N`, le composeur MLX et les demandes reçues d’un agent créent le type actif sans modifier la progression du calendrier. Chaque carte reste modifiable dans le panneau latéral.

L’icône aux trois obélisques reste disponible dans la barre des menus macOS. Son interrupteur **Afficher le widget** masque ou rappelle la pierre sans quitter Quartz.

Pour déplacer la pierre réduite, saisissez-la n’importe où et faites-la glisser. Un clic bref sans mouvement la déplie. En mode déplié, faites glisser l’en-tête : au prochain repli, la pierre reviendra exactement à sa dernière position compacte.

## Vérifier le projet

```bash
./Verifier.command
```

Les données de l’aperçu sont conservées dans :

```text
~/Library/Application Support/Quartz/tasks.json
~/Library/Application Support/Quartz/post-its.json
```

## Ajouter une tâche depuis un agent ou le Terminal

```bash
./Quartz.command ajouter --titre "Préparer le dossier" --date demain --heure 09:30 --rappel 15m --source chatgpt
```

Quartz importe la demande lorsqu’il est ouvert ou au prochain lancement. Les options, le format JSON et une instruction prête à donner à ChatGPT, Claude, Hermes, OpenCode ou un LLM local sont détaillés dans [INTEGRATION_LLM.md](INTEGRATION_LLM.md).

## Raccourcis

- `⌘N` : nouvelle tâche
- `⌘,` : réglages
- `⌘←` / `⌘→` : jour précédent / suivant
- `⇧⌘T` : aujourd’hui
- `⇧⌘M` : réduire ou déplier

## Limites de ce jalon

- une modification de récurrence agit sur toute la série ; les exceptions par occurrence viendront après validation du besoin ;
- la synchronisation iCloud ou Calendrier Apple n’est pas incluse ;
- l’aperçu `swift run` n’est pas un bundle reconnu par macOS : son interrupteur de notifications est donc désactivé proprement ; l’autorisation et la livraison seront validées dans le `.app` signé avant diffusion.
