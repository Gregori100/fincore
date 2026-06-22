#!/usr/bin/env bash
#
# verify-apk.sh — valida versionCode del APK contra el esperado por pubspec.yaml.
#
# Por qué existe (RF-008 del sprint flutter-local-hardening-v3):
#   Flutter `--split-per-abi` prepende un prefix de 1000/2000/3000 al versionCode
#   según ABI. Para arm64 el prefix es 2000, así que `versionCode=38` en
#   `android/app/build.gradle.kts` produce un APK con `versionCode=2038`.
#   Cuando se olvida bumpear el código en gradle o pubspec, el sideload tira
#   INSTALL_FAILED_VERSION_DOWNGRADE sin pista clara. Este script lo detecta
#   antes del install.
#
# Uso:
#   scripts/verify-apk.sh [APK_PATH]
#
#   APK_PATH default: mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
#
# Exit codes:
#   0 — OK, versionCode coincide con 2000+N (N = build number de pubspec).
#   1 — Mismatch detectado.
#   2 — aapt2 no encontrado en $ANDROID_HOME ni en ~/Android/Sdk/build-tools/.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PUBSPEC="$REPO_ROOT/mobile/pubspec.yaml"

APK_PATH="${1:-$REPO_ROOT/mobile/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk}"

# Prefix que flutter --split-per-abi le suma al versionCode para arm64.
# L3-H6 (quality review v3): parametrizable por env var para soportar otras
# ABIs (armeabi-v7a → 1000, x86_64 → 3000) sin reescribir el script.
ABI_PREFIX="${ABI_PREFIX:-2000}"

if [[ ! -f "$PUBSPEC" ]]; then
  echo "ERROR: no encuentro $PUBSPEC" >&2
  exit 1
fi

if [[ ! -f "$APK_PATH" ]]; then
  echo "ERROR: no encuentro APK en $APK_PATH" >&2
  echo "       Pasá el path como primer argumento o construí el APK con:" >&2
  echo "       cd mobile && flutter build apk --release --split-per-abi" >&2
  exit 1
fi

# --- Leer version: X.Y.Z+N de pubspec.yaml -----------------------------------
PUBSPEC_VERSION="$(grep -E '^version:' "$PUBSPEC" | head -n 1 | awk '{print $2}')"
# L3-H4 (quality review v3, RF-017 v4): tolerar `version: '0.3.7+39'` con
# comillas simples o dobles. `tr` elimina ambos tipos sin romper si no hay.
PUBSPEC_VERSION="$(printf '%s' "$PUBSPEC_VERSION" | tr -d "'\"")"
if [[ -z "$PUBSPEC_VERSION" ]]; then
  echo "ERROR: no pude parsear 'version:' de $PUBSPEC" >&2
  exit 1
fi

PUBSPEC_NAME="${PUBSPEC_VERSION%%+*}"
PUBSPEC_CODE="${PUBSPEC_VERSION##*+}"

if [[ "$PUBSPEC_NAME" == "$PUBSPEC_VERSION" ]]; then
  echo "ERROR: 'version: $PUBSPEC_VERSION' en pubspec.yaml no tiene formato X.Y.Z+N" >&2
  exit 1
fi

# L3-H1 (quality review v3): validar que +N es numérico antes de la aritmética.
# Sin esto, `version: 0.3.7+beta` revienta `set -e` con un mensaje cripto.
if ! [[ "$PUBSPEC_CODE" =~ ^[0-9]+$ ]]; then
  echo "ERROR: build number '+$PUBSPEC_CODE' en pubspec.yaml no es numérico." >&2
  echo "       Esperado: 'version: X.Y.Z+N' con N entero." >&2
  exit 1
fi

EXPECTED_CODE=$((ABI_PREFIX + PUBSPEC_CODE))

# --- Buscar aapt2 -------------------------------------------------------------
# L3-H2 (quality review v3, RF-016 v4): `find` en lugar de glob de `ls` para
# tolerar paths con espacios (típico de macOS `/Users/Nombre Con Espacios/...`).
AAPT2=""
if command -v aapt2 >/dev/null 2>&1; then
  AAPT2="$(command -v aapt2)"
