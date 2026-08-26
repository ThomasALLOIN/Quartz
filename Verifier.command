#!/bin/zsh

set -e

PROJECT_DIR="${0:A:h}"
cd "$PROJECT_DIR"

if [[ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]]; then
  export SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
fi
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/private/tmp}/quartz-clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/private/tmp}/quartz-swiftpm-cache"

swift build
swift run QuartzChecks

DEVELOPER_DIR="$(xcode-select -p)"
TESTING_FRAMEWORKS="$DEVELOPER_DIR/Library/Developer/Frameworks"
TESTING_INTEROP="$DEVELOPER_DIR/Library/Developer/usr/lib"
(
  # Le SDK 15.4 contourne l’incompatibilité de l’aperçu, tandis que Swift
  # Testing doit utiliser le SDK courant livré avec le compilateur.
  unset SDKROOT
  if [[ -d "$TESTING_FRAMEWORKS/Testing.framework" && -f "$TESTING_INTEROP/lib_TestingInterop.dylib" ]]; then
    swift test --enable-swift-testing --disable-xctest \
      -Xswiftc -F -Xswiftc "$TESTING_FRAMEWORKS" \
      -Xlinker "-F$TESTING_FRAMEWORKS" \
      -Xlinker -rpath -Xlinker "$TESTING_FRAMEWORKS" \
      -Xlinker -rpath -Xlinker "$TESTING_INTEROP"
  else
    swift test --enable-swift-testing --disable-xctest
  fi
)

for required_path in \
  Sources/QuartzKit \
  Sources/QuartzApp \
  Sources/QuartzCLI \
  Sources/QuartzChecks \
  Quartz.command \
  Integrations/quartz-task.schema.json; do
  if [[ ! -e "$PROJECT_DIR/$required_path" ]]; then
    print -u2 "✗ Élément Quartz absent : $required_path"
    exit 1
  fi
done

OLD_NAME_PATTERN='[Ee][Cc][Rr][Ii][Nn]'
if rg -n "$OLD_NAME_PATTERN" "$PROJECT_DIR" \
  -g '!.build/**' \
  -g '!.git/**' \
  -g '!Sources/QuartzKit/ExternalIntegration.swift' \
  -g '!Sources/QuartzApp/Services/WindowCoordinator.swift' \
  -g '!Sources/QuartzChecks/main.swift' \
  -g '!Verifier.command'; then
  print -u2 "✗ Une référence à l’ancien nom subsiste hors du code de migration"
  exit 1
fi
print "✓ Le projet, ses modules et ses commandes portent le nom Quartz"

MENU_ICON="$PROJECT_DIR/Sources/QuartzApp/Views/QuartzMenuBarIcon.swift"
ROOT_VIEW="$PROJECT_DIR/Sources/QuartzApp/Views/RootView.swift"
if ! rg -q -F 'Image(nsImage: QuartzMenuBarArtwork.image)' "$MENU_ICON" \
  || ! rg -q -F 'image.isTemplate = true' "$MENU_ICON" \
  || ! rg -q -F 'QuartzObelisksShape()' "$ROOT_VIEW"; then
  print -u2 "✗ L’emblème aux trois obélisques doit apparaître dans l’en-tête et la barre macOS"
  exit 1
fi
print "✓ L’emblème Quartz est partagé par l’en-tête et la barre des menus"

WINDOW_COORDINATOR="$PROJECT_DIR/Sources/QuartzApp/Services/WindowCoordinator.swift"
if ! rg -q -F 'expandedMinSize = NSSize(width: 400, height: 372)' "$WINDOW_COORDINATOR" \
  || ! rg -q -F 'expandedMaxSize = NSSize(width: 600, height: 572)' "$WINDOW_COORDINATOR" \
  || ! rg -q -F 'expandedMinFrameSize = NSSize(width: 400, height: 400)' "$WINDOW_COORDINATOR" \
  || ! rg -q -F 'expandedMaxFrameSize = NSSize(width: 600, height: 600)' "$WINDOW_COORDINATOR" \
  || ! rg -q -F '[.titled, .resizable, .fullSizeContentView]' "$WINDOW_COORDINATOR"; then
  print -u2 "✗ La fenêtre dépliée ne conserve plus sa plage native 400 × 400 à 600 × 600 px"
  exit 1
fi
print "✓ La fenêtre dépliée reste redimensionnable de 400 × 400 à 600 × 600 px"

TEXTURE_DIR="$PROJECT_DIR/Sources/QuartzApp/Resources/Textures"
for texture in lapis.jpg black-marble.png; do
  if [[ ! -s "$TEXTURE_DIR/$texture" ]]; then
    print -u2 "✗ Texture absente ou vide : $texture"
    exit 1
  fi
done
print "✓ Les 2 textures minérales Lapis et Marbre noir sont présentes"

if [[ ! -s "$TEXTURE_DIR/obelisk-relief-v1.png" ]]; then
  print -u2 "✗ Relief du sanctuaire d’obélisques absent ou vide"
  exit 1
fi
print "✓ Le relief du sanctuaire d’obélisques est présent"

