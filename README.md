# Quartz — application macOS

Quartz est une petite application française de calendrier et de tâches quotidiennes, conçue comme un objet minéral discret sur le bureau.

Le nom Quartz est utilisé dans toute l’application : interface, modules Swift, exécutables, scripts, modèle MLX et dossier de données. Les anciennes données sont migrées automatiquement au premier lancement.

## État actuel

Quartz est désormais livré comme une **application macOS locale**, tout en conservant l’aperçu SwiftPM pour le développement :

- fenêtre dépliée redimensionnable par ses bords de `400 × 400 px` à `600 × 600 px`, chrome macOS compris, avec mémorisation de la dernière taille ;
- pierre réduite sans chrome de `74 × 42 px`, sculptée comme un petit sanctuaire d’obélisques aux plans arrière ombrés, semi-transparente au repos et entièrement opaque au survol, sans date, panneau de fond ni plaque translucide sur le relief ;
- calendrier hebdomadaire et vue mensuelle ;
- tâches de calendrier avec sous-tâches, descriptions facultatives, échéances et progression journalière ; au survol, quatre boutons compacts permettent de modifier, supprimer, terminer toutes les sous-tâches ou les déplier ;
- signal d’échéance immédiat : pendant la minute exacte d’une tâche non terminée, sa carte devient orange ; si Quartz est réduit, une pastille orange affiche son nom sur la pierre, avec un compteur lorsque plusieurs tâches arrivent ensemble ;
- mode post-it séparé avec deux types : les jaunes restent visibles tous les jours ; les verts « daily » sont liés à une seule date ; les saisies manuelles, MLX ou déposées par un agent suivent le type actif et ne touchent ni au calendrier ni à sa progression ;
- récurrences quotidienne, jours ouvrés, hebdomadaire et mensuelle ;
- planification des rappels locaux via le système de notifications Apple dans `Quartz.app` ;
- stockage local sur le Mac, avec conservation automatique de la dernière version valide et copie de tout fichier illisible dans `Recovery` ;
- deux textures minérales réelles mises en cache pour une transition fluide : **Lapis nuit** bleu et **Marbre noir** veiné gris perle ;
- réduction/dépliage rapides, avec retour automatique à la dernière position de la pierre compacte ;
- toujours visible, sons et menu de barre macOS avec l’option « Afficher le widget ».
- passerelle locale `Quartz.command` et serveur MCP `quartz-mcp` pour permettre à Codex, Claude et aux autres agents MCP de créer tâches et post-it sans modifier directement les données.
- composeur relié à un unique petit modèle local MLX spécialisé en français, inclus dans les ressources de Quartz et démarré automatiquement en arrière-plan au premier envoi, sans Terminal ni fournisseur distant ; chaque proposition ouvre l’éditeur pour confirmation avant création.
- interrupteur « IA locale » mémorisé dans le composeur et les réglages : le couper annule l’analyse en cours, empêche tout nouvel envoi et arrête le moteur démarré par Quartz.

Le design et les fonctions ont été validés le 26 août 2026. Le bundle `1.0.1` possède l’icône aux trois obélisques, l’identifiant `com.thomasalloin.Quartz`, les textures, le modèle français et la commande externe. Sa distribution directe est signée Developer ID et notarisée par Apple.

## Utiliser Quartz.app

L'installateur recommandé est `dist/Quartz-macOS-1.0.1.dmg`. Le ZIP et le bundle restent aussi disponibles dans `dist`.

1. Ouvrir le fichier `.dmg` dans Finder.
2. Glisser **Quartz** vers le dossier **Applications** affiché dans la fenêtre.
3. Ouvrir **Quartz** depuis Applications, puis activer **Notifications** dans les réglages lorsque macOS demande l’autorisation.

Le bundle cible macOS 14 ou ultérieur sur Apple Silicon. Les tâches et post-it déjà utilisés dans l’aperçu sont conservés ; les préférences visuelles et la dernière position du widget sont migrées au premier lancement.

Pour reconstruire l’application après une modification :

```bash
./Packager.command
```

La commande vérifie le projet, compile en mode release, assemble les ressources, signe le bundle puis crée l’installateur DMG et l’archive ZIP. Pour une distribution publique, elle utilise l’identité Developer ID et un profil de notarisation déjà conservé dans le trousseau macOS ; aucun secret Apple ne doit être ajouté au dépôt. Les détails sont dans [Distribution/README.md](Distribution/README.md).

## Récupérer le projet

Le modèle de 136 Mo est suivi avec Git LFS :

```bash
git clone https://github.com/ThomasALLOIN/Quartz.git
cd Quartz
git lfs install --local
git lfs pull
```

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

`MLX.command` reste disponible uniquement comme outil de diagnostic pour le développement ; il n’est plus nécessaire dans l’utilisation normale. Le modèle français est inclus dans `Quartz.app`, mais cette première version dépend encore de l’exécutable `mlx_lm.server` installé sur le Mac. Les réglages indiquent clairement si ce moteur est prêt ; une future distribution autonome devra intégrer le moteur MLX en Swift ou l’embarquer proprement.

