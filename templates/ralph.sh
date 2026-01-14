#!/bin/bash
# Ralph Wiggum - Autonomous AI Agent Loop for Claude Code
# Version: 2.0.0
#
# Usage: ./ralph.sh [max_iterations] [run_name]
#
# Examples:
#   ./ralph.sh 50                    # Auto-detect run from git branch
#   ./ralph.sh 50 frontdesk-fixes    # Use specific run directory
#   ./ralph.sh --version             # Show version
#   ./ralph.sh --help                # Show help
#
# Ralph runs Claude Code repeatedly until all PRD items are complete.
# Each iteration is a fresh Claude instance with clean context.
# Memory persists via git history, progress.txt, and prd.json.
#
# Run directories: scripts/ralph/runs/<run_name>/
# Each run is isolated to prevent accidental modifications by other agents.

RALPH_VERSION="2.0.0"
RALPH_TEMPLATE_DATE="2026-01-14"

set -e

# =============================================================================
# HELP AND VERSION
# =============================================================================

show_help() {
    echo "Ralph Wiggum - Autonomous AI Agent Loop for Claude Code"
    echo ""
    echo "Usage: ./ralph.sh [options] [max_iterations] [run_name]"
    echo ""
    echo "Options:"
    echo "  --help, -h       Show this help message"
    echo "  --version, -v    Show version information"
    echo "  --dry-run        Show what would happen without running"
    echo ""
    echo "Arguments:"
    echo "  max_iterations   Maximum iterations to run (default: 10)"
    echo "  run_name         Run directory name (default: auto-detect from branch)"
    echo ""
    echo "Examples:"
    echo "  ./ralph.sh 50                    # Run 50 iterations, auto-detect run"
    echo "  ./ralph.sh 50 my-feature         # Run 50 iterations on 'my-feature' run"
    echo "  ./ralph.sh --dry-run 50          # Show what would happen"
    echo ""
    echo "Run directories: scripts/ralph/runs/<run_name>/"
    echo "Config file: scripts/ralph/config (optional)"
}

show_version() {
    echo "Ralph Wiggum v$RALPH_VERSION ($RALPH_TEMPLATE_DATE)"
    echo ""
    echo "Template location: ~/.claude/templates/ralph/"
    echo "To update: /ralph sync"
}

# Parse options
DRY_RUN=false
while [[ "$1" == -* ]]; do
    case "$1" in
        --help|-h)
            show_help
            exit 0
            ;;
        --version|-v)
            show_version
            exit 0
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

MAX_ITERATIONS=${1:-10}
RUN_NAME=${2:-""}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MONOREPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"

# =============================================================================
# LOAD CONFIG FILE (if exists)
# =============================================================================

CONFIG_FILE="$SCRIPT_DIR/config"

# Defaults
NOTIFICATIONS_ENABLED=false
TEXTMEBOT_API_KEY=""
TEXTMEBOT_PHONE=""
CLAUDE_FLAGS="--dangerously-skip-permissions"

# Load config if exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# =============================================================================
# NOTIFICATIONS
# =============================================================================

