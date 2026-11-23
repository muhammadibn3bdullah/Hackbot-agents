# On-demand per-skill specialist subagents

One lightweight OpenCode **subagent per skill** (88), generated into
`agents/specialists/<skill-id>.md` and exposed to harnesses as agent ID
`specialists/<skill-id>`.

They are **spawned on demand** (fresh child context), do exactly one skill's
task, then exit. No idle agents, no persistent quota burn. This is the
"one agent per task" model implemented efficiently — NOT 88 persistent Maestro
agents.

## Agent ID convention

```
specialists/<skill-id>      e.g. specialists/hunt-xss, specialists/js_analysis
```

Each specialist's system prompt: load its skill via the `skill` tool, follow it
exactly, stay in the caller-provided scope, return concise result + evidence
paths, flag anything needing human validation.

## How the lead routes

**Rule: use a skill for every task.** For each discrete task, the lead (or a
phase agent) MUST either load the relevant skill with the `skill` tool, or spawn
the matching specialist subagent (which loads that skill itself). Never improvise
a skill's procedure from memory.

Specialists replace doing the work inline:

```
task: "check reflected XSS on search param"
  → spawn subagent  specialists/hunt-xss
task: "extract endpoints from these local JS files"
  → spawn subagent  specialists/js_analysis
task: "fingerprint API from Caido traffic"
  → spawn subagent  specialists/api-fingerprint-caido
```

In Maestro Auto Run, a task can instruct the lead:
"spawn the `specialists/<skill-id>` subagent for this task and use its result."

## Reliability note

Specialization focuses context; it does **not** guarantee correctness.
Reliability comes from: fresh context per task + `triage-validation` 7-Question
Gate + `evidence-hygiene` + human validation/submission. Keep those gates.

## Install

`scripts/install-hackbots.sh` / `.ps1` symlink (Unix) or copy (Windows)
`agents/specialists/` into `~/.config/opencode/agents/` and `~/.claude/agents/`.
