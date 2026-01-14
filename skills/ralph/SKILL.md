---
name: ralph
description: "Ralph autonomous agent system. Just run /ralph and it handles everything - auto-detects setup, initializes if needed, syncs templates, and guides you to work on the PRD. Triggers on: /ralph, ralph, run ralph, setup ralph."
---

# Ralph - Autonomous AI Agent Loop

Ralph runs Claude Code repeatedly until all PRD items are complete. **Just run `/ralph` and it handles everything automatically.**

---

## How To Use

```bash
/ralph
```

That's it. The skill will:
1. Auto-detect if Ralph is set up in your project
2. Auto-initialize if not (creates everything)
3. Auto-sync templates if outdated
4. Auto-detect run name from git branch
5. Guide you to work on the PRD

---

## What You Do (When This Skill Runs)

### Step 1: Detect Project State

Check if Ralph is set up in this project:

```bash
# Check for ralph directory
ls -la scripts/ralph/ 2>/dev/null

# Check for ralph.sh
ls -la scripts/ralph/ralph.sh 2>/dev/null

# Get current git branch
git branch --show-current
```

### Step 2: Auto-Initialize (If New Project)

If `scripts/ralph/` doesn't exist, create everything:

```bash
# Create directory structure
mkdir -p scripts/ralph/runs

# Get run name from branch (ralph/feature-name -> feature-name)
BRANCH=$(git branch --show-current)
if [[ "$BRANCH" == ralph/* ]]; then
    RUN_NAME="${BRANCH#ralph/}"
else
    # Ask user for run name if not on ralph/* branch
    RUN_NAME="default"
fi

mkdir -p "scripts/ralph/runs/$RUN_NAME"
```

Then copy templates from `~/.claude/templates/ralph/`:

| Source | Destination |
|--------|-------------|
| `ralph.sh` | `scripts/ralph/ralph.sh` |
| `config.template` | `scripts/ralph/config` |
| `patterns.md.template` | `scripts/ralph/patterns.md` |
| `prompt.md` | `scripts/ralph/runs/$RUN_NAME/prompt.md` |
| `progress.txt.template` | `scripts/ralph/runs/$RUN_NAME/progress.txt` |
| `prd.json.example` | `scripts/ralph/runs/$RUN_NAME/prd.json` |

**Replace placeholders** in copied files:
- `{{RUN_NAME}}` → actual run name
- `{{DATE}}` → current date
- `{{BRANCH_NAME}}` → current git branch

**Make executable:**
```bash
chmod +x scripts/ralph/ralph.sh
```

### Step 3: Auto-Sync (If Existing Project)

If Ralph exists, check version and sync if needed:

```bash
# Get template version
TEMPLATE_VERSION=$(cat ~/.claude/templates/ralph/VERSION)

# Get project version (from ralph.sh)
PROJECT_VERSION=$(grep 'RALPH_VERSION=' scripts/ralph/ralph.sh | cut -d'"' -f2)

NEEDS_SYNC=false

# Check version mismatch
if [ "$TEMPLATE_VERSION" != "$PROJECT_VERSION" ]; then
    NEEDS_SYNC=true
fi

# Also check for outdated content in prompt.md (e.g., chrome-devtools instead of Playwright)
for run_dir in scripts/ralph/runs/*/; do
    if [ -f "$run_dir/prompt.md" ]; then
        if grep -q "chrome-devtools" "$run_dir/prompt.md" 2>/dev/null; then
            echo "⚠️  Detected outdated prompt.md (uses chrome-devtools instead of Playwright)"
            NEEDS_SYNC=true
        fi
        if grep -q "dev-browser" "$run_dir/prompt.md" 2>/dev/null; then
            echo "⚠️  Detected outdated prompt.md (uses dev-browser instead of Playwright MCP)"
            NEEDS_SYNC=true
        fi
    fi
done

if [ "$NEEDS_SYNC" = true ]; then
    # Update ralph.sh
    cp ~/.claude/templates/ralph/ralph.sh scripts/ralph/ralph.sh
    chmod +x scripts/ralph/ralph.sh

    # Update prompt.md in all run directories
    for run_dir in scripts/ralph/runs/*/; do
        cp ~/.claude/templates/ralph/prompt.md "$run_dir/prompt.md"
        # Replace {{RUN_NAME}} placeholder
        RUN_NAME=$(basename "$run_dir")
        sed -i '' "s/{{RUN_NAME}}/$RUN_NAME/g" "$run_dir/prompt.md"
    done

    echo "✅ Synced templates to v$TEMPLATE_VERSION"
    echo "   - ralph.sh updated"
    echo "   - prompt.md updated (now uses Playwright MCP)"
fi
```

