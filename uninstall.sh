#!/bin/bash
set -eu

PROJECT_DIR="/userdata/system/sunshine-service"
SERVICE_FILE="/userdata/system/services/sunshine"

if [ -x "${SERVICE_FILE}" ]; then
    "${SERVICE_FILE}" stop || true
fi

if command -v batocera-services >/dev/null 2>&1; then
    batocera-services disable sunshine >/dev/null 2>&1 || true
fi

rm -f "${SERVICE_FILE}"
rm -rf "${PROJECT_DIR}"

echo "Removed the Sunshine Batocera service and project directory."
echo "The Sunshine Flatpak and its configuration were left untouched."