Le modèle ne crée jamais une tâche de calendrier directement : l’écran de vérification reste obligatoire. Les formulations françaises explicites de date, d’heure, de récurrence et de rappel sont relues par le moteur de Quartz ; « demain, chaque jours à 19h, rappel 15 minutes avant » conserve donc ces quatre informations même si le petit modèle les oublie. Une demande contenant manifestement plusieurs tâches est refusée avec une invitation à les envoyer une par une. La destination tâche, post-it jaune ou post-it vert est figée au moment où la flèche est pressée.

Le bouton **Active / Coupée** dans le panneau message contrôle l’IA locale. Le même choix est disponible dans **Réglages → Assistant** et reste mémorisé après la fermeture de Quartz.

Pour créer des notes hors calendrier, cliquer sur le bouton **post-it** dans l’en-tête. Il suit un cycle sans ouvrir de fenêtre : premier clic, jaune **toujours** ; deuxième clic, vert **daily** ; troisième clic, désactivé. Le texte **Quartz** et le bouton prennent la couleur du type actif. Survoler Quartz affiche le panneau accolé à gauche : en jaune, il montre les notes permanentes ; en vert, uniquement les daily du jour sélectionné. Une note jaune et son repère apparaissent dans chaque journée ; une note verte n’apparaît que sur sa date. Survoler une petite carte dans la journée révèle une corbeille permettant de la supprimer directement. L’ajout rapide, `⌘N`, le composeur MLX et les demandes reçues d’un agent créent le type actif sans modifier la progression du calendrier. Chaque carte reste modifiable dans le panneau latéral.

L’icône aux trois obélisques reste disponible dans la barre des menus macOS. Son interrupteur **Afficher le widget** masque ou rappelle la pierre sans quitter Quartz.

Pour déplacer la pierre réduite, saisissez-la n’importe où et faites-la glisser. Au relâchement, elle s’aimante au bord gauche ou droit le plus proche : elle ne reste donc jamais au milieu de l’écran. Un clic bref sans mouvement déplie Quartz vers l’intérieur depuis ce même bord. En mode déplié, faites glisser l’en-tête : au prochain repli, la pierre reviendra à son bord et à sa dernière hauteur compacte.

## Vérifier le projet

```bash
./Verifier.command
```

Cette commande compile Quartz, exécute les 89 contrôles du moteur, les tests Swift de sauvegarde/récupération et les gardes statiques de l’interface. La même vérification s’exécute automatiquement sur GitHub à chaque envoi.

Les données de Quartz sont conservées dans :

```text
~/Library/Application Support/Quartz/tasks.json
~/Library/Application Support/Quartz/post-its.json
~/Library/Application Support/Quartz/tasks.backup.json
~/Library/Application Support/Quartz/post-its.backup.json
~/Library/Application Support/Quartz/Recovery/
```

Le bouton **Afficher** de la section **Données** ouvre directement ce dossier. Une erreur de lecture ou d’écriture est affichée dans Quartz au lieu d’être ignorée.

## Ajouter une tâche depuis un agent ou le Terminal

```bash
./Quartz.command ajouter --titre "Préparer le dossier" --date demain --heure 09:30 --rappel 15m --source chatgpt
```

Quartz importe la demande lorsqu’il est ouvert ou au prochain lancement. Les options, le format JSON et une instruction prête à donner à ChatGPT, Claude, Hermes, OpenCode ou un LLM local sont détaillés dans [INTEGRATION_LLM.md](INTEGRATION_LLM.md).

Dans l’application empaquetée, la même commande est disponible à l’emplacement `Quartz.app/Contents/Helpers/quartz`.

## Connecter Codex ou Claude à Quartz

Quartz embarque un serveur MCP local standard, sans réseau ni clé. Il expose deux outils : `quartz_create_task` et `quartz_create_note`. Ils déposent des requêtes validées dans des boîtes locales privées ; Quartz les importe lorsqu’il est ouvert ou au lancement suivant.

Les configurations pour Codex et Claude Desktop sont dans [QUARTZ_MCP.md](QUARTZ_MCP.md). Lancez `InstallerMCP.command` pour installer une copie stable du serveur dans les données Quartz, indépendamment du chemin du projet ou du bundle.

## Raccourcis

- `⌘N` : nouvelle tâche
- `⌘,` : réglages
- `⌘←` / `⌘→` : jour précédent / suivant
- `⇧⌘T` : aujourd’hui
- `⇧⌘M` : réduire ou déplier

## Limites de ce jalon

- une modification de récurrence agit sur toute la série ; les exceptions par occurrence viendront après validation du besoin ;
- la synchronisation iCloud ou Calendrier Apple n’est pas incluse ;
- les notifications sont disponibles dans `Quartz.app` ; l’aperçu `swift run` les laisse volontairement désactivées ;
- Quartz planifie jusqu’à un an d’occurrences, dans une file limitée aux 56 prochains rappels et renouvelée à chaque ouverture ou modification ;
- le moteur MLX exécutable n’est pas encore autonome dans le bundle, même si le modèle français est déjà inclus.