**What gets UPDATED (replaced with latest):**
- `ralph.sh` - Runner script with latest features
- `prompt.md` - Agent instructions with Playwright MCP, quality checklist, forbidden strings

**What gets PRESERVED (your data):**
- `prd.json` - Your stories and progress
- `progress.txt` - Your learnings from iterations
- `patterns.md` - Accumulated patterns across runs
- `config` - Your notification settings

### Step 4: Detect Run Directory

Find or create the run directory:

```bash
BRANCH=$(git branch --show-current)

# If on ralph/* branch, use that as run name
if [[ "$BRANCH" == ralph/* ]]; then
    RUN_NAME="${BRANCH#ralph/}"
    RUN_DIR="scripts/ralph/runs/$RUN_NAME"

    # Create if doesn't exist
    if [ ! -d "$RUN_DIR" ]; then
        mkdir -p "$RUN_DIR"
        # Copy templates for new run
        cp ~/.claude/templates/ralph/prompt.md "$RUN_DIR/"
        cp ~/.claude/templates/ralph/progress.txt.template "$RUN_DIR/progress.txt"
        cp ~/.claude/templates/ralph/prd.json.example "$RUN_DIR/prd.json"
        # Replace placeholders
        sed -i '' "s/{{RUN_NAME}}/$RUN_NAME/g" "$RUN_DIR/prompt.md"
        sed -i '' "s/{{RUN_NAME}}/$RUN_NAME/g" "$RUN_DIR/progress.txt"
        sed -i '' "s/{{DATE}}/$(date)/g" "$RUN_DIR/progress.txt"
        sed -i '' "s/{{BRANCH_NAME}}/$BRANCH/g" "$RUN_DIR/progress.txt"
    fi
else
    # Check how many runs exist
    RUN_COUNT=$(ls -d scripts/ralph/runs/*/ 2>/dev/null | wc -l | tr -d ' ')

    if [ "$RUN_COUNT" -eq 1 ]; then
        RUN_NAME=$(basename "$(ls -d scripts/ralph/runs/*/)")
    elif [ "$RUN_COUNT" -eq 0 ]; then
        # Ask user for run name
        echo "No runs found. What should this run be called?"
    else
        # Show available runs and ask
        echo "Multiple runs found. Which one?"
        ls -d scripts/ralph/runs/*/
    fi
fi
```

### Step 5: Handle Legacy Structure

If project has old flat structure (prd.json directly in scripts/ralph/):

```bash
if [ -f "scripts/ralph/prd.json" ] && [ ! -d "scripts/ralph/runs" ]; then
    echo "Detected legacy Ralph structure. Migrating..."

    # Get branch name from prd.json
    BRANCH=$(jq -r '.branchName' scripts/ralph/prd.json)
    RUN_NAME="${BRANCH#ralph/}"

    # Create new structure
    mkdir -p "scripts/ralph/runs/$RUN_NAME"

    # Move files
    mv scripts/ralph/prd.json "scripts/ralph/runs/$RUN_NAME/"
    mv scripts/ralph/progress.txt "scripts/ralph/runs/$RUN_NAME/" 2>/dev/null || true
    [ -f scripts/ralph/prompt.md ] && mv scripts/ralph/prompt.md "scripts/ralph/runs/$RUN_NAME/"

    # Update ralph.sh to new version
    cp ~/.claude/templates/ralph/ralph.sh scripts/ralph/ralph.sh
    chmod +x scripts/ralph/ralph.sh

    echo "✅ Migrated to new structure: scripts/ralph/runs/$RUN_NAME/"
fi
```

