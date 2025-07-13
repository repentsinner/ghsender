# Agent Coordination Guide: Claude vs Gemini

**Author**: Claude (Self-Assessment) & Team  
**Date**: 2025-07-13  
**Purpose**: Define complementary strengths and handoff strategies for effective multi-agent collaboration

## Agent Capability Matrix

### Claude (Anthropic) Strengths

#### Core Capabilities
- **Long-form reasoning and analysis** - Complex problem decomposition, systematic thinking
- **Comprehensive documentation creation** - Detailed technical writing, structured documentation
- **Code review and architecture** - Deep code analysis, design pattern recognition
- **Workflow design** - Complex multi-step processes, user journey mapping
- **Safety-critical analysis** - Risk assessment, failure mode analysis
- **Conversational context retention** - Maintaining context across long interactions

#### Specific Use Cases Where Claude Excels
- **Architecture Decision Records (ADRs)** - Systematic decision documentation
- **Complex workflow documentation** - Multi-step processes with safety considerations
- **User persona development** - Detailed user journey and competency modeling
- **Requirements analysis** - Breaking down complex requirements into actionable items
- **Code refactoring guidance** - Systematic code improvement strategies
- **Documentation strategy** - Comprehensive docs-as-code implementation
- **Product management thinking** - Market fit analysis, feature prioritization
- **Long technical discussions** - Sustained reasoning over complex topics

### Claude Limitations

#### Areas Where Claude Struggles
- **Visual content creation** - Cannot generate images, diagrams, or visual mockups
- **Real-time web research** - Limited to specific web fetch operations
- **Rapid code generation** - Tends toward over-documentation and analysis
- **Creative visual solutions** - Cannot iterate on visual design concepts
- **Multi-language code examples** - Less fluent in rapid cross-language prototyping
- **Performance optimization** - Limited real-time performance analysis capabilities

---

### Gemini (Google) Strengths

#### Core Capabilities
- **Multimodal processing** - Can analyze and potentially generate visual content
- **Rapid code generation** - Quick prototyping and boilerplate creation
- **Real-time research** - Web search integration and current information access
- **Creative problem solving** - Alternative approaches and innovative solutions
- **Cross-language fluency** - Strong across multiple programming languages
- **Performance analysis** - Code optimization and efficiency improvements

#### Specific Use Cases Where Gemini Excels
- **UI/UX mockups and wireframes** - Visual interface design and iteration
- **Code prototyping** - Rapid proof-of-concept development
- **Technology research** - Current framework comparison, library evaluation
- **Visual documentation** - Diagrams, flowcharts, system visualizations
- **Performance optimization** - Code efficiency analysis and improvement
- **Creative feature brainstorming** - Innovative solution generation
- **Cross-platform compatibility** - Multi-platform development strategies
- **Real-time troubleshooting** - Current error research and resolution

### Gemini Limitations

#### Areas Where Gemini May Struggle
- **Extended context retention** - May lose context in very long interactions
- **Deep documentation strategy** - Less focus on comprehensive documentation systems
- **Safety-critical analysis** - May prioritize innovation over systematic safety
- **Long-form reasoning** - May prefer rapid solutions over thorough analysis
- **Process documentation** - Less emphasis on detailed workflow documentation

---

## Handoff Decision Matrix

### When Claude Should Hand Off to Gemini

| Task Type | Handoff Trigger | Gemini Advantage |
|-----------|----------------|------------------|
| **Visual Design** | Need for UI mockups, diagrams, or visual content | Multimodal capabilities |
| **Rapid Prototyping** | Need quick proof-of-concept or boilerplate code | Faster code generation |
| **Technology Research** | Need current framework/library comparisons | Real-time research access |
| **Performance Issues** | Code optimization or efficiency problems | Performance analysis tools |
| **Creative Solutions** | Stuck on conventional approaches | Creative problem-solving |
| **Cross-Platform Code** | Need multi-platform implementation examples | Cross-language fluency |
| **Current Information** | Need latest documentation or trends | Web research capabilities |

**Claude Handoff Signal**: *"This task would benefit from Gemini's [specific capability]. Gemini, could you take over for [specific deliverable]?"*

### When Gemini Should Hand Off to Claude

| Task Type | Handoff Trigger | Claude Advantage |
|-----------|----------------|------------------|
| **Documentation Strategy** | Need comprehensive docs-as-code implementation | Long-form documentation expertise |
| **Safety Analysis** | CNC safety workflows or risk assessment | Safety-critical thinking |
| **Complex Workflows** | Multi-step user workflows with adaptive guidance | Systematic workflow design |
| **Architecture Decisions** | Major technical architecture choices | Deep reasoning and ADR creation |
| **User Research** | Persona development or user journey mapping | User-centered design thinking |
| **Requirements Analysis** | Complex requirement decomposition | Systematic analysis |
| **Long-term Planning** | Strategic product or technical roadmaps | Sustained reasoning |

**Gemini Handoff Signal**: *"This requires deep analysis that Claude handles better. Claude, could you take over for [specific deliverable]?"*

---

## Collaboration Patterns

### Parallel Work Distribution

#### Claude Focus Areas
- **Product Management** - User stories, requirements, roadmap planning
- **Technical Writing** - Comprehensive documentation, workflow guides
- **Architecture** - System design, integration patterns, decision records
- **Safety & Quality** - Risk analysis, testing strategy, safety workflows
- **Process Design** - Development workflows, team coordination

