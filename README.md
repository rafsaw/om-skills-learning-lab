# om-skills-learning-lab

A sandbox for learning and exercising the [open-mercato](https://github.com/open-mercato/skills)
agent-skill collection.

There is no application code here. The substance of this repository is Markdown
skill definitions and the agentic pipeline configuration that drives them, so
"working on this repo" almost always means editing prose that an agent will
later execute as instructions. Skills are installed as vendored copies — not
submodules — and pinned by content hash in [`skills-lock.json`](skills-lock.json),
which makes the repo a reproducible snapshot of a skill set that can be edited,
broken, and re-run safely.

The pipeline it exercises is a real one: issues and pull requests on GitHub,
claimed and labeled by skills that hand work to each other through tracker
state. What that pipeline does, and what running it actually revealed, is
recorded in [`EXPERIMENTS.md`](EXPERIMENTS.md) and [`FINDINGS.md`](FINDINGS.md).

## Start here

**A fresh clone cannot dispatch a single skill until you recreate the discovery
symlinks.** `.claude/` is deliberately untracked (see [`.gitignore`](.gitignore)),
so after cloning, the skills exist under `.agents/skills/` but nothing points at
them yet. Fix that first:

```bash
mkdir -p .claude/skills
for s in .agents/skills/*/; do
  ln -sfn "$PWD/${s%/}" ".claude/skills/$(basename "$s")"
done
```

On Windows this needs Developer Mode or an elevated shell. These must stay
symlinks: replacing one with a real directory forks the skill into two sources
that then drift apart. This snippet is mirrored from the "Repository layout"
section of [`AGENTS.md`](AGENTS.md), which is the canonical copy — change it
there and here together.

You also need the [`gh` CLI](https://cli.github.com/), authenticated
(`gh auth status`) and at **version 2.82.1 or newer**, plus `jq`. Every tracker
action a skill takes runs through [`.ai/trackers/github.md`](.ai/trackers/github.md),
and older `gh` clients fail label and assignee edits on the retired Projects
(classic) API — that file explains the failure in detail, because it looks like
a harmless warning while silently leaving a pull request unlabeled.

## Repository map

| Path | What lives there |
|---|---|
| `.agents/skills/<name>/` | Canonical skill source — `SKILL.md` plus its `references/`. This is what is committed. |
| `.claude/skills/<name>` | Symlink into `.agents/skills/`. Untracked, recreated per clone (see above). |
| [`.ai/agentic.config.json`](.ai/agentic.config.json) | The pipeline config every `om-*` skill reads: base branch, tracker, label taxonomy, validation commands. |
| [`.ai/trackers/github.md`](.ai/trackers/github.md) | Definitions of every tracker operation, implemented with `gh`. Skills name operations; this file says what they do. |
| [`.ai/browsers/agent-browser.md`](.ai/browsers/agent-browser.md) | The same idea for browser operations, used by UI verification. |
| `.ai/{runs,analysis,specs,scripts,qa}/` | Skill working directories. Generated per run — not source, and not authoritative. |
| [`skills-lock.json`](skills-lock.json) | The installed-skill manifest: `source`, `sourceType`, `skillPath`, and `computedHash` per skill. |
| [`learning-map/`](learning-map) | Standalone HTML visual maps of the skill collection. |

## The documents, and who each is for

| Document | Audience and purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | The agent. Task routing ("when the work involves X, read Y first"), repo conventions, and the table of skills that are *referenced but not installed*. Read it before editing anything under `.agents/` or `.ai/`. |
| [`SDLC.md`](SDLC.md) | Anyone asking "what happens to a ticket here?" Ticket lifecycle, the label state machine, the claim protocol, and why reporting is decoupled from CI. |
| [`CODE_REVIEW.md`](CODE_REVIEW.md) | Reviewers, human and automated. Applied automatically by `om-code-review`, with checks specific to a repo made of skill files and descriptors. |
| [`BACKWARD_COMPATIBILITY.md`](BACKWARD_COMPATIBILITY.md) | Anyone renaming or moving something. Eight protected surfaces — all naming and format contracts — where a break fails quietly at run time instead of loudly at build time. |
| [`FINDINGS.md`](FINDINGS.md) | Conclusions reached by *reading* — a question answered from the documentation. |
| [`EXPERIMENTS.md`](EXPERIMENTS.md) | Conclusions reached by *running* something and watching what happened. |

## Visual map

[`learning-map/om-skills-learning-map-v5.html`](learning-map/om-skills-learning-map-v5.html)
is the current revision and includes an operator runbook. Open it directly in a
browser; it is self-contained and needs no server. The v4 file beside it is the
earlier revision, kept for reference — start with v5.

## What is installed

[`skills-lock.json`](skills-lock.json) is the authoritative list of installed
skills. It matters here more than in a typical project, because **nothing is
fetched at run time**: a skill referenced by name but not present is a dead end,
not a lazy install. The installed skills reference several that are absent, and
[`AGENTS.md`](AGENTS.md) tracks exactly which ones and what capability each gap
costs — read that table before assuming a named skill will resolve.

Add a skill with the `skills` CLI rather than by hand, since the lockfile hash
comes from the tool:

```bash
npx skills add open-mercato/skills -s <skill-name>
```

Then remove its row from the coverage-gap table in [`AGENTS.md`](AGENTS.md) in
the same change.

## Validating a change

```bash
git diff --check
```

That is the entire gate. This repository has no build system, linter, or test
runner because its content is Markdown rather than compiled code, so the gate is
a hygiene check: it exits non-zero on trailing whitespace and leftover conflict
markers, which are the realistic mechanical defects in a Markdown change. The
real defense is the reading — which is what [`CODE_REVIEW.md`](CODE_REVIEW.md)
is for.

The command list lives in [`.ai/agentic.config.json`](.ai/agentic.config.json).
If this repo ever grows a real toolchain, add commands there and to the
validation-gate section of [`SDLC.md`](SDLC.md) together, then re-run
`om-setup-agent-pipeline`.
