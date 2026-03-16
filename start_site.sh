#!/bin/bash

# Configuration
PROJECT_DIR="/home/telemazer/eirinchan-v1"
SCREEN_NAME="eirinchan4001"
export PORT=4001
export MIX_ENV=prod
export PHX_SERVER=true
export DATABASE_URL="ecto://eirinchan:eirinchan@localhost/eirinchan_dev"

# Generate a temporary secret if one isn't already set in the environment
if [ -z "$SECRET_KEY_BASE" ]; then
    export SECRET_KEY_BASE=$(cd $PROJECT_DIR && mix phx.gen.secret)
fi

echo "Stopping existing screen session: $SCREEN_NAME"
screen -S $SCREEN_NAME -X quit || true
sleep 1

echo "Starting site in screen..."
screen -dmS $SCREEN_NAME bash -lc "cd $PROJECT_DIR && mix phx.server"

echo "Done. Use 'screen -r $SCREEN_NAME' to view logs."
