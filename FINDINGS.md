# OM Skills Learning Lab – Findings

## Finding 001  (Lesson 1-2)

### Question

What is the first Open Mercato skill?

### Evidence

`om-setup-agent-pipeline` states:

> "It is the first skill to run in a fresh repository."

### Observation

The setup created:

- .ai/
- AGENTS.md
- SDLC.md
- CODE_REVIEW.md
- BACKWARD_COMPATIBILITY.md

### Conclusion

The engineering pipeline is bootstrapped before any implementation skills are used.

---

## Finding 002 (Lesson 1-2)

### Question

What is the central configuration?

### Evidence

SKILL.md:

> "Every skill reads `.ai/agentic.config.json`."

### Observation

The config contains:

- validation
- labels
- tracker
- paths
- engine

It contains no application framework configuration.

### Conclusion

Open Mercato centralizes engineering-process configuration rather than application-stack configuration.

---

## Finding 003

### Question

Why does `AGENTS.md` exist if `.ai/agentic.config.json` already exists?

### Evidence

`AGENTS.md` contains a **Task routing** section that maps task types to the documents an agent should read first (for example, pipeline changes → `.ai/agentic.config.json` + `SDLC.md`, skill editing → `SKILL.md` + `references/`).

`.ai/agentic.config.json` contains only structured pipeline configuration such as validation commands, labels, engine settings and artifact paths.

### Observation

The two files have different responsibilities.

- `agentic.config.json` configures the engineering pipeline.
- `AGENTS.md` explains how an agent should navigate the repository and which documents become authoritative for a given task.

### Conclusion

Open Mercato separates **configuration** from **repository guidance**.

`agentic.config.json` defines **how the pipeline is configured**, while `AGENTS.md` acts as a **knowledge router**, directing agents to the correct documentation before making changes.