notify() {
    local message="$1"

    # WhatsApp via TextMeBot
    if [ "$NOTIFICATIONS_ENABLED" = true ] && [ -n "$TEXTMEBOT_API_KEY" ] && [ -n "$TEXTMEBOT_PHONE" ]; then
        local encoded_message=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$message'''))" 2>/dev/null || echo "$message")
        curl -s "https://api.textmebot.com/send.php?recipient=${TEXTMEBOT_PHONE}&apikey=${TEXTMEBOT_API_KEY}&text=${encoded_message}" > /dev/null 2>&1 &
    fi
}

# =============================================================================
# DETERMINE RUN DIRECTORY
# =============================================================================

# If no run name provided, try to detect from current branch
if [ -z "$RUN_NAME" ]; then
    CURRENT_BRANCH=$(cd "$MONOREPO_ROOT" && git branch --show-current 2>/dev/null || echo "")

    # Extract run name from branch (e.g., "ralph/frontdesk-fixes" -> "frontdesk-fixes")
    if [[ "$CURRENT_BRANCH" == ralph/* ]]; then
        RUN_NAME="${CURRENT_BRANCH#ralph/}"
    else
        # Check if there's only one run directory
        if [ -d "$SCRIPT_DIR/runs" ]; then
            RUN_COUNT=$(ls -d "$SCRIPT_DIR/runs"/*/ 2>/dev/null | wc -l | tr -d ' ')
            if [ "$RUN_COUNT" -eq 1 ]; then
                RUN_NAME=$(basename "$(ls -d "$SCRIPT_DIR/runs"/*/ 2>/dev/null)")
            elif [ "$RUN_COUNT" -eq 0 ]; then
                echo "ERROR: No run directories found in $SCRIPT_DIR/runs/"
                echo ""
                echo "To create a new run, use: /ralph init <run-name>"
                exit 1
            else
                echo "ERROR: Cannot determine run directory."
                echo "Either:"
                echo "  1. Be on a ralph/* branch (e.g., ralph/frontdesk-fixes)"
                echo "  2. Specify run name: ./ralph.sh 50 frontdesk-fixes"
                echo ""
                echo "Available runs:"
                ls -d "$SCRIPT_DIR/runs"/*/ 2>/dev/null | xargs -I {} basename {} || echo "  (none)"
                exit 1
            fi
        else
            echo "ERROR: No runs directory found at $SCRIPT_DIR/runs/"
            echo ""
            echo "To initialize Ralph, use: /ralph init <run-name>"
            exit 1
        fi
    fi
fi

RUN_DIR="$SCRIPT_DIR/runs/$RUN_NAME"

# Verify run directory exists
if [ ! -d "$RUN_DIR" ]; then
    echo "ERROR: Run directory not found: $RUN_DIR"
    echo ""
    echo "Available runs:"
    ls -d "$SCRIPT_DIR/runs"/*/ 2>/dev/null | xargs -I {} basename {} || echo "  (none)"
    echo ""
    echo "To create a new run, use: /ralph init $RUN_NAME"
    exit 1
fi

PRD_FILE="$RUN_DIR/prd.json"
PROGRESS_FILE="$RUN_DIR/progress.txt"
PROMPT_FILE="$RUN_DIR/prompt.md"
PATTERNS_FILE="$SCRIPT_DIR/patterns.md"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
LAST_BRANCH_FILE="$RUN_DIR/.last-branch"

# =============================================================================
# PRE-FLIGHT CHECKS
# =============================================================================

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  RALPH WIGGUM v$RALPH_VERSION - Autonomous AI Agent Loop"
echo "═══════════════════════════════════════════════════════"
echo ""

# Check Claude CLI is available
if ! command -v claude &> /dev/null; then
    echo "ERROR: Claude CLI not found."
    echo ""
    echo "Install Claude Code CLI:"
    echo "  npm install -g @anthropic-ai/claude-code"
    echo ""
    echo "Or visit: https://claude.ai/code"
    exit 1
fi

# Check prd.json exists
if [ ! -f "$PRD_FILE" ]; then
    echo "ERROR: PRD file not found at $PRD_FILE"
    echo ""
    echo "Create a prd.json with your user stories first."
    echo "Use: /ralph convert <prd-file.md>"
    exit 1
fi

# Check prompt.md exists
if [ ! -f "$PROMPT_FILE" ]; then
    echo "ERROR: Prompt file not found at $PROMPT_FILE"
    echo ""
    echo "Run: /ralph init $RUN_NAME"
    exit 1
fi

# Validate prd.json is valid JSON
if ! jq empty "$PRD_FILE" 2>/dev/null; then
    echo "ERROR: prd.json is not valid JSON"
    echo ""
    echo "Check syntax at: $PRD_FILE"
    exit 1
fi

# Get branch from PRD
PRD_BRANCH=$(jq -r '.branchName // empty' "$PRD_FILE" 2>/dev/null || echo "")
if [ -z "$PRD_BRANCH" ]; then
    echo "ERROR: prd.json missing 'branchName' field"
    echo ""
    echo "Add to $PRD_FILE:"
    echo '  "branchName": "ralph/your-feature-name"'
    exit 1
fi

# Check current git branch matches PRD
cd "$MONOREPO_ROOT"
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "$PRD_BRANCH" ]; then
    echo "WARNING: Current branch ($CURRENT_BRANCH) doesn't match PRD branch ($PRD_BRANCH)"
    echo ""
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY RUN] Would prompt to switch branches"
    else
        read -p "Switch to $PRD_BRANCH? (y/n) " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git checkout "$PRD_BRANCH" 2>/dev/null || git checkout -b "$PRD_BRANCH"
        else
            echo "Continuing on $CURRENT_BRANCH..."
        fi
    fi
fi

# =============================================================================
# ARCHIVE PREVIOUS RUN (if branch changed)
# =============================================================================

if [ -f "$LAST_BRANCH_FILE" ]; then
    LAST_BRANCH=$(cat "$LAST_BRANCH_FILE" 2>/dev/null || echo "")

    if [ -n "$LAST_BRANCH" ] && [ "$PRD_BRANCH" != "$LAST_BRANCH" ]; then
        # Check for uncommitted changes before archiving
        if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
            echo "WARNING: Uncommitted changes detected."
            echo "Commit or stash changes before switching PRDs to avoid losing work."
            if [ "$DRY_RUN" = true ]; then
                echo "[DRY RUN] Would prompt to continue"
            else
                read -p "Continue anyway? (y/n) " -n 1 -r
                echo ""
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    exit 1
                fi
            fi
        fi

        # Archive the previous run
        DATE=$(date +%Y-%m-%d)
        FOLDER_NAME=$(echo "$LAST_BRANCH" | sed 's|^ralph/||' | sed 's|/|-|g')
        ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

        echo "Archiving previous run: $LAST_BRANCH"
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$ARCHIVE_FOLDER"
            [ -f "$PRD_FILE" ] && cp "$PRD_FILE" "$ARCHIVE_FOLDER/"
            [ -f "$PROGRESS_FILE" ] && cp "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"
            echo "   Archived to: $ARCHIVE_FOLDER"

            # Preserve patterns - copy to patterns.md if not already there
            if [ -f "$PROGRESS_FILE" ]; then
                # Extract Codebase Patterns section and append to patterns.md
                PATTERNS=$(sed -n '/^## Codebase Patterns/,/^---$/p' "$PROGRESS_FILE" | head -n -1)
                if [ -n "$PATTERNS" ] && [ -f "$PATTERNS_FILE" ]; then
                    echo "" >> "$PATTERNS_FILE"
                    echo "<!-- From $LAST_BRANCH -->" >> "$PATTERNS_FILE"
                    echo "$PATTERNS" >> "$PATTERNS_FILE"
                fi
            fi

            # Reset progress file for new run (with patterns header)
            echo "## Codebase Patterns" > "$PROGRESS_FILE"
            echo "" >> "$PROGRESS_FILE"
            if [ -f "$PATTERNS_FILE" ]; then
                echo "See patterns.md for accumulated patterns from previous runs." >> "$PROGRESS_FILE"
            fi
            echo "" >> "$PROGRESS_FILE"
            echo "---" >> "$PROGRESS_FILE"
            echo "" >> "$PROGRESS_FILE"
            echo "# Ralph Progress Log" >> "$PROGRESS_FILE"
            echo "Started: $(date)" >> "$PROGRESS_FILE"
            echo "Branch: $PRD_BRANCH" >> "$PROGRESS_FILE"
            echo "" >> "$PROGRESS_FILE"
        else
            echo "[DRY RUN] Would archive to: $ARCHIVE_FOLDER"
        fi
    fi
fi

# Track current branch
if [ "$DRY_RUN" = false ]; then
    echo "$PRD_BRANCH" > "$LAST_BRANCH_FILE"
fi

# Initialize progress file if it doesn't exist
if [ ! -f "$PROGRESS_FILE" ] && [ "$DRY_RUN" = false ]; then
    echo "## Codebase Patterns" > "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
    echo "---" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
    echo "# Ralph Progress Log" >> "$PROGRESS_FILE"
    echo "Started: $(date)" >> "$PROGRESS_FILE"
    echo "Branch: $PRD_BRANCH" >> "$PROGRESS_FILE"
    echo "" >> "$PROGRESS_FILE"
fi

# Initialize patterns file if it doesn't exist
if [ ! -f "$PATTERNS_FILE" ] && [ "$DRY_RUN" = false ]; then
    echo "# Persistent Codebase Patterns" > "$PATTERNS_FILE"
    echo "" >> "$PATTERNS_FILE"
    echo "> Patterns accumulated across all Ralph runs. Never deleted." >> "$PATTERNS_FILE"
    echo "" >> "$PATTERNS_FILE"
fi

# =============================================================================
# SHOW STATUS
# =============================================================================

TOTAL_STORIES=$(jq '.userStories | length' "$PRD_FILE")
COMPLETED_STORIES=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")
REMAINING_STORIES=$((TOTAL_STORIES - COMPLETED_STORIES))

echo "Project Root:   $MONOREPO_ROOT"
echo "Run Directory:  $RUN_DIR"
echo "PRD:            $PRD_FILE"
echo "Branch:         $PRD_BRANCH"
echo "Stories:        $COMPLETED_STORIES/$TOTAL_STORIES complete ($REMAINING_STORIES remaining)"
echo "Max iterations: $MAX_ITERATIONS"
echo "Notifications:  $([ "$NOTIFICATIONS_ENABLED" = true ] && echo "enabled" || echo "disabled")"
echo ""

if [ "$REMAINING_STORIES" -eq 0 ]; then
    echo "All stories already complete!"
    notify "✅ Ralph: All $TOTAL_STORIES stories already complete."
    exit 0
fi

if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would run $MAX_ITERATIONS iterations"
    echo "[DRY RUN] Command: cat \"$PROMPT_FILE\" | claude $CLAUDE_FLAGS -p"
    exit 0
fi

# =============================================================================
# MAIN LOOP
# =============================================================================

notify "🚀 Ralph starting: $REMAINING_STORIES stories remaining"

for i in $(seq 1 $MAX_ITERATIONS); do
    echo ""
    echo "═══════════════════════════════════════════════════════"
    echo "  Ralph Iteration $i of $MAX_ITERATIONS"
    echo "═══════════════════════════════════════════════════════"

    # CRITICAL: Run Claude from project root so all paths resolve correctly
    cd "$MONOREPO_ROOT"

    # Unset ANTHROPIC_API_KEY to force OAuth authentication (Claude Code Max)
    unset ANTHROPIC_API_KEY

    # Run Claude with the ralph prompt from run directory
    OUTPUT=$(cat "$PROMPT_FILE" | claude $CLAUDE_FLAGS -p 2>&1 | tee /dev/stderr) || true

    # Get updated story count after iteration
    COMPLETED_NOW=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")

    # Check for completion signal
    if echo "$OUTPUT" | grep -q "<promise>COMPLETE</promise>"; then
        echo ""
        echo "═══════════════════════════════════════════════════════"
        echo "  RALPH COMPLETE!"
        echo "  All stories done at iteration $i of $MAX_ITERATIONS"
        echo "═══════════════════════════════════════════════════════"
        notify "🎉 Ralph Complete! All $TOTAL_STORIES stories done in $i iterations."
        exit 0
    fi

    # Notify progress after each iteration
    notify "📦 Ralph iteration $i: $COMPLETED_NOW/$TOTAL_STORIES stories complete"

    echo ""
    echo "Iteration $i complete. Stories: $COMPLETED_NOW/$TOTAL_STORIES"
    sleep 2
done

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Ralph reached max iterations ($MAX_ITERATIONS)"
echo "  Stories: $COMPLETED_NOW/$TOTAL_STORIES complete"
echo "  Progress: $PROGRESS_FILE"
echo "═══════════════════════════════════════════════════════"
notify "⚠️ Ralph stopped: max iterations ($MAX_ITERATIONS). $COMPLETED_NOW/$TOTAL_STORIES stories."
exit 1
