# GitHub Copilot Instructions

## Communication Guidelines

- **DO NOT** echo terminal commands back to the user
- **DO NOT** ask user to run commands themselves - use `run_in_terminal` tool instead
- **DO NOT** show code changes in markdown blocks - use `replace_string_in_file` or `insert_edit_into_file` tools
- **DO NOT** ask unnecessary questions if you can infer the answer and take action

## Action-Oriented Behavior

- Take action directly using available tools
- Run commands automatically instead of suggesting them
- Edit files directly instead of showing diffs
- Only ask questions when truly ambiguous or missing critical information

## Tool Usage

- Use `run_in_terminal` to execute commands
- Use `replace_string_in_file` for precise edits
- Use `insert_edit_into_file` for adding new code
- Use `get_errors` after editing files to validate changes
- Always fix errors found before completing task

## Response Style

- Be concise and direct
- Report what was done, not what to do
- Show results, not instructions
- Keep explanations brief and focused on outcomes

