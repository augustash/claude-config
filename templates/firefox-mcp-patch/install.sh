#!/bin/zsh
# Install the patched firefox-devtools MCP server.
#
# Upstream addresses tabs by POSITION (index into a flat list of every tab in
# every window) and rebuilds that whole list before every page operation. The
# patch adds addressing by pageId -- the Marionette window handle, which is
# stable for the tab's lifetime. See README.md.
set -e

DEST="${1:-$HOME/.local/share/firefox-devtools-mcp-patched}"
SRC="${0:A:h}"

mkdir -p "$DEST"
cp "$SRC/package.json" "$DEST/"
mkdir -p "$DEST/patches"
cp "$SRC"/patches/*.patch "$DEST/patches/"

cd "$DEST"
npm install

node --check node_modules/@mozilla/firefox-devtools-mcp/dist/index.js
print "Installed and patched at $DEST"
print ""
print "Point Claude Code at it (replaces any npx-based firefox-devtools entry):"
print ""
print "  claude mcp remove firefox-devtools --scope user 2>/dev/null"
print "  claude mcp add firefox-devtools --scope user -- \\"
print "    node $DEST/node_modules/@mozilla/firefox-devtools-mcp/dist/index.js \\"
print "    --toolPreset developer --connectExisting --marionettePort 2828"
