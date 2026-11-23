---
type: reference
title: Hackbot Foundation Architecture
created: 2026-11-23
tags:
  - architecture
  - recon
  - orchestration
related:
  - '[[workflow]]'
  - '[[authorized-use]]'
---

# Architecture — local recon flow

This document describes the recon flow in prose, without diagrams. Every stage
operates on local files, or on Caido traffic captured for a target you are
explicitly authorized to test. Complete the checklist in [[authorized-use]]
before any live run. The agent-to-skill mapping is covered in [[workflow]].

## Pipeline stages

1. **Local JS files.** The input is a directory of JavaScript bundles that
   already exist on disk in `lab/sample-app/` or another local folder. Nothing
   here fetches from the internet or contacts a target.

2. **`lazy_chunk_downloader` (optional).** If a bundle references code-split
   chunks that are not present locally, this helper locates the dynamic-import
   chunk map (for example a webpack-style `__webpack_require__.u`) and
   downloads only those chunks into the working directory. It is skipped when
   all relevant JS is already available.

3. **`js-analysis`.** The `js-analysis` subagent / `js_analysis` skill scans the
   collected JS files and extracts API endpoints, paths, and URLs — routes
   such as `/api/v1/users`, absolute URLs, and `baseURL` constants.

4. **`all_endpoints.txt`** — the raw line-oriented output of the scan. It is a
   flat list, one candidate endpoint per line, and is treated as generated
   data (ignored by git).

5. **Markdown report.** `scripts/aggregate_findings.py` reads
   `all_endpoints.txt`, de-duplicates it, groups entries into `/api` routes,
   absolute URLs, ID/token-bearing paths, and other, and writes
   `reports/endpoints.md` with a table and a count per group.

6. **Maestro / Claude / Codex orchestration.** Maestro is the orchestration
   surface; OpenCode (`hackbot-lead`, `js-hunter`) is the primary execution
   layer, and Codex is the cross-harness bridge (for example
   `caido-fingerprinter`). Agents invoke the skills above and hand results to
   one another with `maestro-cli ask`. See [[workflow]] for the exact command
   patterns.

## Stage summary

| Stage | Input | Output | Runs locally |
|-------|-------|--------|--------------|
| Local JS files | bundle directory | `.js` files on disk | yes |
| `lazy_chunk_downloader` | existing bundle | fetched chunks (optional) | yes, from local references |
| `js-analysis` | `.js` files | raw endpoint candidates | yes |
| `all_endpoints.txt` | endpoint candidates | flat endpoint list | yes |
| Markdown report | endpoint list | `reports/endpoints.md` | yes |
| Orchestration | reports + traffic | coordinated agent work | yes |

## Safety boundary

No stage in this flow scans a live target. The only network-adjacent step is
`api-fingerprint-caido`, which reads traffic already captured in Caido on
`127.0.0.1:8080` for an authorized scope. Do not supply a real target in
`.env.example` values or point any agent at a host unless written
authorization and an explicit in-scope list exist.
