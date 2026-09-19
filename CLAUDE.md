# Tube2Reaper — Claude context

Read and follow the shared project context in [AGENTS.md](AGENTS.md) before
making changes. It is the source of truth for architecture, user preferences,
module responsibilities, testing, and known limitations. Read [README.md](README.md)
for installation and user workflows.

@AGENTS.md

Key constraint: this is a REAPER-native Lua project with minimal dependencies.
The former Python scaffold was removed as unused. Preserve optional tempo review:
Automatic saves without a confirmation; Review prompts; Off skips analysis.

Maintain detailed project context in AGENTS.md so Codex and Claude stay aligned,
rather than duplicating it here.
