# Code review rules

Applied automatically by `om-code-review` (and therefore by `om-auto-review-pr`) in addition to that skill's built-in checklist. These rules are specific to what this repository actually contains: Markdown skill definitions, committed operation descriptors, and pipeline configuration. There is no compiled code here, so the usual "does it build" signal is absent — the reviewer's reading is the primary defense.

## Review priorities

1. **Correctness of instructions.** A skill file is executed by an agent. Review it the way you would review code: does every step have a defined input, an unambiguous action, and a stated outcome? Ambiguity is a defect, not a style nit.
2. **Safety and scope.** Does the change widen what an agent may do — new commands, new network access, new write targets, weakened confirmation? That needs explicit justification in the PR body.
3. **Contract stability.** Does the change alter a surface other skills depend on? See `BACKWARD_COMPATIBILITY.md`.

## Repo-specific checks

### Skill definitions (`.agents/skills/<name>/SKILL.md`, `references/*.md`)

- Frontmatter `name` matches the containing directory exactly; skill resolution is by name.
- The `description` reads as *trigger conditions* ("use when…"), not as a summary. A dispatcher sees only this text.
- `SKILL.md` stays a router: new detail belongs in `references/<topic>.md`, referenced from the body. Reject changes that inline a long procedure into `SKILL.md`.
- Every internal pointer resolves — `references/<file>.md` exists, and cross-skill pointers use the `om-<skill>/references/<file>` form.
- Numbered workflow steps stay consistently numbered after an insertion or deletion, and every step referenced elsewhere in the file ("see step 4") still points at the right step.
- Config fields named in a skill exist in `.ai/agentic.config.json`'s schema, and defaults quoted in prose match the defaults the config actually carries.

### Shell snippets inside skill files

- Externally-sourced values (issue ids, PR numbers, branch names, slugs, provider names) are validated before interpolation — numeric where expected, otherwise `^[A-Za-z0-9._/-]+$` — and stay quoted. An unquoted `$VAR` in a command line is a blocker.
- No secrets, tokens, or `.env` content in examples, output, or logs.
- Destructive operations (force-push, history rewrite, bulk close/delete, `rm -rf`) are gated behind explicit user confirmation, never implied by an earlier approval.

### Descriptors (`.ai/trackers/*.md`, `.ai/browsers/*.md`)

- Every operation the contract requires is present and named exactly as the template names it; skills dispatch on those names.
- Label mutations go through the descriptor's guards (`label_exists`, `apply_label`, `apply_issue_label`, `remove_issue_label`, `set_pipeline_label`). A raw `gh label`/`gh issue edit` call outside a guard is a bug.
- No operation deletes, renames, or recolors an existing label.

### Pipeline config (`.ai/agentic.config.json`)

- Valid JSON, and `SDLC.md` updated in the same PR when the process it describes changes.
- Label groups stay internally consistent: pipeline labels mutually exclusive, `needs-qa` and `skip-qa` never both present in guidance.
- No secrets, tokens, or user identities — this file is committed team configuration.

### Symlinks and the lockfile

- `.claude/skills/<name>` entries remain symlinks into `.agents/skills/`. A PR that converts one into a real directory forks the skill into two sources and must be rejected.
- `skills-lock.json` changes are explained: a changed `computedHash` means either a re-pull or a local edit to a vendored skill, and the PR body says which.

### Documentation

- Claims about the repo are true of *this* repo. Boilerplate imported from another project — commands that do not exist here, directories that are not present — is a finding.
- Markdown tables and fenced blocks are well-formed; relative links resolve.

## Severity guidance

- **Blocker** — unsafe widening of agent authority; an unquoted or unvalidated interpolation; a broken or forked skill-discovery symlink; a skill instruction that contradicts `SDLC.md`; secrets in the diff.
- **Major** — a missing or misnamed descriptor operation; a dangling reference pointer; a config change without the matching `SDLC.md` update; an ambiguous instruction that would plausibly send an agent down the wrong path.
- **Minor** — wording, formatting, table alignment, and non-load-bearing inconsistencies. Note them; do not block on them.

Blockers and majors are fixed before approval. Minors may be deferred to a follow-up issue via `om-followup-issue-from-pr`.

## Validation

The reviewer confirms the gate ran: `git diff --check`. Because that gate catches only whitespace and conflict markers, an approving review here is a statement about the *reading*, not about a green build — say so plainly in the review body rather than implying automated coverage this repo does not have.
