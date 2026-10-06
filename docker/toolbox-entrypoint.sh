#!/bin/sh
set -eu

# agy 1.3.0 ignores the OS keyring when this Docker marker exists, even
# with a working session bus. Keep the marker in /tmp for diagnostics.
# Only apply the workaround when host keyring access is configured.
if [ "${DBUS_SESSION_BUS_ADDRESS:-}" = "unix:path=/tmp/host-session-bus" ] \
    && [ -S /tmp/host-session-bus ] \
    && [ -f /.dockerenv ]; then
    sudo -n mv /.dockerenv /tmp/toolbox-dockerenv
fi

exec "$@"
