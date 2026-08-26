# Utiliser et spécialiser le LLM local de Quartz avec MLX

## Ce que fait MLX

MLX est le moteur conçu pour les puces Apple. Dans Quartz, il a deux rôles :

1. exécuter le petit modèle local ;
2. l’entraîner légèrement en français avec LoRA.

Le modèle reste spécialisé dans une seule transformation :

```text
« Demain à 9 h, appeler Paul, rappelle-moi 15 min avant »
                              ↓
                 SmolLM2 français dans MLX
                              ↓
{ "title": "Appeler Paul", "date": "demain", "time": "09:00", "reminder": "15m" }
                              ↓
                  validation par le code de Quartz
                              ↓
                    aperçu puis création confirmée
```

## Modèle de départ

Quartz utilise provisoirement :

```text
HuggingFaceTB/SmolLM2-135M-Instruct-Q8-mlx
```

Il contient 135 millions de paramètres et pèse environ 148 Mo dans son format MLX 8 bits. Il est très léger, mais son français devra être renforcé avec nos propres exemples.

## Démarrage dans Quartz

Le modèle français fusionné fait désormais partie des ressources de Quartz. Dans l’utilisation normale :

1. ouvrir le composeur avec l’icône message ;
2. écrire une demande puis cliquer sur la flèche ;
3. Quartz démarre MLX-LM silencieusement, attend qu’il soit prêt et l’arrête à la fermeture de l’application.

`MLX.command` reste un outil de diagnostic facultatif. Il exécute l’équivalent de :

```sh
mlx_lm.server \
  --model Sources/QuartzApp/Resources/MLX/quartz-fr \
  --host 127.0.0.1 \
  --port 8080
```

Si le modèle français fusionné n’existe pas encore, le script démarre automatiquement le modèle de base.

La configuration correspondante dans Quartz est :

- adresse : `http://127.0.0.1:8080/v1` ;
- modèle : `default_model` (c’est le nom local donné par le serveur au modèle chargé).

## Spécialisation en français

Il ne faut pas réentraîner le modèle depuis zéro. MLX-LM permet un entraînement LoRA : seuls de petits adaptateurs apprennent le vocabulaire et la structure des tâches de Quartz.

Le dossier d’entraînement contient :

```text
MLX/Dataset/train.jsonl
MLX/Dataset/valid.jsonl
MLX/Dataset/test.jsonl
MLX/Dataset/realistic.jsonl
```

Le générateur reproductible se trouve dans `Outils/generer_dataset_mlx.py`. Il produit 504 exemples d’apprentissage, 72 de validation et 72 de test ; les titres du lot de test n’apparaissent jamais dans l’apprentissage.

Chaque ligne sera un exemple de conversation :

```json
{"messages":[{"role":"system","content":"Transforme la demande française en JSON Écrin et ne réponds avec rien d’autre."},{"role":"user","content":"Demain à 9 h appeler le dentiste, rappel 15 minutes avant"},{"role":"assistant","content":"{\"title\":\"Appeler le dentiste\",\"date\":\"demain\",\"time\":\"09:00\",\"recurrence\":\"none\",\"reminder\":\"15m\",\"notes\":\"\",\"subtasks\":[]}"}]}
```

Le mot `Écrin` reste ici un libellé interne appris par le modèle fusionné. Il n’est pas affiché dans l’interface : le nom visible de l’application est Quartz. Le conserver évite de dégrader les réponses du modèle déjà entraîné.

L’adaptateur français initial a été entraîné avec :

```sh
mlx_lm.lora \
  --model HuggingFaceTB/SmolLM2-135M-Instruct-Q8-mlx \
  --train \
  --data MLX/Dataset \
  --adapter-path MLX/Adapters/quartz-fr \
  --iters 600 \
  --batch-size 4 \
  --mask-prompt
```

Comme le modèle est quantifié, MLX-LM utilise QLoRA. La perte de validation est passée de `1,602` avant apprentissage à `0,011` après 600 étapes. Ce chiffre vérifie l’apprentissage du corpus, mais les phrases inédites restent le vrai critère de qualité.

## Fusion du modèle spécialisé

