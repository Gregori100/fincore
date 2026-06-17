#!/usr/bin/env bash
# Genera el APK release apuntando al backend definido en FINCORE_API_URL.
#
# Uso:
#   export FINCORE_API_URL=https://loma-latitude-3540.tail285790.ts.net
#   ./scripts/build-apk.sh
#
# Output:
#   build/app/outputs/flutter-apk/app-release.apk
#
# Instalar en device conectado por USB con depuración activa:
#   adb install build/app/outputs/flutter-apk/app-release.apk
set -euo pipefail

if [ -z "${FINCORE_API_URL:-}" ]; then
  echo "Error: FINCORE_API_URL no está definido."
  echo "Ejemplo: export FINCORE_API_URL=https://loma-latitude-3540.tail285790.ts.net"
  exit 1
fi

cd "$(dirname "$0")/.."

flutter build apk --release --dart-define=FINCORE_API_URL="$FINCORE_API_URL"

echo ""
echo "APK generado: build/app/outputs/flutter-apk/app-release.apk"
echo "Tamaño: $(du -h build/app/outputs/flutter-apk/app-release.apk | cut -f1)"
echo ""
echo "Para instalar en device conectado:"
echo "  adb install build/app/outputs/flutter-apk/app-release.apk"
