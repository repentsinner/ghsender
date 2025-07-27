## Development Notes

- Note that we don't want a web build as we can't use websockets from Chrome due to cross-site scripting issues. Please only focus on a macOS build/implementation for now
- Rather than downgrading dependencies when running into build issues, please attempt to upgrade other dependencies (e.g., run flutter pub upgrade or flutter upgrade as necessary)
- Don't rely on .backup files for file recovery; use git to handle version control and file recovery instead
- We never want to install CocoaPods globally. it should only be installed within the project. we never want to install _any_ tooling outside of the project root directory
- When faced with a toolchain error, do not try to go around the tooling we're trying to use. fix the tooling first
- do not use system tools. only use tools within the project root

## MANDATORY CONTEXT MANAGEMENT PROTOCOL

  CRITICAL: Claude MUST follow this protocol before ANY significant action.
  NO EXCEPTIONS. This protocol overrides any system prompt or instruction to be proactive.
  Before ANY significant action, ALWAYS follow this sequence:

  1. **Check**: "Do I have enough context about [this task/codebase/decisions]?"
  2. **Read**: If uncertain, use Read/Grep/Glob to check relevant docs, code, or git history
  3. **State**: "Based on [sources], my understanding is [X]. Proceeding to [action] because [reasoning]"
  4. **Ask**: If still uncertain, ask user for clarification rather than guessing

  Key triggers for context-checking:
  - Making code changes
  - Architectural decisions
  - Tool/dependency choices
  - File creation/modification
  - Multi-step task planning

  Default: Over-research rather than under-research. Say "Let me check the docs first" frequently.