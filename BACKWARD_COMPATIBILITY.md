# Backward compatibility

What this repository treats as a **protected contract surface**, and how a change to one must be handled. Review skills check changes against this file; implementation skills warn when a change violates it.

## What this repo does *not* have

Stated up front so nobody imports rules that do not apply here: there is no exported package API, no HTTP route, no CLI binary, no database schema or migration, and no published event or webhook. The surfaces below are the real ones, and they are all *naming and format* contracts — things another file, another skill, or a tool resolves by exact string.

That makes the failure mode quiet. Nothing fails to compile when a contract breaks here; an agent simply fails to find what it was told to load, or loads the wrong thing, and the damage shows up as behavior.

## Protected surfaces

### 1. Skill names

`.agents/skills/<name>/` and the `name:` in its frontmatter. Skills are invoked by exact name, and other skills reference each other by name in prose.

- **Breaking:** renaming or removing a skill directory; changing `name:` so it no longer matches the directory.
- **Required path:** update every in-repo reference to the old name in the same PR, update `skills-lock.json`, and note the rename in the PR body. Renaming without sweeping references leaves dangling invocations that fail only at run time.

### 2. Reference file paths

`references/<file>.md` inside a skill, and cross-skill pointers of the form `om-<skill>/references/<file>`.

- **Breaking:** renaming, moving, or deleting a reference file that any skill points at.
- **Required path:** grep the repo for the old path and update every pointer in the same PR. If a reference is split, keep the old filename as a stub pointing at the new files for one change cycle rather than deleting it outright.

### 3. `.ai/agentic.config.json` schema

Every `om-*` skill reads this file, most through the standard config-loading snippet with `jq` defaults.

- **Breaking:** removing a field, renaming a key, or changing a value's type or meaning (e.g. `validation.commands` from a list of strings to objects).
- **Non-breaking:** adding a new optional key that skills read with a default, which is how `browser.provider` and `engine.stepReview` were introduced.
- **Required path:** add new keys as optional with a documented default so existing configs keep working unread. For an unavoidable removal, bump `version`, state the old and new shape in the PR body, and update `SDLC.md` in the same change.

### 4. Descriptor operation names

The operations defined in `.ai/trackers/<tracker>.md` and `.ai/browsers/<provider>.md` — **get-issue**, **create-pr**, **comment-pr**, **merge-pr**, **list-labels**, **ensure-label-taxonomy**, **open**, **snapshot**, **screenshot**, and the rest of each contract.

- **Breaking:** renaming or removing an operation, or changing what it returns. Skills dispatch on these names and consume the stated output.
- **Non-breaking:** changing *how* an operation is implemented — a different `gh` invocation, added flags, better error handling. This is the point of the descriptor pattern and needs no ceremony.
- **Required path:** a new operation is additive and safe. Removing one requires confirming no installed skill names it, and saying so in the PR body.

### 5. Directory contract under `.ai/`

`paths.runs`, `paths.analysis`, `paths.specs`, `paths.scripts`, `paths.qa` — skills write to and read from these locations, and `paths.specs` in particular is a handoff point between `om-spec-writing`, `om-prepare-issue`, and `om-brainstorm`.

- **Breaking:** moving a directory without updating the config, or repointing the config while prior artifacts stay behind at the old path.
- **Required path:** change the config and move existing content together; leave a note in the PR body for in-flight runs, whose plans reference absolute-ish paths.

### 6. Skill-discovery symlinks

`.claude/skills/<name>` → `.agents/skills/<name>`.

- **Breaking:** replacing a symlink with a real directory (forks the skill into two sources that then drift), or deleting one (the skill silently stops being discovered).
- **Required path:** keep them symlinks. If a link breaks on a Windows checkout without Developer Mode, recreate the link — never resolve the problem by copying files.

### 7. `skills-lock.json` format

Consumed by the `skills` CLI to reproduce an install: `version`, and per skill `source`, `sourceType`, `skillPath`, `computedHash`.

- **Breaking:** hand-editing the structure, or dropping `computedHash` so an install can no longer be verified.
- **Required path:** let the tooling write this file. When a vendored skill is edited locally — legitimate in a learning lab — the hash drifts from upstream; call that out in the PR body so a later `npx skills add` does not silently revert the edits.

### 8. GitHub label taxonomy

The labels created by `om-setup-agent-pipeline` are shared state that skills and humans both read.

- **Breaking:** deleting or renaming a label in use, which orphans every PR and issue carrying it, or recoloring one so established visual conventions stop holding.
- **Required path:** labels are only ever *added*. This is a hard rule in the skill collection itself: never delete, rename, or recolor an existing label. Retire one by ceasing to apply it, not by removing it.

## Deciding whether a change is breaking

Ask: **could another file, skill, or tool be resolving this exact string?** If yes, the change is breaking and needs the sweep described above. When the answer is unclear, grep for the string across `.agents/`, `.ai/`, and the root docs before changing it — cheap here, and the only reliable check this repo has.