LOCAL_MODEL="$PROJECT_DIR/Sources/QuartzApp/Resources/MLX/quartz-fr/model.safetensors"
LOCAL_RUNTIME="$PROJECT_DIR/Sources/QuartzApp/Services/LocalMLXRuntime.swift"
if [[ ! -s "$LOCAL_MODEL" ]] \
  || ! rg -q -F 'ensureRunning(configuration:' "$LOCAL_RUNTIME" \
  || ! rg -q -F 'applicationWillTerminate' "$PROJECT_DIR/Sources/QuartzApp/QuartzApp.swift"; then
  print -u2 "✗ Le modèle MLX doit être une ressource gérée automatiquement par Quartz"
  exit 1
fi
if ! rg -q -F 'case unexpectedServer' "$LOCAL_RUNTIME" \
  || ! rg -q -F 'modelList.data.count == 1' "$LOCAL_RUNTIME" \
  || ! rg -q -F 'truncate(atOffset: 0)' "$LOCAL_RUNTIME"; then
  print -u2 "✗ Quartz doit refuser un serveur MLX incompatible et borner son journal"
  exit 1
fi
print "✓ Le modèle MLX est intégré, identifié et son cycle de vie est géré par Quartz"

APP_MODEL="$PROJECT_DIR/Sources/QuartzApp/AppModel.swift"
LLM_COMPOSER="$PROJECT_DIR/Sources/QuartzApp/Views/LLMComposerView.swift"
SETTINGS_VIEW="$PROJECT_DIR/Sources/QuartzApp/Views/SettingsView.swift"
if ! rg -q -F 'static let llmEnabled = "llmEnabled"' "$APP_MODEL" \
  || ! rg -q -F 'func setLLMEnabled(_ enabled: Bool)' "$APP_MODEL" \
  || ! rg -q -F 'llmRequestTask?.cancel()' "$APP_MODEL" \
  || ! rg -q -F 'LocalMLXRuntime.shared.stop()' "$APP_MODEL" \
  || ! rg -q -F 'model.setLLMEnabled(!model.llmEnabled)' "$LLM_COMPOSER" \
  || ! rg -q -F 'title: "IA locale"' "$SETTINGS_VIEW"; then
  print -u2 "✗ L’interrupteur de l’IA locale doit rester visible, mémorisé et effectif"
  exit 1
fi
print "✓ L’IA locale peut être activée ou coupée depuis Quartz"


RECOVERABLE_STORE="$PROJECT_DIR/Sources/QuartzKit/RecoverableJSONStore.swift"
PERSISTENCE_TESTS="$PROJECT_DIR/Tests/QuartzKitTests/RecoverableJSONStoreTests.swift"
if ! rg -q -F 'quarantinePrimaryFile()' "$RECOVERABLE_STORE" \
  || ! rg -q -F 'backupURL' "$RECOVERABLE_STORE" \
  || ! rg -q -F 'case failed(JSONFileStoreFailure)' "$RECOVERABLE_STORE" \
  || [[ ! -s "$PERSISTENCE_TESTS" ]] \
  || ! rg -q -F 'storageNotice' "$APP_MODEL"; then
  print -u2 "✗ La sauvegarde, la quarantaine et la récupération des données doivent rester actives"
  exit 1
fi
print "✓ Les données disposent d’une sauvegarde automatique et d’une récupération testée"

NOTIFICATION_SCHEDULER="$PROJECT_DIR/Sources/QuartzApp/Services/NotificationScheduler.swift"
if ! rg -q -F 'planningHorizonDays = 365' "$NOTIFICATION_SCHEDULER" \
  || ! rg -q -F 'failedCount' "$NOTIFICATION_SCHEDULER" \
  || ! rg -q -F 'content.userInfo' "$NOTIFICATION_SCHEDULER" \
  || ! rg -q -F 'applyNotificationReport' "$APP_MODEL"; then
  print -u2 "✗ Les notifications doivent conserver leur horizon et signaler les échecs"
  exit 1
fi
print "✓ Les notifications planifient jusqu’à un an et exposent leurs échecs"

TASK_LIST="$PROJECT_DIR/Sources/QuartzApp/Views/TaskListView.swift"
POST_IT_BOARD="$PROJECT_DIR/Sources/QuartzApp/Views/PostItBoardView.swift"
if ! rg -q -F '.accessibilityActions {' "$TASK_LIST" \
  || ! rg -q -F 'pendingSave: Task<Void, Never>?' "$POST_IT_BOARD" \
  || ! rg -q -F '.accessibilityActions {' "$POST_IT_BOARD"; then
  print -u2 "✗ Les actions essentielles doivent rester disponibles sans survol et les post-it temporisés"
  exit 1
fi
print "✓ Les actions critiques sont accessibles et les post-it évitent les écritures à chaque frappe"

WEEK_STRIP="$PROJECT_DIR/Sources/QuartzApp/Views/RootView.swift"
if ! rg -q -F 'HStack(spacing: 8)' "$WEEK_STRIP" \
  || ! rg -q -F '.frame(height: 48)' "$WEEK_STRIP" \
  || ! rg -q -F '.padding(.horizontal, 14)' "$WEEK_STRIP" \
  || ! rg -q -F '.padding(.vertical, 7)' "$WEEK_STRIP" \
  || ! rg -q -F 'lineWidth: 0.75' "$WEEK_STRIP"; then
  print -u2 "✗ La bande des sept jours doit conserver sa respiration visuelle"
  exit 1
fi
print "✓ Les sept jours conservent une présentation aérée"
