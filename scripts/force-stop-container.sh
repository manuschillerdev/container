#!/bin/bash
# Copyright © 2025-2026 Apple Inc. and the container project authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# force-stop-container.sh - Force stop Apple/container dev build processes deterministically

set -e

PROJECT_DIR="${1:-$(pwd)}"

echo "Stopping Apple/container dev build processes in $PROJECT_DIR..."

# -----------------------------
# Reusable function: stop_processes
# -----------------------------
# Arguments:
#   $1 - name/regex pattern of process to stop
#   $2 - optional timeout in seconds for graceful shutdown (default 5)
stop_processes() {
    local pattern="$1"
    local timeout="${2:-5}"
    local elapsed=0

    pkill -15 -f "$pattern" 2>/dev/null || true

    while pgrep -f "$pattern" > /dev/null && (( $(echo "$elapsed < $timeout" | bc -l) )); do
        sleep 0.2
        elapsed=$(echo "$elapsed + 0.2" | bc)
    done

    pkill -9 -f "$pattern" 2>/dev/null || true
}

# -----------------------------
# Kill project-specific build processes
# -----------------------------
stop_processes "${PROJECT_DIR}/bin/container"
stop_processes "${PROJECT_DIR}/.build/.*/container"
stop_processes "${PROJECT_DIR}/bin/container-apiserver"
stop_processes "${PROJECT_DIR}/.build/.*/container-apiserver"
stop_processes "${PROJECT_DIR}/libexec/container"

# Kill Swift test processes for this project
stop_processes "swift test.*${PROJECT_DIR}"
stop_processes "containerPackageTests"

# -----------------------------
# Detect launchd domain
# -----------------------------
# macOS has three service domains based on session type:
# - System: system-level services (run as root)
# - Aqua: GUI session services (user logged in via GUI)
# - Background: background/SSH session services
launchd_domain=$(launchctl managername)
if [[ "$launchd_domain" == "System" ]]; then
    domain_string="system"
elif [[ "$launchd_domain" == "Aqua" ]]; then
    domain_string="gui/$(id -u)"
elif [[ "$launchd_domain" == "Background" ]]; then
    domain_string="user/$(id -u)"
else
    echo "Warning: Unknown launchd domain '$launchd_domain', trying gui/$(id -u)"
    domain_string="gui/$(id -u)"
fi

# -----------------------------
# Unload related launchctl services
# -----------------------------
echo "Unloading launchctl services from $domain_string..."
for svc in \
    com.apple.container.apiserver \
    com.apple.container.container-network-vmnet.default \
    com.apple.container.container-core-images; do
    launchctl bootout "$domain_string/$svc" 2>/dev/null || true
done

# -----------------------------
# Verification
# -----------------------------
if launchctl list 2>/dev/null | grep -q 'com\.apple\.container\.apiserver'; then
    echo "Warning: apiserver still registered in launchctl"
    exit 1
fi

echo "Done."