#### Gemini Focus Areas
- **Visual Design** - UI mockups, system diagrams, visual documentation
- **Development** - Code generation, prototyping, performance optimization
- **Research** - Technology evaluation, competitive analysis, current trends
- **Innovation** - Creative solutions, alternative approaches, feature ideation
- **Implementation** - Cross-platform code, build systems, deployment

### Sequential Handoff Patterns

#### Pattern 1: Research → Analysis → Implementation
1. **Gemini**: Research current best practices and technologies
2. **Claude**: Analyze findings and create comprehensive strategy
3. **Gemini**: Implement proof-of-concept based on strategy

#### Pattern 2: Design → Documentation → Validation
1. **Gemini**: Create visual mockups and interaction designs
2. **Claude**: Document detailed workflows and user journeys
3. **Gemini**: Build interactive prototypes for validation

#### Pattern 3: Problem → Solution → Documentation
1. **Claude**: Analyze complex problem and requirements
2. **Gemini**: Generate creative solutions and implementations
3. **Claude**: Document solution rationale and maintenance procedures

---

## Communication Protocols

### Context Handoff Template
```markdown
## Handoff to [Agent Name]

**Task**: [Specific deliverable needed]
**Context**: [Relevant background information]
**Previous Work**: [What has been completed]
**Specific Request**: [What the receiving agent should focus on]
**Success Criteria**: [How to know the task is complete]
**Return Handoff**: [When to hand back and what deliverables to provide]

**Files Modified/Created**: [List of relevant files]
**Key Constraints**: [Important limitations or requirements]
```

### Status Update Template
```markdown
## Progress Update from [Agent Name]

**Completed**: [What was finished]
**Current Status**: [What is in progress]
**Challenges**: [Issues encountered]
**Next Steps**: [Planned actions]
**Handoff Ready**: [Yes/No - ready to hand back]
**Output Files**: [New or modified files]
```

### Shared Agent Workspace Protocol

**Purpose**: The `SHARED_WORKSPACE.md` file serves as the primary, local, and untracked log for asynchronous agent-to-agent communication and status updates. It is designed to facilitate real-time coordination without cluttering the Git history with transient operational details.

**Usage Guidelines**:
- **Local Only**: This file is intentionally untracked by Git (via `.gitignore`). Changes made to it will not be committed to the repository.
- **Ephemeral Log**: It acts as a dynamic, session-based log for ongoing agent activities, status, and brief messages.
- **Read First**: Agents should always read `SHARED_WORKSPACE.md` at the beginning of a session to understand recent activities and current context from other agents.
- **Update Regularly**: Agents must update their status and log significant actions in `SHARED_WORKSPACE.md` after completing work, even if those actions are not committed to Git. Use the `tools/generate_log_entry.sh` script to ensure consistent formatting and system-generated timestamps. Example: `tools/generate_log_entry.sh "Gemini" "Updated AGENT_COORDINATION.md" "team/AGENT_COORDINATION.md" "Added instructions for using generate_log_entry.sh"`
- **Time Synchronization**: When reading `SHARED_WORKSPACE.md`, agents should use a system tool (e.g., `date` command) to get the current time. This helps in understanding the relative age of log entries and their position within the timeline, compensating for any internal clock discrepancies.
- **No Version Control**: Do not attempt to commit `SHARED_WORKSPACE.md` to the repository. Its purpose is to be a local, unversioned communication channel.

### Conflict Resolution
When agents disagree on approach:
1. **Document both perspectives** in a comparison format
2. **Escalate to Product Manager role** for business priority decision
3. **System Architect role** makes final technical decision
4. **Record decision** as ADR for future reference

---

## Quality Assurance

### Cross-Agent Review
- **Claude reviews Gemini's documentation** for completeness and consistency
- **Gemini reviews Claude's code examples** for efficiency and modern practices
- **Both agents validate** against project requirements and user personas

### Consistency Checks
- **Same role-switching commands** used by both agents
- **Consistent documentation style** across all outputs
- **Unified voice** in user-facing documentation
- **Aligned architectural decisions** through proper escalation

### Success Metrics
- **Reduced handoff friction** - Smooth transitions between agents
- **Complementary outputs** - Each agent's work enhances the other's
- **Consistent quality** - No degradation when switching agents
- **Faster delivery** - Combined capabilities exceed individual performance

---

## Examples of Effective Collaboration

### Example 1: Feature Development
**Scenario**: Add new machine connection workflow

1. **Claude**: Analyze user safety requirements and create workflow documentation
2. **Gemini**: Research current TCP/IP libraries and create connection prototype
3. **Claude**: Review prototype for safety considerations and document implementation
4. **Gemini**: Optimize performance and add error handling
5. **Claude**: Create comprehensive user documentation and testing procedures

### Example 2: Architecture Decision
**Scenario**: Choose between Flutter and Electron for desktop app

1. **Gemini**: Research current capabilities, performance, and ecosystem
2. **Claude**: Analyze against project requirements and create decision matrix
3. **Gemini**: Create proof-of-concept implementations in both frameworks
4. **Claude**: Document final decision as ADR with rationale and consequences

### Example 3: Documentation Overhaul
**Scenario**: Improve user onboarding documentation

1. **Claude**: Analyze current user journey and identify pain points
2. **Gemini**: Create visual workflow diagrams and UI mockups
3. **Claude**: Write comprehensive step-by-step guides
4. **Gemini**: Build interactive examples and troubleshooting tools
5. **Claude**: Create testing procedures and success metrics

This coordination guide ensures both agents work to their strengths while maintaining project consistency and quality.