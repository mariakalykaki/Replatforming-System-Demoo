#!/usr/bin/env bash
# Generates a standalone, runnable example project by copying this blank
# scaffold and layering example-specific business logic on top. The blank
# scaffold itself is left untouched - this only ever writes to the target
# directory.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

EXAMPLE_NAME="${1:-pizza-maker-simulator}"
TARGET_DIR="${2:-$BASE_DIR/../$EXAMPLE_NAME}"
OVERLAY_DIR="$BASE_DIR/examples/$EXAMPLE_NAME/overlay"

if [ ! -d "$OVERLAY_DIR" ]; then
  echo "No such example: '$EXAMPLE_NAME' (looked for $OVERLAY_DIR)" >&2
  echo "Available examples:" >&2
  ls -1 "$BASE_DIR/examples" 2>/dev/null | sed 's/^/  - /' >&2
  exit 1
fi

if [ -e "$TARGET_DIR" ]; then
  echo "Refusing to overwrite existing directory: $TARGET_DIR" >&2
  echo "Pass a different target, e.g.: ./scripts/create-example.sh $EXAMPLE_NAME ../pizza-try-2" >&2
  exit 1
fi

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync is required but not found on PATH." >&2
  echo "macOS/Linux ship it by default; on native Windows use WSL2 or Git Bash with rsync installed." >&2
  exit 1
fi

echo "Creating '$EXAMPLE_NAME' at: $TARGET_DIR"
mkdir -p "$TARGET_DIR"

# 1. Copy the blank scaffold itself (not its own build output, git metadata,
#    or the examples/scripts machinery used to generate this project).
rsync -a \
  --exclude target/ \
  --exclude .git/ \
  --exclude examples/ \
  --exclude scripts/ \
  "$BASE_DIR/" "$TARGET_DIR/"

# 2. Layer the example's business logic on top.
rsync -a "$OVERLAY_DIR/" "$TARGET_DIR/"

# 3. The blank scaffold's .gitkeep placeholders (one per empty package) are
#    no longer needed in any directory the overlay just populated with real
#    code - drop them so the generated project doesn't look half-empty.
find "$TARGET_DIR/src/main/java" -name .gitkeep -print0 | while IFS= read -r -d '' gitkeep; do
  dir="$(dirname "$gitkeep")"
  if [ "$(find "$dir" -mindepth 1 | wc -l)" -gt 1 ]; then
    rm -f "$gitkeep"
  fi
done

cat <<EOF

Done. Next steps:

  cd $TARGET_DIR
  make up
  mvn quarkus:dev

Then see docs/$([ "$EXAMPLE_NAME" = "pizza-maker-simulator" ] && echo PIZZA-EXAMPLE.md || echo FIRST-STEPS.md) for what to try.
EOF