elif [[ -n "${ANDROID_HOME:-}" && -d "$ANDROID_HOME/build-tools" ]]; then
  AAPT2="$(find "$ANDROID_HOME/build-tools" -maxdepth 2 -name aapt2 -type f 2>/dev/null | sort -V | tail -n 1)"
elif [[ -d "$HOME/Android/Sdk/build-tools" ]]; then
  AAPT2="$(find "$HOME/Android/Sdk/build-tools" -maxdepth 2 -name aapt2 -type f 2>/dev/null | sort -V | tail -n 1)"
fi

if [[ -z "$AAPT2" || ! -x "$AAPT2" ]]; then
  echo "ERROR: aapt2 no encontrado." >&2
  echo "       Instalá Android SDK build-tools o seteá ANDROID_HOME." >&2
  exit 2
fi

# --- Extraer versionCode + versionName del APK --------------------------------
# Capturamos la salida completa primero y después grep, así evitamos un
# SIGPIPE de aapt2 escribiendo más de lo que `head -n 1` lee (que con
# `set -o pipefail` reventaba el script con exit 141 en runs benignos).
#
# L3-H7 (quality review v3): si el APK está corrupto, aapt2 puede exitear con
# no-zero. Capturamos para mostrar mensaje útil en lugar del exit 1 cripto.
BADGING_FULL="$("$AAPT2" dump badging "$APK_PATH" 2>&1)" || {
  echo "ERROR: aapt2 falló analizando '$APK_PATH'. ¿APK corrupto o truncado?" >&2
  echo "       Output de aapt2:" >&2
  printf '%s\n' "$BADGING_FULL" | sed 's/^/         /' >&2
  exit 1
}
# L3-H3 (quality review v3): buscar versionCode en TODA la salida (no solo
# línea 1). Versiones futuras de aapt2 podrían reordenar las líneas; el script
# resiste ese cambio.
# L3-H5 (quality review v3, RF-018 v4): tolerar comillas simples y dobles
# en la salida de aapt2. Versiones modernas usan simples; aapt2 pre-30 a veces
# emitía dobles. El charset `['"]` cubre ambas.
APK_CODE="$(printf '%s' "$BADGING_FULL" | sed -n "s/.*versionCode=['\"]\\([0-9]*\\)['\"].*/\\1/p" | head -n 1)"
APK_NAME="$(printf '%s' "$BADGING_FULL" | sed -n "s/.*versionName=['\"]\\([^'\"]*\\)['\"].*/\\1/p" | head -n 1)"

if [[ -z "$APK_CODE" ]]; then
  echo "ERROR: no pude extraer versionCode del APK." >&2
  echo "       Output de aapt2: $BADGING" >&2
  exit 1
fi

# --- Comparar -----------------------------------------------------------------
echo "APK:           $APK_PATH"
echo "aapt2:         $AAPT2"
echo "pubspec:       $PUBSPEC_NAME+$PUBSPEC_CODE (esperado APK code: $EXPECTED_CODE)"
echo "APK detectado: $APK_NAME ($APK_CODE)"

if [[ "$APK_CODE" != "$EXPECTED_CODE" ]]; then
  echo ""
  echo "✗ MISMATCH: versionCode esperado $EXPECTED_CODE, encontrado $APK_CODE."
  echo "  Causa probable: olvido bumpear 'versionCode' en android/app/build.gradle.kts"
  echo "  o 'version: X.Y.Z+N' en pubspec.yaml. Ambos deben estar en sincronía."
  exit 1
fi

if [[ "$APK_NAME" != "$PUBSPEC_NAME" ]]; then
  echo ""
  echo "✗ MISMATCH: versionName esperado $PUBSPEC_NAME, encontrado $APK_NAME."
  exit 1
fi

echo ""
echo "✓ OK — versionCode $EXPECTED_CODE / versionName $PUBSPEC_NAME consistentes."
