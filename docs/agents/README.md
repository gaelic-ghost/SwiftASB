# AgentSB Reports

`docs/agents/` stores durable maintainer reports created by AgentSB, the
repo-local maintenance agent app for SwiftASB.

Reports under `docs/agents/reports/` are tracked maintainer records. They are
intended to survive local cleanup tools and should be reviewed like other
repository documentation before commit.

AgentSB version one is report-first. A normal report run may create a new
Markdown file in `docs/agents/reports/`, but it must not promote generated wire
snapshots, edit Swift public API, tag releases, or change release automation.
