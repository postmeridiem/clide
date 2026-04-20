---
name: skill-create
description: >
  Guidance for creating effective Claude Code skills (.skill packages).
  Use when the user wants to create, build, design, or iterate on a skill —
  including writing SKILL.md files, bundling scripts/references/assets,
  initializing new skills, packaging skills, or improving existing ones.
  Triggers on requests like "create a skill", "make a new skill",
  "build a skill for X", "package this skill", or "improve my skill".
---


# Skill Creator

## About Skills

Skills are modular, self-contained packages that extend Claude's capabilities
by providing specialized knowledge, workflows, and tools. They transform Claude
from a general-purpose agent into a specialized agent equipped with procedural
knowledge that no model can fully possess.

### What Skills Provide

- **Specialized workflows** — Multi-step procedures for specific domains
- **Tool integrations** — Instructions for working with specific file formats or APIs
- **Domain expertise** — Company-specific knowledge, schemas, business logic
- **Bundled resources** — Scripts, references, and assets for complex and repetitive tasks

## Core Principles

### Concise is Key

The context window is a public good. Skills share it with everything else Claude
needs: system prompt, conversation history, other skills' metadata, and the
actual user request.

Default assumption: Claude is already very smart. Only add context Claude doesn't
already have. Challenge each piece of information: "Does Claude really need this
explanation?" and "Does this paragraph justify its token cost?"

Prefer concise examples over verbose explanations.

### Set Appropriate Degrees of Freedom

Match specificity to the task's fragility and variability:

- **High freedom** (text-based instructions): Multiple approaches valid, decisions
  depend on context, heuristics guide the approach.
- **Medium freedom** (pseudocode or scripts with parameters): Preferred pattern
  exists, some variation acceptable, configuration affects behavior.
- **Low freedom** (specific scripts, few parameters): Operations are fragile and
  error-prone, consistency is critical, specific sequence must be followed.

Think of Claude as exploring a path: a narrow bridge with cliffs needs specific
guardrails (low freedom), while an open field allows many routes (high freedom).

## Anatomy of a Skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter metadata (required)
│   │   ├── name: (required)
│   │   ├── description: (required)
│   │   └── compatibility: (optional, rarely needed)
│   └── Markdown instructions (required)
└── Bundled Resources (optional)
    ├── scripts/          - Executable code (Python/Bash/etc.)
    ├── references/       - Documentation loaded into context as needed
    └── assets/           - Files used in output (templates, icons, fonts, etc.)
```

### SKILL.md (required)

- **Frontmatter (YAML)**: `name` and `description` fields (required). Only these
  are read by Claude to determine when the skill triggers — be clear and
  comprehensive. The `compatibility` field is for environment requirements but
  most skills don't need it.
- **Body (Markdown)**: Instructions and guidance. Only loaded AFTER the skill
  triggers.

### Bundled Resources (optional)

**Scripts (`scripts/`)** — Executable code for tasks requiring deterministic
reliability or that are repeatedly rewritten.

**References (`references/`)** — Documentation loaded as needed into context.
Keep SKILL.md lean; move detailed reference material, schemas, and examples here.
If files are large (>10k words), include grep search patterns in SKILL.md.

**Assets (`assets/`)** — Files used in output, not loaded into context (templates,
images, icons, boilerplate code, fonts).

### What to NOT Include

Do NOT create extraneous files like README.md, INSTALLATION_GUIDE.md,
QUICK_REFERENCE.md, CHANGELOG.md, etc. The skill should only contain information
needed for an AI agent to do the job.

## Progressive Disclosure

Skills use a three-level loading system:

1. **Metadata** (name + description) — Always in context (~100 words)
2. **SKILL.md body** — When skill triggers (<5k words)
3. **Bundled resources** — As needed (unlimited; scripts can run without reading)

Keep SKILL.md body under 500 lines. Split content into separate files when
approaching this limit. Reference split files from SKILL.md with clear
descriptions of when to read them.

### Disclosure Patterns

**Pattern 1: High-level guide with references** — Keep overview in SKILL.md,
link to detail files loaded only when needed.

**Pattern 2: Domain-specific organization** — Organize content by domain
(e.g., `references/finance.md`, `references/sales.md`) so only relevant content
is loaded.

**Pattern 3: Conditional details** — Show basic content, link to advanced
content loaded only when the user needs those features.

Guidelines:
- Avoid deeply nested references — keep one level deep from SKILL.md
- Structure longer reference files with a table of contents at the top

## Skill Creation Process

Follow these steps in order, skipping only with clear reason:

### Step 1: Understand the Skill with Concrete Examples

Skip only when usage patterns are already clearly understood.

Ask the user for concrete examples of how the skill will be used:
- "What functionality should the skill support?"
- "Can you give some examples of how this skill would be used?"
- "What would a user say that should trigger this skill?"

Avoid overwhelming users — start with the most important questions.

### Step 2: Plan the Reusable Skill Contents

Analyze each example by considering how to execute from scratch and identifying
what scripts, references, and assets would help with repeated execution.

Establish a list of reusable resources: scripts, references, and assets.

### Step 3: Initialize the Skill

Create the skill directory manually:

```
mkdir -p <output-directory>/<skill-name>
```

Then create `SKILL.md` with frontmatter and body. Add `scripts/`, `references/`,
and `assets/` subdirectories only as needed.

Skip if iterating on an existing skill.

### Step 4: Edit the Skill

Remember the skill is for another Claude instance to use. Include beneficial,
non-obvious information.

For design patterns, consult:
- `references/workflows.md` — Sequential workflows and conditional logic
- `references/output-patterns.md` — Template and example patterns

**Implementation order:**
1. Start with reusable resources (`scripts/`, `references/`, `assets/`)
2. Test added scripts by running them
3. Delete unused example files from initialization
4. Update SKILL.md

**Writing guidelines:** Always use imperative/infinitive form.

**Frontmatter:**
- `name`: The skill name — use **domain-action** naming: `{domain}-{action}`.
  The domain is the system/area the skill operates on, the action is what it does.
  Examples: `pr-review`, `sprint-plan`, `docs-search`, `git-commit`, `debt-scan`.
  Multi-action wrappers (like `ticket`) can use the domain name alone.
  The directory name must match the `name` field.
- `description`: Primary triggering mechanism. Include what the skill does AND
  specific triggers/contexts. All "when to use" info goes here (not in body).

**Body:** Instructions for using the skill and its bundled resources.

### Step 5: Validate the Skill

Check the skill manually:
- Frontmatter has `name` and `description`
- SKILL.md body is under 500 lines
- No extraneous files (README.md, CHANGELOG.md, etc.)
- Scripts are executable and tested
- References are referenced from SKILL.md

### Step 6: Iterate

After real usage, notice struggles or inefficiencies, identify needed updates,
implement changes, and test again.
