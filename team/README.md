# Team Directory

This directory contains agent-specific instructions and team coordination documents.

## Agent Instructions

Each AI agent working on this project has their own instruction file:

- **`CLAUDE.md`** - Instructions for Claude (Anthropic) agents
- **`GEMINI.md`** - Instructions for Gemini (Google) agents  
- **`[AGENT_NAME].md`** - Instructions for other agents as needed

## Team Coordination

- **`TEAM_ROLES.md`** - Team role definitions and escalation framework (located at project root, referenced here)
- **Agent handoff procedures** - How agents coordinate work and pass context
- **Shared context management** - How agents maintain project understanding

## Adding New Agents

When adding a new agent to the team:

1. Create `[AGENT_NAME].md` with agent-specific instructions
2. Include reference to universal team roles and documentation standards
3. Define agent's primary responsibilities and specialty areas
4. Establish handoff procedures with existing agents
5. Test agent integration with sample tasks

## Agent Instruction Template

Each agent instruction file should include:

- **Project Overview** - Brief description of the G-Code sender project
- **Agent Role** - Primary responsibilities and specialties
- **Team Structure** - Reference to role-switching system and escalation
- **Documentation Standards** - Reference to documentation strategy
- **Code Standards** - Language-specific coding conventions
- **Communication Protocols** - How to coordinate with other agents
- **Project Context** - Key files, directories, and architectural decisions

## Coordination Guidelines

- Agents should reference the main `/TEAM_ROLES.md` for role definitions
- Use consistent role-switching commands across all agents
- Maintain shared understanding of project goals and user personas
- Follow the same documentation standards regardless of agent
- Coordinate on architectural decisions through proper escalation