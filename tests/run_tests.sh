#!/bin/bash
# amalgame-ui-forms — Test Runner. Requires amc 0.8.0+, amalgame-ui-sdl, SDL2 dev headers.
set -u

if [ $# -ge 1 ]; then AMC="$1"
elif [ -n "${AMC:-}" ]; then :
elif command -v amc >/dev/null 2>&1; then AMC="$(command -v amc)"
else echo "ERROR: amc not found." >&2; exit 2
fi
[ -x "$AMC" ] || { echo "ERROR: amc not executable: $AMC" >&2; exit 2; }
AMC="$(cd "$(dirname "$AMC")" && pwd)/$(basename "$AMC")"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PKG_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AMC_DIR="$(cd "$(dirname "$AMC")" && pwd)"
if [ -d "$AMC_DIR/runtime" ]; then AMC_RUNTIME="$AMC_DIR/runtime"
elif [ -d "$AMC_DIR/../share/amalgame/runtime" ]; then AMC_RUNTIME="$AMC_DIR/../share/amalgame/runtime"
elif [ -n "${AMC_RUNTIME:-}" ]; then :
else echo "ERROR: amc runtime/ not found." >&2; exit 2; fi

# amalgame-ui-sdl sibling checkout (CI checks both repos out side-by-side).
# Locally, point at ../amalgame-ui-sdl/.
UI_SDL_ROOT="${UI_SDL_ROOT:-$PKG_ROOT/../amalgame-ui-sdl}"
if [ ! -f "$UI_SDL_ROOT/runtime/Amalgame_UI.h" ]; then
    echo "ERROR: amalgame-ui-sdl runtime header not found at: $UI_SDL_ROOT/runtime/Amalgame_UI.h" >&2
    echo "Set UI_SDL_ROOT to its checkout location, or clone it next to this repo." >&2
    exit 2
fi
UI_SDL_RUNTIME="$UI_SDL_ROOT/runtime"

# SDL2 headers must be discoverable. Try pkg-config first.
SDL_CFLAGS=""
SDL_LIBS="-lSDL2 -lSDL2_ttf"
if command -v pkg-config >/dev/null 2>&1; then
    if pkg-config --exists sdl2 2>/dev/null; then
        SDL_CFLAGS="$(pkg-config --cflags sdl2 SDL2_ttf 2>/dev/null || pkg-config --cflags sdl2)"
        SDL_LIBS="$(pkg-config --libs sdl2 SDL2_ttf 2>/dev/null || pkg-config --libs sdl2) -lSDL2_ttf"
    fi
fi

BUILD_DIR="$(mktemp -d -t auf-tests-XXXXXX)"
trap 'rm -rf "$BUILD_DIR"' EXIT
PROJ_DIR="$BUILD_DIR/proj"
mkdir -p "$PROJ_DIR"

GREEN='\033[0;32m'; RED='\033[0;31m'; YELLOW='\033[0;33m'; NC='\033[0m'
PASS=0; FAIL=0; SKIP=0

echo ""
echo "════════════════════════════════════════════"
echo "  amalgame-ui-forms — Test Suite"
echo "════════════════════════════════════════════"
echo "  amc:       $AMC ($("$AMC" --version 2>&1 | head -1))"
echo "  package:   $PKG_ROOT"
echo "  ui-sdl:    $UI_SDL_ROOT"
echo "  runtime:   $AMC_RUNTIME"
echo "  sdl:       $SDL_LIBS"

FAKE_CACHE="$BUILD_DIR/cache"
PKG_GIT_FORMS="github.com/amalgame-lang/amalgame-ui-forms"
PKG_GIT_SDL="github.com/amalgame-lang/amalgame-ui-sdl"
PKG_TAG="${PKG_TAG:-v0.0.2-dev}"
FAKE_SHA="deadbeefcafebabe0000000000000000000000ab"
SHORT_SHA="${FAKE_SHA:0:8}"
FORMS_CACHE_DIR="$FAKE_CACHE/$PKG_GIT_FORMS/${PKG_TAG}_${SHORT_SHA}"
SDL_CACHE_DIR="$FAKE_CACHE/$PKG_GIT_SDL/${PKG_TAG}_${SHORT_SHA}"
mkdir -p "$(dirname "$FORMS_CACHE_DIR")" "$(dirname "$SDL_CACHE_DIR")"
ln -s "$PKG_ROOT" "$FORMS_CACHE_DIR"
ln -s "$UI_SDL_ROOT" "$SDL_CACHE_DIR"

cat > "$PROJ_DIR/amalgame.lock" <<EOF
[[package]]
name = "amalgame-ui-sdl"
git  = "$PKG_GIT_SDL"
tag  = "$PKG_TAG"
rev  = "$FAKE_SHA"

[[package]]
name = "amalgame-ui-forms"
git  = "$PKG_GIT_FORMS"
tag  = "$PKG_TAG"
rev  = "$FAKE_SHA"
EOF
export AMALGAME_PACKAGES_DIR="$FAKE_CACHE"
echo "  cache:     $FAKE_CACHE"
echo ""

# ── Pre-build a combined facade archive ──
# amc --lib in standalone mode doesn't load the lockfile, so we
# can't compile ui-forms' facade alone — it references OSTheme /
# Color from ui-sdl and the resolver bails on "Unknown symbol".
# Pass BOTH facade.am files in one amc invocation so all
# cross-package types resolve in a single AST. The resulting
# archive carries every symbol the test binary needs (Color/
# Rect/Window/Event/Font/OSTheme/EventKind from ui-sdl, plus
# Theme/Widget/Label/Button/Form/Application from ui-forms).
FACADE_BUILD_DIR="$BUILD_DIR/facade"
mkdir -p "$FACADE_BUILD_DIR"
COMBINED_ARCHIVE="$FACADE_BUILD_DIR/libamalgame-pkg-ui-forms.a"
echo "── Pre-compiling ui-sdl + ui-forms facades → $(basename "$COMBINED_ARCHIVE") ──"
"$AMC" --lib --quiet \
    "$UI_SDL_ROOT/facade.am" \
    "$PKG_ROOT/facade.am" \
    -o "$FACADE_BUILD_DIR/ui-forms-combined" 2>&1 | head -5
if [ ! -f "$FACADE_BUILD_DIR/ui-forms-combined.c" ]; then
    echo "ERROR: amc failed to emit ui-forms-combined.c" >&2; exit 1
fi
gcc -O2 -I"$AMC_RUNTIME" -I"$UI_SDL_RUNTIME" $SDL_CFLAGS -w -c \
    "$FACADE_BUILD_DIR/ui-forms-combined.c" \
    -o "$FACADE_BUILD_DIR/ui-forms-combined.o" 2>&1 | head -10
if [ ! -f "$FACADE_BUILD_DIR/ui-forms-combined.o" ]; then
    echo "ERROR: gcc failed to build ui-forms-combined.o" >&2; exit 1
fi
ar rcs "$COMBINED_ARCHIVE" "$FACADE_BUILD_DIR/ui-forms-combined.o"

echo "  built: $COMBINED_ARCHIVE"
echo ""

run_test() {
    local name="$1"; local expected="$2"
    printf "  %-38s" "$name"
    cp "$SCRIPT_DIR/stdlib_ui_forms.am" "$PROJ_DIR/test.am"
    local out_base="$PROJ_DIR/test"
    local out
    out=$(cd "$PROJ_DIR" && "$AMC" -o test test.am --quiet 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}FAIL${NC} (amc error)"
        echo "$out" | head -5 | sed 's/^/    /'
        FAIL=$((FAIL + 1)); return
    fi
    if [ ! -f "$out_base.c" ]; then echo -e "${RED}FAIL${NC} (no .c)"; FAIL=$((FAIL + 1)); return; fi
    local gcc_log
    # Link order: test.c + combined facade archive (carries both
    # ui-sdl and ui-forms symbols) + system libs.
    gcc_log=$(gcc -O2 -I"$AMC_RUNTIME" -I"$UI_SDL_RUNTIME" $SDL_CFLAGS "$out_base.c" \
        "$COMBINED_ARCHIVE" \
        -lgc -lm -lcurl -lz -ldl -lpthread $SDL_LIBS -o "$out_base" 2>&1)
    if [ ! -x "$out_base" ]; then
        echo -e "${RED}FAIL${NC} (link)"
        # Larger window than head -5 so undefined-ref errors at
        # the tail of the gcc/ld output aren't hidden behind
        # leading warnings.
        echo "$gcc_log" | head -30 | sed 's/^/    /'
        FAIL=$((FAIL + 1)); return
    fi
    local run_output
    run_output=$("$out_base" 2>&1)
    if echo "$run_output" | grep -qF "$expected"; then
        echo -e "${GREEN}PASS${NC}"; PASS=$((PASS + 1))
    else
        echo -e "${RED}FAIL${NC} (mismatch)"
        echo "    expected: $expected"
        echo "    got:      $(echo "$run_output" | head -3 | tr '\n' '|')"
        FAIL=$((FAIL + 1))
    fi
}

echo "── Amalgame.UI.Forms ──────────────────────"
run_test "Theme.Light surface white"       "[PASS] Theme.Light surface white"
run_test "Theme.Dark background dark"      "[PASS] Theme.Dark background dark"
run_test "Theme.FromOS non-null"           "[PASS] Theme.FromOS non-null"
run_test "Widget hit-test"                 "[PASS] Widget hit-test"
run_test "Label widget"                    "[PASS] Label widget"
run_test "Button widget + OnClick"         "[PASS] Button widget + OnClick"
run_test "Form add + child count"          "[PASS] Form add + child count"
run_test "Form.Close sets ShouldClose"     "[PASS] Form.Close sets ShouldClose"

echo ""
echo "────────────────────────────────────────────"
echo -e "  ${GREEN}PASS: $PASS${NC}  |  ${RED}FAIL: $FAIL${NC}  |  ${YELLOW}SKIP: $SKIP${NC}"
echo "────────────────────────────────────────────"
echo ""
[ $FAIL -eq 0 ] && exit 0 || exit 1
