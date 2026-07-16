#!/bin/bash
set -eu

REPO="Redemp/batocera-service-sunshine-flatpak"
BRANCH="${SUNSHINE_SERVICE_BRANCH:-main}"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
APP_ID="dev.lizardbyte.app.Sunshine"
PROJECT_DIR="/userdata/system/sunshine-service"
SERVICE_DIR="/userdata/system/services"
LOG_DIR="/userdata/system/logs"
SERVICE_FILE="${SERVICE_DIR}/sunshine"
FILES="install.sh sunshine sunshine-csrf-setup sunshine-diagnose uninstall.sh"
AUTO_YES=0
INSTALL_SUNSHINE=0
START_SERVICE=1

info() { printf '%s\n' "$*"; }
notice() { printf '[INFO] %s\n' "$*"; }
ok() { printf '[ OK ] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
fail() { printf '[FAIL] %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<USAGE
Usage: install.sh [options]

Options:
  -y, --yes                 Accept installer confirmations.
      --install-sunshine    Install the Sunshine Flatpak when missing.
      --no-start            Install and enable the service without starting it.
  -h, --help                Show this help.

Environment:
  SUNSHINE_SERVICE_BRANCH   GitHub branch or tag to download (default: main).
USAGE
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        -y|--yes) AUTO_YES=1 ;;
        --install-sunshine) INSTALL_SUNSHINE=1 ;;
        --no-start) START_SERVICE=0 ;;
        -h|--help) usage; exit 0 ;;
        *) fail "Unknown option: $1" ;;
    esac
    shift
done

ask_yes_no() {
    local prompt="$1"
    local default="${2:-no}"
    local answer=""

    if [ "${AUTO_YES}" -eq 1 ]; then
        return 0
    fi

    if [ ! -r /dev/tty ]; then
        [ "${default}" = "yes" ]
        return
    fi

    if [ "${default}" = "yes" ]; then
        printf '%s [Y/n] ' "${prompt}" > /dev/tty
    else
        printf '%s [y/N] ' "${prompt}" > /dev/tty
    fi
    IFS= read -r answer < /dev/tty || answer=""

    case "${answer}" in
        y|Y|yes|YES) return 0 ;;
        n|N|no|NO) return 1 ;;
        '') [ "${default}" = "yes" ]; return ;;
        *) return 1 ;;
    esac
}

is_local_source() {
    [ -n "${BASH_SOURCE[0]:-}" ] && \
    [ -f "${BASH_SOURCE[0]}" ] && \
    [ -f "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)/sunshine" ]
}

fetch_files() {
    local destination="$1"
    local file source_dir
    mkdir -p "${destination}"

    if is_local_source; then
        source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
        for file in ${FILES}; do
            cp "${source_dir}/${file}" "${destination}/${file}"
        done
    else
        command -v curl >/dev/null 2>&1 || fail "curl is required for direct GitHub installation."
        for file in ${FILES}; do
            curl -fsSL --retry 3 --connect-timeout 15 \
                "${RAW_BASE}/${file}" -o "${destination}/${file}" \
                || fail "Could not download ${file} from ${RAW_BASE}."
        done
    fi
}

install_sunshine_flatpak() {
    info "Installing Sunshine Flatpak system-wide..."

    if ! flatpak remotes --system 2>/dev/null | awk '{print $1}' | grep -qx "flathub"; then
        fail "The system-wide Flathub remote is not configured. Open Batocera's Flatpak Manager once, then run this installer again."
    fi

    if flatpak install --system -y flathub "${APP_ID}"; then
        if flatpak info --system "${APP_ID}" >/dev/null 2>&1; then
            ok "Sunshine Flatpak installed system-wide"
        else
            fail "Flatpak reported success, but the system-wide Sunshine installation could not be verified."
        fi
    else
        fail "Sunshine could not be installed. Use Batocera's Flatpak Manager and run this installer again."
    fi
}

get_ipv4() {
    ip -4 route get 1.1.1.1 2>/dev/null \
        | sed -n 's/.* src \([^ ]*\).*/\1/p' \
        | head -n 1
}

