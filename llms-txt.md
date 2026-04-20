---
name: llms-txt
description: Generate an llms.txt file for a project. Use when preparing a web project for deployment and want to make it discoverable by AI agents.
allowed-tools: Read, Glob, Grep, Bash, Write
---
<!-- Version: 2026-04-20.1 -->

# llms-txt

Generate an llms.txt file for the current project.

## Steps

1. **Find the public directory.** Look for a `public/` directory in the project. Check common locations: the project root, and any component repos. If no `public/` directory exists, ask the user where it should go. If the project has no web surface, stop — llms.txt is not applicable.

2. **Read project docs.** Read whatever exists from:
   - `CLAUDE.md` (project root)
   - `PHILOSOPHY.md` (project root)
   - `manifest.json` (project root)
   - `docs/memory.md` (project root)
   - If running from a component repo, also check the parent project directory for these files.

3. **Generate the draft.** Build an llms.txt following the standard format:
   - **H1** — the project/app name
   - **Blockquote** — one-sentence summary of what the app is
   - **Body** — what the app does, who it's for, what an agent or user can do here. Written in plain language. Describe capabilities in terms of actions and outcomes, not technical implementation.
   - **Sections (H2)** — add sections as the content warrants. Common ones: Features, API, Capabilities, Contact. Don't force sections that don't apply.

   The output should be useful to an AI agent arriving at this site for the first time. It should understand what the app is, what it can do, and what actions are available.

4. **Present the draft.** Show the full llms.txt content to the user for review. Don't write it yet.

5. **Write the file.** On approval, write to `public/llms.txt` in the identified directory.

## Rules

- No boilerplate. Every line should carry information.
- Write for an agent, not a human marketer. Direct, factual, specific.
- Don't invent capabilities that don't exist in the app yet.
- If the project docs are too thin to generate a useful llms.txt, say so and ask the user to fill in the gaps.
