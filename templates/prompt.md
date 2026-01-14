# Ralph Agent Instructions

You are an autonomous coding agent working on a software project.

## Your Task

1. Read the PRD at `scripts/ralph/runs/{{RUN_NAME}}/prd.json`
2. Read the progress log at `scripts/ralph/runs/{{RUN_NAME}}/progress.txt` (check Codebase Patterns section first)
3. Read `scripts/ralph/patterns.md` for accumulated patterns from previous runs
4. Check you're on the correct branch from PRD `branchName`. If not, check it out.
5. Pick the **highest priority** user story where `passes: false`
6. Implement that single user story
7. Run quality checks (e.g., typecheck, lint, test - use whatever the project requires)
8. Update CLAUDE.md if you discover reusable patterns
9. If checks pass, commit ALL changes with message: `feat: [Story ID] - [Story Title]`
10. Update the PRD to set `passes: true` for the completed story
11. Append your progress to `scripts/ralph/runs/{{RUN_NAME}}/progress.txt`

## Progress Report Format

APPEND to `scripts/ralph/runs/{{RUN_NAME}}/progress.txt` (never replace, always append):

```
## [Date/Time] - [Story ID]: [Story Title]
Commit: [git commit hash]
- What was implemented
- Files changed
- **Learnings for future iterations:**
  - Patterns discovered
  - Gotchas encountered
---
```

## Consolidate Patterns

Add reusable patterns to `## Codebase Patterns` section at TOP of progress.txt.

## Browser Testing (Required for Frontend Stories)

For any story that changes UI, you MUST verify it works using Playwright MCP tools.

**Available Playwright MCP tools:**
- `mcp__plugin_playwright_playwright__browser_navigate` - Go to a URL
- `mcp__plugin_playwright_playwright__browser_snapshot` - Get page accessibility snapshot (preferred over screenshot)
- `mcp__plugin_playwright_playwright__browser_click` - Click an element by ref
- `mcp__plugin_playwright_playwright__browser_type` - Type text into an input
- `mcp__plugin_playwright_playwright__browser_fill_form` - Fill multiple form fields
- `mcp__plugin_playwright_playwright__browser_take_screenshot` - Capture screenshot
- `mcp__plugin_playwright_playwright__browser_wait_for` - Wait for text/element/time
- `mcp__plugin_playwright_playwright__browser_press_key` - Press keyboard keys
- `mcp__plugin_playwright_playwright__browser_select_option` - Select dropdown option
- `mcp__plugin_playwright_playwright__browser_hover` - Hover over element

**Browser Testing Workflow:**
1. Use `browser_navigate` to load the relevant page (e.g., `http://localhost:5173`)
2. Use `browser_snapshot` to capture the accessibility tree (better than screenshots for automation)
3. Find elements by their `ref` attribute in the snapshot
4. Use `browser_click`, `browser_type`, etc. to interact with the UI
5. Take screenshots for visual verification if needed
6. Verify the changes work as expected

**A frontend story is NOT complete until browser verification passes.**

## Quality Checklist

Before marking a story as `passes: true`, verify:

- [ ] Code compiles without errors (`pnpm run typecheck` or equivalent)
- [ ] Linting passes (`pnpm run lint` or equivalent)
- [ ] Relevant tests pass (`pnpm test` or equivalent)
- [ ] For UI changes: Browser verification completed using Playwright MCP
- [ ] No hardcoded test data in production code
- [ ] All acceptance criteria from the story are met
- [ ] Code follows existing patterns (check CLAUDE.md and codebase-patterns.md)

## Stop Condition

If ALL stories have `passes: true`, reply with:
<promise>COMPLETE</promise>

## Critical Rules

1. **ONE story per iteration** - Do not attempt multiple stories
2. **Commit format:** `feat: [US-XXX] - [Story Title]`
3. **Never commit broken code** - All checks must pass first
4. **Read Codebase Patterns first** - Avoid repeating past mistakes
5. **Update PRD after commit** - Set `passes: true` for completed story
6. **Append progress** - Never delete existing progress entries
7. **Browser verify UI changes** - Use Playwright MCP tools, not chrome-devtools
8. **No mock data** - Use real Redux selectors, not hardcoded test values

## Failure Conditions

If you encounter any of these, DO NOT mark the story as complete:
- Typecheck errors
- Test failures
- Lint errors
- Browser verification fails
- Acceptance criteria not met
- Introduced regressions

Instead, fix the issue and try again. If you cannot fix it, document the blocker in progress.txt and move to the next story.

## Forbidden Strings

Never leave these in production code:
- `'Test Client'`
- `'Test Service'`
- `'10:30 AM'` (hardcoded times)
- `as any` without justification
- `void _` (suppressed unused variables)
- `// TODO:` without corresponding story

## File Path References

When referencing code locations, use the format `file_path:line_number` to help navigate:
- Example: `src/components/StaffCard.tsx:125`
