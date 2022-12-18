#!/bin/bash
set -eoux pipefail

FACTORIO_VOL=/factorio
LOAD_LATEST_SAVE="${LOAD_LATEST_SAVE:-true}"
GENERATE_NEW_SAVE="${GENERATE_NEW_SAVE:-false}"
SAVE_NAME="${SAVE_NAME:-""}"
SAVES="$FACTORIO_VOL/saves"
CONFIG="$FACTORIO_VOL/config"
BIND="${BIND:-""}"

mkdir -p $SAVES $CONFIG $FACTORIO_VOL/mods $FACTORIO_VOL/scenarios $FACTORIO_VOL/script-output

if [[ ! -f $CONFIG/rconpw ]]; then
  # Generate a new RCON password if none exists
  pwgen 15 1 > $CONFIG/rconpw
fi

copy_default_config() {
    # Copy default settings if it doesn't exist
  CFG_FILE_NAME=$1
  if [[ ! -f $CONFIG/$CFG_FILE_NAME.json ]]; then
    cp "/opt/factorio/data/$CFG_FILE_NAME.example.json" "$CONFIG/$CFG_FILE_NAME.json"
fi
}

copy_default_config "server-settings"
copy_default_config "map-gen-settings"
copy_default_config "map-settings"


NRTMPSAVES=$( find -L "$SAVES" -iname \*.tmp.zip -mindepth 1 | wc -l )
if [[ $NRTMPSAVES -gt 0 ]]; then
  # Delete incomplete saves (such as after a forced exit)
  rm -f "$SAVES"/*.tmp.zip
fi

if [[ ${UPDATE_MODS_ON_START:-} == "true" ]]; then
  ./docker-update-mods.sh
fi

NRSAVES=$(find -L "$SAVES" -iname \*.zip -mindepth 1 | wc -l)
if [[ $GENERATE_NEW_SAVE != true && $NRSAVES ==  0 ]]; then
    GENERATE_NEW_SAVE=true
    SAVE_NAME=_autosave1
fi

if [[ $GENERATE_NEW_SAVE == true ]]; then
    if [[ -z "$SAVE_NAME" ]]; then
        echo "If \$GENERATE_NEW_SAVE is true, you must specify \$SAVE_NAME"
        exit 1
    fi
    if [[ -f "$SAVES/$SAVE_NAME.zip" ]]; then
        echo "Map $SAVES/$SAVE_NAME.zip already exists, skipping map generation"
    else
        /opt/factorio/bin/x64/factorio \
            --create "$SAVES/$SAVE_NAME.zip" \
            --map-gen-settings "$CONFIG/map-gen-settings.json" \
            --map-settings "$CONFIG/map-settings.json"
    fi
fi

FLAGS=(\
  --port "$PORT" \
  --server-settings "$CONFIG/server-settings.json" \
  --server-banlist "$CONFIG/server-banlist.json" \
  --rcon-port "$RCON_PORT" \
  --server-whitelist "$CONFIG/server-whitelist.json" \
  --use-server-whitelist \
  --server-adminlist "$CONFIG/server-adminlist.json" \
  --rcon-password "$(cat "$CONFIG/rconpw")" \
  --server-id "$CONFIG/server-id.json" \
)

if [ -n "$BIND" ]; then
  FLAGS+=( --bind "$BIND" )
fi

if [[ $LOAD_LATEST_SAVE == true ]]; then
    FLAGS+=( --start-server-load-latest )
else
    FLAGS+=( --start-server "$SAVE_NAME" )
fi

exec /opt/factorio/bin/x64/factorio "${FLAGS[@]}" "$@"
