---
name: prd
description: "Generate a Product Requirements Document (PRD) for a new feature. Use when planning a feature, starting a new project, or when asked to create a PRD. Triggers on: create a prd, write prd for, plan this feature, requirements for, spec out."
---

# PRD Generator

Create detailed Product Requirements Documents that are clear, actionable, and **optimized for Ralph autonomous execution**.

---

## The Job

1. Receive a feature description from the user
2. **Explore the codebase** to understand existing patterns and files
3. Ask 3-5 essential clarifying questions (with lettered options)
4. Generate a structured PRD based on answers
5. Save to `/tasks/prd-[feature-name].md`

**Important:** Do NOT start implementing. Just create the PRD.

---

## Step 0: Explore Codebase First

**Before asking questions**, explore the relevant parts of the codebase:

1. Read `CLAUDE.md` for project patterns and architecture
2. Check `.claude/rules/codebase-patterns.md` for learned patterns
3. Find existing similar components to reference
4. Identify specific files that will need changes
5. Note line counts of files (if >500 lines, plan to split)

This context informs better questions and more specific stories.

---

## Step 1: Clarifying Questions

Ask only critical questions where the initial prompt is ambiguous. Focus on:

- **Problem/Goal:** What problem does this solve?
- **Core Functionality:** What are the key actions?
- **Scope/Boundaries:** What should it NOT do?
- **Success Criteria:** How do we know it's done?

### Format Questions Like This:

```
1. What is the primary goal of this feature?
   A. Improve user onboarding experience
   B. Increase user retention
   C. Reduce support burden
   D. Other: [please specify]

2. Who is the target user?
   A. New users only
   B. Existing users only
   C. All users
   D. Admin users only

3. What is the scope?
   A. Minimal viable version
   B. Full-featured implementation
   C. Just the backend/API
   D. Just the UI
```

This lets users respond with "1A, 2C, 3B" for quick iteration.

---

## Step 2: PRD Structure

Generate the PRD with these sections:

### 1. Introduction/Overview
Brief description of the feature and the problem it solves.

### 2. Goals
Specific, measurable objectives (bullet list).

### 3. User Stories

**CRITICAL: Story Sizing for Ralph**

Each story must be completable in ONE Ralph iteration. Ralph spawns a fresh Claude instance per iteration with NO memory of previous work.

**Size Guidelines:**
- Target: 50-150 lines of code changes
- Max: 300 lines (if more, split the story)
- One file focus preferred (2-3 files max)

**Right-sized stories (1 iteration each):**
- Add a database column + migration
- Add ONE UI component to an existing page
- Update ONE server action with new logic
- Add a filter dropdown to a list
- Extract ONE helper function to a new file

**Too big (MUST split):**
- ❌ "Build the dashboard" → Split into 5-10 specific components
- ❌ "Add authentication" → Split into schema, middleware, login UI, session
- ❌ "Split StaffSidebar into modules" → Split into: extract Header, extract CardGrid, extract hooks, etc.
- ❌ "Refactor the API" → Split into one story per endpoint

**Rule of thumb:** If you can't describe the change in ONE sentence with a specific file path, it's too big.

---

### Story Ordering: Dependencies First

Stories execute in priority order. Earlier stories must not depend on later ones.

1. **Priority 1-3:** Schema/database changes, Redux slice updates
2. **Priority 4-6:** Utility functions, hooks, services
3. **Priority 7-10:** UI components that use the above
4. **Priority 11+:** Integration, polish, cleanup

---

### Story Format (REQUIRED)

```markdown
### US-001: [Verb] [Specific Thing]
**Description:** As a [user], I want [feature] so that [benefit].

**Files to modify:**
- `src/components/Example.tsx` (~50 lines to change)
- `src/store/slices/exampleSlice.ts` (add 1 selector)

**Acceptance Criteria:**
- [ ] Specific criterion with exact expected behavior
- [ ] Another criterion referencing specific values/strings
- [ ] No forbidden strings (see list below)
- [ ] pnpm run typecheck passes
- [ ] [UI only] Verify in browser using Playwright MCP

**Notes:**
- Follow pattern from `src/components/SimilarComponent.tsx`
- Use existing `useExampleHook` from `src/hooks/`
- CRITICAL: Do NOT use mock data - use real Redux selectors

**Priority:** N
```