La version de MLX-LM installée accepte l’option d’adaptateur dans son serveur mais ne la résout pas correctement avec son alias de modèle. Quartz utilise donc une copie fusionnée, plus fiable :

```sh
hf download HuggingFaceTB/SmolLM2-135M-Instruct-Q8-mlx \
  --local-dir MLX/Base/smollm2-135m-q8

mlx_lm.fuse \
  --model MLX/Base/smollm2-135m-q8 \
  --adapter-path MLX/Adapters/quartz-fr \
  --save-path Sources/QuartzApp/Resources/MLX/quartz-fr
```

Quartz et `MLX.command` détectent ensuite cette copie française automatiquement.

## Mesures de qualité

La mesure historique sur 72 formulations partageant les mêmes patrons que l’apprentissage donnait :

- JSON valide : `72/72` (`100 %`) ;
- tous les champs exactement corrects : `60/72` (`83,3 %`) ;
- principaux écarts : confusion entre heure et date, ou entre récurrence quotidienne et mensuelle.

Cette mesure vérifiait surtout la mémorisation de la structure. Elle est désormais complétée par `realistic.jsonl` : 40 formulations écrites séparément, avec langage oral, fautes, combinaisons de champs, faux positifs, notes et sous-tâches. L’évaluateur exige 100 % de JSON et de schémas valides, puis au moins 70 % de réponses sémantiquement exactes. La casse, les espaces et la forme de l’apostrophe ne faussent pas le score.

Mesure du modèle fusionné actuel sur ce nouveau lot :

- JSON et schémas valides : `39/40` (`97,5 %`) ;
- réponses sémantiquement exactes : `4/40` (`10 %`) ;
- seuil de `70 %` : non atteint.

Ce résultat montre que le modèle de 135 M mémorisait les anciens patrons mais généralise encore mal. Il ne doit donc être considéré que comme un extracteur assisté. Les champs temporels finaux sont désormais exclusivement tirés des règles françaises explicites ; les valeurs de date, heure, récurrence ou rappel inventées par MLX sont ignorées.

Pour lancer ce banc d’essai, démarrer d’abord `MLX.command` comme outil de diagnostic :

```sh
python3 Outils/evaluer_mlx.py --minimum-exact 0.70
```

Quartz ajoute aussi une garde déterministe pour les formulations françaises explicites. Elle couvre les dates comme « demain », « après-demain », « dans trois jours », « vendredi prochain », `20/08/2026` ou « 20 août » ; les heures ; les récurrences courantes ; et les rappels à l’heure, 5, 15, 30 minutes ou 1 heure avant. Une date impossible ou un délai de rappel indisponible est refusé au lieu d’être inventé. Les demandes manifestement composées de plusieurs tâches sont arrêtées avant même l’appel au modèle.

Lorsque le bouton **Mode post-it** est actif, la proposition de MLX n’ouvre pas l’éditeur de tâche et n’est pas ajoutée au calendrier. Elle devient immédiatement une carte dans le mur de post-it, où elle peut être corrigée ou supprimée en un clic. La destination exacte est capturée avant l’appel : changer le bouton pendant l’analyse ne déplace pas la réponse. Le mode normal conserve l’écran de confirmation obligatoire avant toute création de tâche de calendrier.

## Règles de sécurité et de qualité

- Le serveur reste limité à `127.0.0.1`.
- Le LLM ne doit jamais écrire directement dans `tasks.json`.
- Quartz décode puis valide chaque champ avec son propre moteur.
- Toute interprétation est présentée dans l’éditeur avant enregistrement.
- Le lot réaliste séparé de l’entraînement mesure la précision sémantique et fait échouer l’évaluation sous le seuil choisi.

## État actuel du prototype

Le modèle de 148 Mo est inclus dans les ressources de Quartz ; le corpus français et l’adaptateur LoRA restent dans l’espace de développement. Le lancement automatique en arrière-plan, l’appel HTTP Swift, la validation stricte, les gardes déterministes et l’écran de confirmation sont actifs. Le modèle fusionné actuel n’atteint pas le seuil réaliste ; le prochain choix consiste à réentraîner sur des formulations réellement variées ou à essayer un modèle légèrement plus grand.
