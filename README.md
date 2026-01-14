# Ralph

![Ralph](ralph.webp)

Ralph is an autonomous AI agent loop that runs [Claude Code](https://claude.ai/code) (or [Amp](https://ampcode.com)) repeatedly until all PRD items are complete. Each iteration is a fresh instance with clean context. Memory persists via git history, `progress.txt`, `patterns.md`, and `prd.json`.

Based on [Geoffrey Huntley's Ralph pattern](https://ghuntley.com/ralph/).

[Read my in-depth article on how I use Ralph](https://x.com/ryancarson/status/2008548371712135632)

## What's New in v2.0.0

- **Claude Code CLI support** - Works with both Claude Code and Amp
- **Run directories** - Isolated runs at `scripts/ralph/runs/<name>/`
- **Global templates** - Store templates at `~/.claude/templates/ralph/`
- **Auto-sync** - Automatically updates templates when newer version available
- **Playwright MCP** - Browser testing via Playwright MCP tools (not dev-browser)
- **Notifications** - WhatsApp notifications via TextMeBot
- **CLI options** - `--help`, `--version`, `--dry-run`
- **Quality checklist** - Comprehensive verification before marking stories complete
- **Forbidden strings** - Automatic detection of mock data and bad patterns

## Prerequisites

- [Claude Code CLI](https://claude.ai/code) or [Amp CLI](https://ampcode.com) installed and authenticated
- `jq` installed (`brew install jq` on macOS)
- A git repository for your project

## Quick Start

The easiest way to use Ralph:

```bash
# 1. Copy templates to global location (one-time setup)
mkdir -p ~/.claude/templates/ralph
cp templates/* ~/.claude/templates/ralph/

# 2. Copy skills to Claude Code (one-time setup)
mkdir -p ~/.claude/skills
cp -r skills/ralph ~/.claude/skills/
cp -r skills/prd ~/.claude/skills/

# 3. In your project, just run:
/ralph
```

The `/ralph` skill will:
1. Auto-detect if Ralph is set up in your project
2. Auto-initialize if not (creates everything)
3. Auto-sync templates if outdated
4. Guide you to work on the PRD

## Setup Options

### Option 1: Use the /ralph skill (Recommended)

After copying skills to `~/.claude/skills/`, just run `/ralph` in any project. It handles everything automatically.

### Option 2: Manual setup

Copy files to your project:

```bash
# From your project root
mkdir -p scripts/ralph/runs/my-feature
cp /path/to/ralph/ralph.sh scripts/ralph/
cp /path/to/ralph/prompt.md scripts/ralph/runs/my-feature/
chmod +x scripts/ralph/ralph.sh
```

## Workflow

### 1. Create a PRD

Use the `/prd` skill to generate a detailed requirements document:

```
/prd [your feature description]
```

Answer the clarifying questions. The skill saves output to `tasks/prd-[feature-name].md`.

### 2. Convert PRD to Ralph format

Use the `/ralph` skill to convert the markdown PRD to JSON:

```
/ralph convert tasks/prd-[feature-name].md
```

This creates `scripts/ralph/runs/<run-name>/prd.json` with user stories structured for autonomous execution.

### 3. Run Ralph

```bash
./scripts/ralph/ralph.sh [max_iterations] [run_name]
```

**CLI Options:**
- `./ralph.sh 50` - Run 50 iterations, auto-detect run from branch
- `./ralph.sh 50 my-feature` - Run 50 iterations on specific run
- `./ralph.sh --dry-run 50` - Preview without running
- `./ralph.sh --help` - Show help
- `./ralph.sh --version` - Show version

Ralph will:
1. Check/create the correct branch (from PRD `branchName`)
2. Pick the highest priority story where `passes: false`
3. Implement that single story
4. Run quality checks (typecheck, lint, tests)
5. **For UI stories:** Verify in browser using Playwright MCP
6. Commit if all checks pass
7. Update `prd.json` to mark story as `passes: true`
8. Append learnings to `progress.txt`
9. Repeat until all stories pass or max iterations reached

## Project Structure

```
scripts/ralph/
├── ralph.sh              # Runner script
├── config                # Optional: notifications, Claude flags
├── patterns.md           # Persistent patterns across all runs
└── runs/
    └── my-feature/
        ├── prd.json      # User stories for this run
        ├── prompt.md     # Agent instructions
        └── progress.txt  # Learnings from iterations
```

## Key Files

| File | Purpose |
|------|---------|
| `ralph.sh` | The bash loop that spawns fresh Claude instances |
| `prompt.md` | Instructions given to each Claude instance |
| `prd.json` | User stories with `passes` status (the task list) |
| `progress.txt` | Append-only learnings for future iterations |
| `patterns.md` | Persistent patterns across all runs |
| `config` | Notification settings and Claude flags |
| `templates/` | Global templates for new projects |
| `skills/prd/` | Skill for generating Ralph-optimized PRDs |
| `skills/ralph/` | Skill for setup, sync, and PRD conversion |

## Flowchart

[![Ralph Flowchart](ralph-flowchart.png)](https://snarktank.github.io/ralph/)

**[View Interactive Flowchart](https://snarktank.github.io/ralph/)** - Click through to see each step with animations.

## Critical Concepts

### Each Iteration = Fresh Context

Each iteration spawns a **new Claude instance** with clean context. Memory persists ONLY via:
- Git history (commits from previous iterations)
- `progress.txt` (learnings and Codebase Patterns)
- `patterns.md` (persistent patterns across all runs)
- `prd.json` (which stories are complete)

### Story Sizing (Critical for Success)

Each PRD item must be small enough to complete in one iteration.

**Size Guidelines:**
- Target: 50-150 lines of code changes
- Max: 300 lines (if more, split the story)
- One file focus preferred (2-3 files max)

**Right-sized stories (1 iteration each):**
- Add a database column + migration
- Add ONE UI component to an existing page
- Update ONE server action with new logic
- Add a filter dropdown to a list

**Too big (MUST split):**
- "Build the entire dashboard" → Split into 5-10 specific components
- "Add authentication" → Split into schema, middleware, login UI, session
- "Refactor the API" → Split into one story per endpoint

**Rule of thumb:** If you can't describe the change in ONE sentence with a specific file path, it's too big.

### Browser Testing with Playwright MCP

Frontend stories must include "Verify in browser using Playwright MCP" in acceptance criteria.

**Available Playwright MCP tools:**
- `mcp__plugin_playwright_playwright__browser_navigate` - Go to a URL
- `mcp__plugin_playwright_playwright__browser_snapshot` - Get page accessibility snapshot
- `mcp__plugin_playwright_playwright__browser_click` - Click an element
- `mcp__plugin_playwright_playwright__browser_type` - Type text into an input
- `mcp__plugin_playwright_playwright__browser_take_screenshot` - Capture screenshot

**A frontend story is NOT complete until browser verification passes.**

### Quality Checklist

Before marking a story as `passes: true`, Ralph verifies:
- [ ] Code compiles without errors
- [ ] Linting passes
- [ ] Relevant tests pass
- [ ] For UI changes: Browser verification completed
- [ ] No forbidden strings in code
- [ ] All acceptance criteria met

### Forbidden Strings

Stories automatically check for these anti-patterns:
- `'Test Client'` - Mock data
- `'Test Service'` - Mock data
- `'10:30 AM'` - Hardcoded time
- `as any` - Type safety bypass
- `void _` - Suppressed unused var
- `// TODO:` - Incomplete work

### Stop Condition

When all stories have `passes: true`, Ralph outputs `<promise>COMPLETE</promise>` and the loop exits.

## Configuration

Create `scripts/ralph/config` for custom settings:

```bash
# WhatsApp notifications
NOTIFICATIONS_ENABLED=true
TEXTMEBOT_API_KEY="your-key"
TEXTMEBOT_PHONE="your-phone"

# Claude flags
CLAUDE_FLAGS="--dangerously-skip-permissions"
```

## Debugging

```bash
# See which stories are done
cat scripts/ralph/runs/my-feature/prd.json | jq '.userStories[] | {id, title, passes}'

# See Codebase Patterns
head -20 scripts/ralph/runs/my-feature/progress.txt

# See persistent patterns
cat scripts/ralph/patterns.md

# See recent learnings
tail -50 scripts/ralph/runs/my-feature/progress.txt

# Check git history
git log --oneline -10

# Show Ralph status
./scripts/ralph/ralph.sh --version
```

## Templates

Global templates are stored at `~/.claude/templates/ralph/`:

| File | Purpose |
|------|---------|
| `VERSION` | Template version for auto-sync |
| `ralph.sh` | Runner script |
| `prompt.md` | Agent instructions |
| `config.template` | Settings template |
| `progress.txt.template` | Progress starter |
| `patterns.md.template` | Patterns starter |
| `prd.json.example` | Example PRD |

## Archiving

Ralph automatically archives previous runs when you start a new feature (different `branchName`). Archives are saved to `scripts/ralph/archive/YYYY-MM-DD-feature-name/`.

Pattern preservation ensures learnings are not lost - patterns are extracted and appended to `patterns.md` before archiving.

## When To Use Ralph

**Good for:**
- Greenfield projects with clear requirements
- Large refactors with verifiable outcomes
- Batch operations (lint fixes, standardization)
- Multi-file feature implementation
- Cross-app integrations

**Not good for:**
- Ambiguous requirements
- Architectural decisions
- Security-sensitive code
- Exploration/research tasks
- Design decisions requiring human judgment

## References

- [Geoffrey Huntley's Ralph article](https://ghuntley.com/ralph/)
- [Claude Code documentation](https://claude.ai/code)
- [Amp documentation](https://ampcode.com/manual)