**Required Fields:**
- **Files to modify** - Exact paths Ralph will change
- **Notes** - Implementation hints, patterns to follow, warnings
- **Priority** - Explicit number for ordering

---

### Acceptance Criteria Rules

**GOOD criteria (specific, verifiable):**
- "Remove hardcoded 'Test Client' string from line ~125"
- "Button click dispatches `addItem` action to Redux"
- "Dropdown shows options: All | Active | Completed"
- "Component renders client name from `ticket.clientName` (not mock)"
- "File is under 300 lines after refactor"

**BAD criteria (vague, unverifiable):**
- ❌ "Works correctly"
- ❌ "Good user experience"
- ❌ "Handles edge cases"
- ❌ "Is performant"

**Always include:**
```
- [ ] No forbidden strings in code (see list)
- [ ] pnpm run typecheck passes
- [ ] [UI stories] Verify in browser using Playwright MCP
```

---

### Forbidden Strings

Stories must explicitly forbid these in acceptance criteria:

| Forbidden | Why | Check |
|-----------|-----|-------|
| `'Test Client'` | Mock data | grep for string |
| `'Test Service'` | Mock data | grep for string |
| `'10:30 AM'` | Hardcoded time | grep for string |
| `as any` | Type safety bypass | grep for cast |
| `void _` | Suppressed unused var | grep for pattern |
| `// TODO:` | Incomplete work | grep for comment |
| `console.log` | Debug code | grep (unless intentional) |

**Add to acceptance criteria:**
```
- [ ] No forbidden strings: 'Test Client', 'Test Service', 'as any', 'void _'
```

---

### 4. Functional Requirements
Numbered list referencing specific stories:
- "FR-1 (US-001): The system must store priority in database"
- "FR-2 (US-003): TaskCard must display PriorityBadge"

### 5. Non-Goals (Out of Scope)
What this feature will NOT include. Be specific.

### 6. Technical Considerations
- **Existing patterns to follow:** Reference specific files
- **Files that will be modified:** List with line counts
- **Potential risks:** Large files needing split, etc.

### 7. Open Questions
Remaining questions or areas needing clarification.

---

## Writing for Ralph (Autonomous AI Agent)

Ralph has **NO MEMORY** between iterations. Each story must be self-contained.

**Include in every story:**
- Exact file paths to modify
- Specific patterns to follow (with file references)
- Warnings about what NOT to do
- All context needed to implement

