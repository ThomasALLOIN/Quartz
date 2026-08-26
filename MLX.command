#!/bin/zsh

set -e

PROJECT_DIR="${0:A:h}"
MODEL="HuggingFaceTB/SmolLM2-135M-Instruct-Q8-mlx"
ADAPTER="$PROJECT_DIR/MLX/Adapters/quartz-fr"
FUSED_MODEL="$PROJECT_DIR/Sources/QuartzApp/Resources/MLX/quartz-fr"
PORT="8080"

cd "$PROJECT_DIR"

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Quartz : MLX nécessite un Mac avec une puce Apple Silicon."
  read -r "?Appuyez sur Entrée pour fermer…"
  exit 1
fi

if ! command -v mlx_lm.server >/dev/null 2>&1; then
  echo "Quartz : MLX-LM n’est pas encore installé."
  echo "Installez-le avec : uv tool install 'mlx-lm[train]'"
  read -r "?Appuyez sur Entrée pour fermer…"
  exit 1
fi

echo "Quartz démarre son petit modèle local…"
echo "Le premier lancement téléchargera environ 148 Mo."
echo "Gardez cette fenêtre ouverte pendant l’utilisation de l’assistant."
if [[ -f "$FUSED_MODEL/model.safetensors" ]]; then
  echo "Modèle français Quartz détecté : il sera chargé automatiquement."
  SERVER_MODEL="$FUSED_MODEL"
else
  echo "Aucun modèle français fusionné trouvé : utilisation du modèle de base."
  SERVER_MODEL="$MODEL"
  if [[ -f "$ADAPTER/adapters.safetensors" ]]; then
    echo "Conseil : fusionnez l’adaptateur présent avant d’utiliser Quartz."
  fi
fi
echo

exec mlx_lm.server \
  --model "$SERVER_MODEL" \
  --host 127.0.0.1 \
  --port "$PORT"