### Step 6: Verify All Files Exist

Ensure all required files exist with proper content:

```bash
RUN_DIR="scripts/ralph/runs/$RUN_NAME"

# Check/create patterns.md at ralph level
if [ ! -f "scripts/ralph/patterns.md" ]; then
    cp ~/.claude/templates/ralph/patterns.md.template scripts/ralph/patterns.md
    echo "✅ Created patterns.md"
fi

# Check/create config
if [ ! -f "scripts/ralph/config" ]; then
    cp ~/.claude/templates/ralph/config.template scripts/ralph/config
    echo "✅ Created config (edit for notifications)"
fi

# Check/create prompt.md in run directory
if [ ! -f "$RUN_DIR/prompt.md" ]; then
    cp ~/.claude/templates/ralph/prompt.md "$RUN_DIR/prompt.md"
    sed -i '' "s/{{RUN_NAME}}/$RUN_NAME/g" "$RUN_DIR/prompt.md"
    echo "✅ Created prompt.md with Playwright MCP tools"
fi

# Check/create progress.txt in run directory
if [ ! -f "$RUN_DIR/progress.txt" ]; then
    cp ~/.claude/templates/ralph/progress.txt.template "$RUN_DIR/progress.txt"
    sed -i '' "s/{{RUN_NAME}}/$RUN_NAME/g" "$RUN_DIR/progress.txt"
    sed -i '' "s/{{DATE}}/$(date)/g" "$RUN_DIR/progress.txt"
    sed -i '' "s/{{BRANCH_NAME}}/$(git branch --show-current)/g" "$RUN_DIR/progress.txt"
    echo "✅ Created progress.txt"
fi

# Check/create prd.json in run directory
if [ ! -f "$RUN_DIR/prd.json" ]; then
    cp ~/.claude/templates/ralph/prd.json.example "$RUN_DIR/prd.json"
    # Update branchName to current branch
    BRANCH=$(git branch --show-current)
    jq --arg branch "$BRANCH" '.branchName = $branch' "$RUN_DIR/prd.json" > "$RUN_DIR/prd.json.tmp"
    mv "$RUN_DIR/prd.json.tmp" "$RUN_DIR/prd.json"
    echo "✅ Created prd.json (needs your stories)"
fi

# Verify ralph.sh is executable
if [ ! -x "scripts/ralph/ralph.sh" ]; then
    chmod +x scripts/ralph/ralph.sh
    echo "✅ Made ralph.sh executable"
fi
```

### Step 7: Guide User to PRD

After setup is complete, help user with the PRD:

```bash
PRD_FILE="scripts/ralph/runs/$RUN_NAME/prd.json"

# Check if PRD has real stories or is just example
STORY_COUNT=$(jq '.userStories | length' "$PRD_FILE" 2>/dev/null || echo "0")
FIRST_TITLE=$(jq -r '.userStories[0].title // empty' "$PRD_FILE" 2>/dev/null)

if [ "$STORY_COUNT" -eq 0 ] || [ "$FIRST_TITLE" = "Story title (verb + noun)" ]; then
    echo "📝 PRD needs your stories!"
    echo ""
    echo "Options:"
    echo "1. Edit directly: $PRD_FILE"
    echo "2. Convert existing PRD: /ralph convert <prd-file.md>"
    echo ""
    echo "After adding stories, run: ./scripts/ralph/ralph.sh 50"
else
    # Show status
    COMPLETED=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")
    TOTAL=$(jq '.userStories | length' "$PRD_FILE")
    REMAINING=$((TOTAL - COMPLETED))

    echo "✅ Ralph is ready!"
    echo ""
    echo "Run: $RUN_NAME"
    echo "Branch: $(git branch --show-current)"
    echo "Stories: $COMPLETED/$TOTAL complete ($REMAINING remaining)"
    echo ""
    if [ "$REMAINING" -gt 0 ]; then
        NEXT_STORY=$(jq -r '[.userStories[] | select(.passes == false)][0] | "\(.id): \(.title)"' "$PRD_FILE")
        echo "Next: $NEXT_STORY"
        echo ""
    fi
    echo "To run: ./scripts/ralph/ralph.sh 50"
fi
```