**Do NOT assume Ralph knows:**
- What was done in previous stories (it doesn't)
- Project conventions (tell it explicitly)
- Where files are located (give paths)
- What patterns to use (reference examples)

---

## Anti-Patterns to Avoid

| Anti-Pattern | Example | Fix |
|--------------|---------|-----|
| Mock data | `clientName: 'Test Client'` | Use `ticket.clientName` from Redux |
| Vague criteria | "Works correctly" | "Button shows confirmation dialog" |
| Big stories | "Split component into modules" | One extraction per story |
| Missing files | "Update the component" | "Update `src/components/X.tsx`" |
| No patterns | "Add a modal" | "Follow pattern in `EditModal.tsx`" |
| `as any` | `(data as any).field` | Proper type guards |
| Wrong order | UI before Redux slice | Dependencies first |

---

## Example PRD (Ralph-Optimized)

```markdown
# PRD: Task Priority System

## Introduction

Add priority levels to tasks so users can focus on what matters most.

## Goals

- Allow assigning priority (high/medium/low) to any task
- Visual differentiation between priority levels
- Filter tasks by priority

## User Stories

### US-001: Add priority field to tasks Redux slice
**Description:** As a developer, I need priority in state management.

**Files to modify:**
- `src/store/slices/tasksSlice.ts` (~20 lines)
- `src/types/task.ts` (~5 lines)

**Acceptance Criteria:**
- [ ] Add `priority: 'high' | 'medium' | 'low'` to Task interface
- [ ] Default value is `'medium'`
- [ ] Add `selectTasksByPriority` selector
- [ ] pnpm run typecheck passes

**Notes:**
- Follow pattern from existing selectors in tasksSlice.ts
- Type must be union, not string

**Priority:** 1

---

### US-002: Create PriorityBadge component
**Description:** As a developer, I need a reusable badge for priority display.

**Files to modify:**
- `src/components/ui/PriorityBadge.tsx` (NEW, ~40 lines)

**Acceptance Criteria:**
- [ ] Props: `priority: 'high' | 'medium' | 'low'`
- [ ] Colors: red (#ef4444)=high, yellow (#eab308)=medium, gray (#6b7280)=low
- [ ] Renders as pill-shaped badge with text
- [ ] No forbidden strings
- [ ] pnpm run typecheck passes
- [ ] Verify in browser using Playwright MCP

**Notes:**
- Follow pattern from `src/components/ui/StatusBadge.tsx`
- Use Tailwind classes, not inline styles

**Priority:** 2

---

### US-003: Display priority badge on TaskCard
**Description:** As a user, I want to see task priority at a glance.

**Files to modify:**
- `src/components/TaskCard.tsx` (~15 lines)

**Acceptance Criteria:**
- [ ] Import and render PriorityBadge component
- [ ] Badge appears in card header, right side
- [ ] Priority comes from `task.priority` (NOT hardcoded)
- [ ] No forbidden strings: 'Test', 'Mock', 'as any'
- [ ] pnpm run typecheck passes
- [ ] Verify in browser using Playwright MCP

**Notes:**
- TaskCard is ~180 lines, this adds ~15 (under 200 total)
- Use existing task prop, don't add new data fetching

**Priority:** 3

---

### US-004: Add priority selector to TaskEditModal
**Description:** As a user, I want to change task priority when editing.

**Files to modify:**
- `src/components/TaskEditModal.tsx` (~25 lines)

**Acceptance Criteria:**
- [ ] Add dropdown with options: High, Medium, Low
- [ ] Current priority is pre-selected
- [ ] Selection updates local form state
- [ ] Save dispatches `updateTask` with new priority
- [ ] No forbidden strings
- [ ] pnpm run typecheck passes
- [ ] Verify in browser using Playwright MCP

**Notes:**
- Use existing Select component from `src/components/ui/select`
- Follow pattern from status selector in same modal

**Priority:** 4

---

### US-005: Add priority filter to task list
**Description:** As a user, I want to filter tasks by priority.

**Files to modify:**
- `src/components/TaskListHeader.tsx` (~20 lines)
- `src/components/TaskList.tsx` (~10 lines)

**Acceptance Criteria:**
- [ ] Filter dropdown: All | High | Medium | Low
- [ ] Filter uses `selectTasksByPriority` selector
- [ ] Empty state shows "No tasks match filter"
- [ ] No forbidden strings
- [ ] pnpm run typecheck passes
- [ ] Verify in browser using Playwright MCP

**Notes:**
- Follow pattern from existing status filter
- Filter state in component, not Redux (local UI state)

**Priority:** 5

## Functional Requirements

- FR-1 (US-001): Task type includes `priority` field
- FR-2 (US-002): PriorityBadge component exists with correct colors
- FR-3 (US-003): TaskCard displays priority badge
- FR-4 (US-004): TaskEditModal allows priority changes
- FR-5 (US-005): TaskList can be filtered by priority

## Non-Goals

- No priority-based notifications
- No automatic priority assignment
- No drag-and-drop priority reordering

## Technical Considerations

- **Existing patterns:** StatusBadge.tsx, Select component
- **File sizes:** All modified files stay under 300 lines
- **State:** Priority filter is local state, not Redux
```

---

## Checklist Before Saving

- [ ] **Explored codebase** to find patterns and file paths
- [ ] Asked clarifying questions with lettered options
- [ ] **Every story has "Files to modify" with paths**
- [ ] **Every story has "Notes" with patterns to follow**
- [ ] Stories are small enough (50-150 lines, max 300)
- [ ] Stories ordered by dependency (Priority numbers)
- [ ] Every story has `pnpm run typecheck passes`
- [ ] UI stories have `Verify in browser using Playwright MCP`
- [ ] **Forbidden strings listed in criteria**
- [ ] Non-goals section defines clear boundaries
- [ ] Saved to `/tasks/prd-[feature-name].md`

---

## Integration with Ralph

After creating the PRD:

```bash
# Initialize Ralph (if not done)
/ralph

# Convert PRD to Ralph format
/ralph convert tasks/prd-[feature-name].md

# Run Ralph
./scripts/ralph/ralph.sh 50
```

**Commit message format Ralph will use:**
```
feat: [US-XXX] - [Story Title]
```
