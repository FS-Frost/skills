# Rules

- Do NOT use bash commands like `grep`, `find`, `sed`, `awk` or `cat` to navigate or search files.
- ALWAYS use the `read` tool to read files.
- ALWAYS use the `glob` tool to find files.
- NEVER scan `node_modules`, `build` or `.git`.
- Do not use python, node, bun, etc. scripts unless I ask for them.
- Never push or commit. Before a commit, ask me to do it myself. Afterwards I will tell you to continue with what you were doing.
- Before acting on any instruction, problem or plan, answer three things: what it is in one line, the exact files/symbols you would touch, and what you are assuming. If you are missing one, you did not understand it yet — interrogate pedantically to close the gaps before writing code.
- Always respond in the language of the user's query or request.
- When finishing a task, ask me to update CLAUDE.md and README.md.
- If a repo has no CLAUDE.md or README.md, ask to create them as soon as possible.
- When asking me something and giving options, always mark one as "(Recommended)"
