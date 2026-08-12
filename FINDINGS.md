# OM Skills Learning Lab – Findings

## Finding 001

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

## Finding 002

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