### Step 8: Show File Summary

Display what files exist and their status:

```
📁 Ralph Setup Complete!

scripts/ralph/
├── ralph.sh        ✅ v2.0.0 (executable)
├── config          ✅ (edit for notifications)
├── patterns.md     ✅ (persistent learnings)
└── runs/
    └── {RUN_NAME}/
        ├── prd.json      ⚠️ Needs your stories
        ├── prompt.md     ✅ Playwright MCP tools
        └── progress.txt  ✅ Ready for learnings
```

---

## PRD Conversion (Optional)

If user has an existing PRD markdown file:

```bash
/ralph convert tasks/prd-my-feature.md
```

### Conversion Rules

**Story Size (Critical):**
- Each story must complete in ONE iteration
- If you can't describe it in 2-3 sentences, split it

**Story Order:**
1. Schema/database changes
2. Backend logic
3. UI components
4. Dashboard/aggregation views

**Acceptance Criteria:**
- Must be verifiable (not vague)
- Always include: `"pnpm run typecheck passes"`
- For UI: `"Verify in browser using Playwright MCP"`

**Output Format:**
```json
{
  "project": "Project Name",
  "branchName": "[current git branch]",
  "description": "Feature description",
  "userStories": [
    {
      "id": "US-001",
      "title": "Story title",
      "description": "As a [user], I want [feature] so that [benefit]",
      "acceptanceCriteria": [
        "Specific criterion",
        "pnpm run typecheck passes"
      ],
      "priority": 1,
      "passes": false,
      "notes": ""
    }
  ]
}
```

---

## Running Ralph

After PRD is ready:

```bash
./scripts/ralph/ralph.sh 50
```

**CLI Options:**
- `./ralph.sh 50` - Run 50 iterations, auto-detect run
- `./ralph.sh 50 my-feature` - Specify run name
- `./ralph.sh --dry-run 50` - Preview without running
- `./ralph.sh --help` - Show help
- `./ralph.sh --version` - Show version

---

## How Ralph Works

Each iteration:
1. Read prd.json, find highest priority `passes: false` story
2. Read progress.txt (Codebase Patterns first)
3. Implement ONE story
4. Run quality checks
5. For UI: Verify with Playwright MCP
6. Commit: `feat: [US-XXX] - [Story Title]`
7. Set `passes: true` in prd.json
8. Append to progress.txt
9. If all done: output `<promise>COMPLETE</promise>`

---

## Browser Testing

For UI stories, uses Playwright MCP tools:
- `mcp__plugin_playwright_playwright__browser_navigate`
- `mcp__plugin_playwright_playwright__browser_snapshot`
- `mcp__plugin_playwright_playwright__browser_click`
- `mcp__plugin_playwright_playwright__browser_type`
- `mcp__plugin_playwright_playwright__browser_take_screenshot`

---

## Configuration

Edit `scripts/ralph/config` for:

```bash
# WhatsApp notifications
NOTIFICATIONS_ENABLED=true
TEXTMEBOT_API_KEY="your-key"
TEXTMEBOT_PHONE="your-phone"

# Claude flags
CLAUDE_FLAGS="--dangerously-skip-permissions"
```

---

## Templates Location

Global templates: `~/.claude/templates/ralph/`

| File | Purpose |
|------|---------|
| `VERSION` | Template version |
| `ralph.sh` | Runner script |
| `prompt.md` | Agent instructions |
| `config.template` | Settings template |
| `progress.txt.template` | Progress starter |
| `patterns.md.template` | Patterns starter |
| `prd.json.example` | Example PRD |

---

## Summary

| You Do | Ralph Does |
|--------|-----------|
| Run `/ralph` | Everything else |
| Write PRD stories | Setup, sync, detect |
| Run `./ralph.sh 50` | Execute iterations |

**That's it.** Just `/ralph` and work on your PRD.
