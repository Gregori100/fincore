#!/usr/bin/env bash
# Arranca la app en Linux desktop apuntando al backend definido en FINCORE_API_URL.
#
# Uso:
#   export FINCORE_API_URL=https://loma-latitude-3540.tail285790.ts.net
#   ./scripts/run-linux.sh
#
# O en una sola línea:
#   FINCORE_API_URL=https://... ./scripts/run-linux.sh
set -euo pipefail

if [ -z "${FINCORE_API_URL:-}" ]; then
  echo "Error: FINCORE_API_URL no está definido."
  echo "Ejemplo: export FINCORE_API_URL=https://loma-latitude-3540.tail285790.ts.net"
  exit 1
fi

cd "$(dirname "$0")/.."

exec flutter run -d linux --dart-define=FINCORE_API_URL="$FINCORE_API_URL" "$@"
