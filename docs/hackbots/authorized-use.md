---
type: reference
title: Authorized-Use Checklist (Preconditions for Any Live Run)
created: 2026-11-23
tags:
  - authorization
  - scope
  - safety
  - checklist
related:
  - '[[architecture]]'
  - '[[workflow]]'
---

# Authorized use — checklist before any live run

Everything in this repository runs against local files or against Caido traffic
that was already captured for a target you are explicitly authorized to test.
**No task in this playbook performs a live scan.** This checklist is the gate
that must be satisfied before any agent is pointed at a real host. If any box
below is unchecked, do not run a live assessment.

The recon data flow is described in [[architecture]] and the agent/CLI patterns
in [[workflow]]. Both documents link here as the authorization gate.

## Preconditions

- [ ] **Written authorization.** A signed authorization or rules-of-engagement
      document exists, naming the target and the testing window. Store its
      location (not credentials) in `AUTHORIZATION_REF` in your local `.env`.
      A verbal "go ahead" or a public bug-bounty policy alone is not sufficient
      unless its scope explicitly covers the intended activity.

- [ ] **Explicit in-scope hosts.** A concrete list of in-scope hosts, domains,
      IPs, and API base URLs is recorded in `TARGET_SCOPE` in `.env`. Wildcards
      are acceptable only if the authorization itself grants them. "The whole
      company" is not a scope.

- [ ] **Out-of-scope exclusions.** Excluded hosts and data types are written
      down explicitly (for example production databases, third-party SaaS
      tenants, payment/cardholder data, employee personal accounts, and any
      subdomain carved out by the engagement). Verified against the
      authorization, not assumed.

- [ ] **Caido running with captured traffic.** Caido is running on
      `127.0.0.1:8080` (`CAIDO_URL` in `.env`) and the in-scope target has
      already been browsed through it, so `api-fingerprint-caido` has real
      traffic to read. The `caido-fingerprinter` agent only reads captured
      traffic — it does not generate it.

- [ ] **Named human reviewer.** A specific person is designated as the reviewer
      and point of contact, recorded in `REVIEWER_NAME` in `.env`. They are
      reachable during the testing window and have authority to stop the run.
      Automated findings are not acted on externally without their review.

## Standing rules

- Do not place a real target, token, or credential in `.env.example` or commit
  it to version control. Only `.env` (git-ignored) may hold live values.
- Never broaden scope mid-run. Stop and re-authorize before touching a new host.
- Prefer read-only, local, or captured-traffic operations. Escalate to any
  active/exploit step only with the reviewer's explicit approval.
- Keep `- [ ]` items unchecked until the underlying evidence actually exists;
  this checklist is a gate, not a formality.

## Verification for this task

- File created: `docs/authorized-use.md`.
- Checklist covers all five required preconditions: written authorization,
  in-scope hosts, out-of-scope exclusions, Caido with captured traffic, and a
  named human reviewer.
- Reinforces that no live scan is performed in this playbook.
