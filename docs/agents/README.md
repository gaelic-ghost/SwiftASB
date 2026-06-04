# AgentSB Reports

`docs/agents/` stores durable maintainer reports created by AgentSB, the
repo-local maintenance agent app for SwiftASB.

Reports under `docs/agents/reports/` are tracked maintainer records. They are
intended to survive local cleanup tools and should be reviewed like other
repository documentation before commit.

AgentSB version one is report-first. A normal report or maintenance run may
create new Markdown files in `docs/agents/reports/`, but it must not promote
generated wire snapshots, edit Swift public API, tag releases, or change release
automation.

See [`agentsb-roadmap.md`](agentsb-roadmap.md) for the eval, schema diffing,
draft-patch, and safe auto-apply workflow.

See [`codex-direct-read-plan.md`](codex-direct-read-plan.md) for the AgentSB
prototype plan for read-only Codex storage inspection. The intended SwiftASB
feature direction lives in
[`../maintainers/codex-direct-thread-storage-plan.md`](../maintainers/codex-direct-thread-storage-plan.md).
