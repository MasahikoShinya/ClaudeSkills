#!/bin/bash
# Open Cowork Chrome profile (macOS)
# Double-click this file to launch Chrome with the "Cowork" profile.
# If your profile has a different display name, change PROFILE_NAME below.

PROFILE_NAME="Cowork"
LOCAL_STATE="$HOME/Library/Application Support/Google/Chrome/Local State"
CHROME_APP="/Applications/Google Chrome.app"

# Check Chrome is installed
if [ ! -d "$CHROME_APP" ]; then
  osascript -e 'display alert "Google Chrome not found" message "Chrome is not installed at /Applications/Google Chrome.app" as critical'
  exit 1
fi

# Check Local State exists
if [ ! -f "$LOCAL_STATE" ]; then
  osascript -e 'display alert "Chrome Local State not found" message "Launch Chrome at least once first, then try again." as critical'
  exit 1
fi

# Find the profile directory name whose display name equals PROFILE_NAME
PROFILE_DIR=$(/usr/bin/python3 - <<PYEOF
import json
try:
    target = "$PROFILE_NAME".strip().lower()
    with open("$LOCAL_STATE") as f:
        data = json.load(f)
    for key, info in data.get("profile", {}).get("info_cache", {}).items():
        name = (info.get("name") or "").strip().lower()
        if name == target:
            print(key)
            break
except Exception:
    pass
PYEOF
)

if [ -z "$PROFILE_DIR" ]; then
  osascript -e "display alert \"Profile '$PROFILE_NAME' not found\" message \"Make sure you have a Chrome profile named '$PROFILE_NAME'. Edit PROFILE_NAME in this script if you used a different name.\" as critical"
  exit 1
fi

# Launch Chrome with the Cowork profile
open -na "Google Chrome" --args --profile-directory="$PROFILE_DIR"