printf '%s\n' '----------------------------------------------------'
printf '%s\n' ' Sunshine Flatpak Service Installer for Batocera'
printf '%s\n' '----------------------------------------------------'
printf '\n'

if [ -f /etc/batocera-release ] || grep -qi batocera /etc/os-release 2>/dev/null; then
    ok "Batocera detected"
else
    fail "This installer is intended for Batocera."
fi

command -v flatpak >/dev/null 2>&1 || fail "Flatpak is not available on this Batocera installation."
ok "Flatpak is available"

if flatpak info --system "${APP_ID}" >/dev/null 2>&1; then
    ok "Sunshine Flatpak is installed system-wide"
else
    warn "Sunshine Flatpak is not installed system-wide."

    if flatpak info --user "${APP_ID}" >/dev/null 2>&1; then
        warn "A user-only Sunshine installation was detected."
        fail "This Batocera service requires the system-wide Sunshine Flatpak. Remove the user installation and install Sunshine through Batocera's Flatpak Manager, or run: flatpak uninstall --user ${APP_ID}"
    fi

    if [ "${INSTALL_SUNSHINE}" -eq 1 ] || ask_yes_no "Install Sunshine system-wide from Flathub now?" "yes"; then
        install_sunshine_flatpak
    else
        info ""
        info "Install Sunshine from Batocera's Flatpak Manager, or run:"
        info "  flatpak install --system flathub ${APP_ID}"
        info ""
        fail "The system-wide Sunshine Flatpak is required before the service can be installed."
    fi
fi

TMP_DIR=$(mktemp -d /tmp/sunshine-service.XXXXXX)
trap 'rm -rf "${TMP_DIR}"' EXIT INT TERM

notice "Installing Sunshine service..."
fetch_files "${TMP_DIR}"

mkdir -p "${PROJECT_DIR}" "${SERVICE_DIR}" "${LOG_DIR}"
for file in ${FILES}; do
    install -m 0755 "${TMP_DIR}/${file}" "${PROJECT_DIR}/${file}"
done

install -m 0755 "${PROJECT_DIR}/sunshine" "${SERVICE_FILE}"
ok "Sunshine service installed"

if command -v batocera-services >/dev/null 2>&1; then
    if batocera-services enable sunshine >/dev/null 2>&1; then
        ok "SUNSHINE service enabled"
    else
        warn "Could not enable the service automatically."
        info "Enable SUNSHINE under MAIN MENU > SYSTEM SETTINGS > SERVICES."
    fi
else
    warn "batocera-services was not found; enable SUNSHINE from the Services menu."
fi

SUNSHINE_STARTED=0

if [ "${START_SERVICE}" -eq 1 ]; then
    if "${SERVICE_FILE}" start; then
        SUNSHINE_STARTED=1
        ok "Sunshine started"
    else
        warn "Sunshine did not start successfully."
        info "Run: ${PROJECT_DIR}/sunshine-diagnose"
    fi
else
    notice "Sunshine was not started because --no-start was used."
fi

ip_addr=$(get_ipv4 || true)

info ""
printf '%s\n' '----------------------------------------------------'
printf '%s\n' ' Installation complete'
printf '%s\n' '----------------------------------------------------'

if [ "${SUNSHINE_STARTED}" -eq 1 ]; then
    if [ -n "${ip_addr}" ]; then
        info ""
        info "Open the Sunshine Web UI:"
        info "  https://${ip_addr}:47990"
    fi
    info ""
    info "Complete the initial Sunshine setup in your browser."
    info "A warning about the self-signed certificate is expected."
    info ""
    info "If Sunshine reports a CSRF Protection Error, reproduce it once and run:"
    info "  ${PROJECT_DIR}/sunshine-csrf-setup"
else
    info ""
    info "Sunshine was installed but is not currently running."
    info "Start it with:"
    info "  ${SERVICE_FILE} start"
fi

info ""
info "Troubleshooting:"
info "  ${PROJECT_DIR}/sunshine-diagnose"
info ""
