#!/bin/bash
# Install the "Convert to DNG with X3Fuse" Finder Quick Action for the current user.
#
# The Quick Action lives in Finder/Convert to DNG with X3Fuse.workflow. It hands the
# selected X3F files (or folders of them) to /Applications/X3Fuse.app through the
# x3fuse://convert URL scheme, so it needs a build of X3Fuse that registers that scheme
# (fork release 0.1.5-dp2q-fix.9 or later).
#
# Usage: ./scripts/install_quick_action.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME="Convert to DNG with X3Fuse.workflow"
SOURCE="$REPO_ROOT/Finder/$NAME"
DEST_DIR="$HOME/Library/Services"
DEST="$DEST_DIR/$NAME"

if [ ! -d "$SOURCE" ]; then
  echo "error: $SOURCE not found" >&2
  exit 1
fi

mkdir -p "$DEST_DIR"
if [ -d "$DEST" ]; then
  ditto "$SOURCE" "$DEST"
  echo "Updated $DEST"
else
  ditto "$SOURCE" "$DEST"
  echo "Installed $DEST"
fi

# Ask the Services manager to pick the new item up without logging out.
/System/Library/CoreServices/pbs -update >/dev/null 2>&1 || true

if [ -d /Applications/X3Fuse.app ]; then
  # Make sure Launch Services knows the installed app handles x3fuse:// URLs.
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f /Applications/X3Fuse.app >/dev/null 2>&1 || true
else
  echo "note: /Applications/X3Fuse.app not found; the Quick Action will fall back to whichever X3Fuse Launch Services knows about."
fi

cat <<'EOF'

Done. In Finder, right-click one or more .X3F files (or a folder of them) and choose
Quick Actions → Convert to DNG with X3Fuse. If it does not appear, enable it under
System Settings → General → Login Items & Extensions → Extensions → Finder.
EOF
