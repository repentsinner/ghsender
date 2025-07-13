# Product Brief: A Modern, Safe G-Code Sender

This document defines the product vision, target users, and success criteria for the new G-Code sender application.

## 1. The Problem

Existing G-Code senders for hobbyist CNCs are often unreliable, have high-latency interfaces, and lack robust safety features. This leads to a frustrating user experience, a steep learning curve for beginners, and a high risk of costly mistakes, such as tool collisions and ruined workpieces. Users lack confidence in their tools, and the software often gets in the way of their creativity.

**Critical Gap: Manual Operation Safety**
The most dangerous moments in CNC operation occur during manual interventions - tool changes, workpiece setup, and coordinate system touchoff. Existing senders treat these as afterthoughts, providing little to no guidance during state transitions between automated G-Code execution and manual control. This results in:
- User confusion about machine state and what will happen next
- High accident rates during tool changes and workpiece setup
- Lost productivity from positioning errors and material waste
- Beginners abandoning projects when they encounter manual operations

## 2. User Personas

We are building this for two primary users:

*   **Brenda, the Beginner Hobbyist:** Brenda has just purchased her first CNC machine. **She is excited to learn and eager to build her skills progressively.** She needs software that starts with detailed, slow-paced guidance but adapts as she gains confidence. She values clear explanations and an uncluttered interface over a dense feature set. **Her biggest fear is crashing the machine during manual operations like tool changes or setting up workpieces.** She wants the system to initially walk her through every step with confirmations, but as she demonstrates competency, she wants it to gradually increase the pace and reduce hand-holding. **She needs a system that celebrates her learning progress and builds her confidence over time.**

*   **Mark, the Experienced Maker:** Mark has been using CNCs for years. He is comfortable with G-Code and knows his machine well. He is frustrated by software that is buggy, slow, or unreliable. He values efficiency, keyboard shortcuts, advanced control, and, most importantly, software that he can trust to execute his jobs flawlessly without getting in his way. **He frequently runs complex multi-tool jobs and needs reliable state management during manual interventions.** While he's experienced with CNC operation, **he needs to learn how this software's workflows differ from his current tools.** He wants the option to experience the full safety workflows initially to understand the system's approach, but then quickly graduate to streamlined expert modes. **He appreciates systems that respect his existing knowledge while teaching him new paradigms efficiently.**

## 3. Value Proposition

Our G-Code sender will be the **safest, most reliable, and most user-friendly** option for grblHAL users, designed to become the **#1 G-Code sender platform** that drives grblHAL hardware adoption. We provide a modern, tablet-first interface with low-latency controls and proactive error prevention, giving users the confidence to execute their projects successfully, regardless of their experience level. **Our adaptive learning system grows with users, providing detailed guidance for beginners that gradually evolves into efficient expert workflows as competency increases.**

**Platform Strategy:**
- **Community-Driven Development:** Open architecture enables rapid feature development through community contributions
- **Hardware Ecosystem Growth:** Deep grblHAL integration makes this the preferred software for modern CNC hardware
- **Network Effects:** Learning data and workflow templates create a platform that improves with adoption
- **High Development Velocity:** Extensible architecture allows rapid response to community needs and hardware innovations
- **Proven Design Patterns:** Leverages VS Code's successful platform patterns (JSON settings, command palette, extension marketplace) adapted for CNC workflows

## 4. Minimum Viable Product (MVP)

To deliver on our core value proposition quickly, the MVP will focus on the essentials of safe and reliable machine operation. The goal is to solve the core problem for Brenda, our beginner persona, while providing the stability that Mark, our experienced maker, demands.

**MVP Feature Set:**

1.  **Connection:** Connect to a grblHAL controller via TCP/IP.
2.  **State Display:** A clear, real-time Digital Readout (DRO) and machine status display (e.g., `Idle`, `Run`, `Alarm`).
3.  **Manual Control:** Reliable, low-latency jogging for all axes and the ability to set the work coordinate system zero (`G10 L20 P1 X0 Y0 Z0`).
4.  **G-Code Execution:** Load a G-Code file from the local device and execute it with `Start`, `Pause`, and `Stop` controls.
5.  **Core Safety Feature (The Visualizer):** A 2D/3D visualizer that:
    *   Displays the G-Code toolpath.
    *   Fetches the machine's work envelope from the controller.
    *   Clearly visualizes the work envelope.
    *   **Validates that the toolpath is within the envelope *before* the job can be started.**

6.  **Manual Intervention Workflows:** Streamlined, safety-focused workflows for critical manual operations that occur outside of G-Code execution:
    *   **Tool Changing:** Clear step-by-step guidance for manual tool changes with machine state awareness and collision prevention.
    *   **Workpiece Touchoff:** Intuitive workflows for setting workpiece coordinate systems with real-time feedback and undo capabilities.
    *   **State Transition Management:** Seamless entry/exit between G-Code program execution and manual "sender macro" operations with clear visual indicators of current machine mode.
    *   **Adaptive Learning Workflows:** Progressive workflow adaptation that starts with detailed, confirmed steps and gradually increases automation speed as user competency is demonstrated through successful operations.

*Features explicitly **out of scope for the MVP** include: advanced probing cycles, automated tool changing systems, and complex macro programming.*

## 5. Success Metrics (KPIs)

We will measure our success based on the following Key Performance Indicators:

*   **Adoption Rate:** The number of weekly active users.
*   **Job Success Rate:** The percentage of jobs that complete without a user-initiated stop or a critical error. This is a direct measure of reliability.
*   **Manual Operation Safety Rate:** The percentage of tool changes and workpiece touchoff operations that complete without user errors or safety incidents. This measures the effectiveness of our guided workflow approach.
*   **State Transition Error Rate:** The frequency of user confusion or errors when transitioning between program execution and manual intervention modes. Lower rates indicate clearer UX design.
*   **Learning Progression Rate:** The percentage of users who successfully graduate from beginner to intermediate workflow speeds within their first 10 operations. This measures the effectiveness of our adaptive learning system.
*   **Workflow Efficiency Improvement:** Time reduction in completing standard operations as users progress through learning levels, measuring both system adaptation and user skill development.
*   **User Satisfaction:** Qualitative feedback gathered from community forums and GitHub issues. Post-MVP, we will implement a simple in-app feedback mechanism.
*   **Crash Rate:** The number of application crashes per 1,000 sessions. This measures application stability.

## 6. Key User Journey Impact Analysis

### 6.1. Brenda (Beginner) Journey Enhancement

**Critical Moment: First Tool Change**
- **Current State (Existing Senders):** Brenda panics when her program hits an M6 tool change command. No guidance provided, machine stops, unclear what to do next. High likelihood of collision or abandoning the job.
- **Our Solution:** Step-by-step wizard walks Brenda through safe tool change position, tool removal, installation, and validation. **System starts with individual step confirmations, then gradually groups related steps as Brenda demonstrates competency.** Clear "what happens next" messaging at each step with progress celebration.
- **Success Metric:** >90% of first-time tool changes completed successfully without support requests; >80% of users graduate to intermediate tool change speed by their 5th tool change.

**Critical Moment: Setting Work Zero**
- **Current State:** Brenda struggles with coordinate systems, accidentally crashes tool into workpiece during touchoff, destroys hours of work.
- **Our Solution:** Progressive jogging speeds, clear visual feedback, undo capability, automatic boundary validation after touchoff. **System initially requires confirmation for each axis movement, then adapts to allow multi-axis operations as Brenda shows understanding.**
- **Success Metric:** <5% of touchoff operations result in user-reported errors or do-overs; >70% of users advance to streamlined touchoff mode within 3 successful operations.

### 6.2. Mark (Experienced) Journey Enhancement

**Critical Moment: Migrating from Existing Sender**
- **Current State:** Mark is frustrated by safety "hand-holding" that slows down his workflow. He wants efficiency but not at the cost of reliability.
- **Our Solution:** **Intelligent onboarding that recognizes expertise level and offers "Expert Learning Mode" - shows him the full safety workflow once for understanding, then immediately adapts to streamlined expert interface.** Contextual safety with quick acknowledgment options, keyboard shortcuts for rapid workflow progression.
- **Success Metric:** Mark completes common workflows 20% faster than with existing senders while maintaining safety validation; >90% of experienced users choose and successfully use Expert Learning Mode.

**Critical Moment: Complex Multi-Tool Jobs**
- **Current State:** Mark loses track of program state during multiple tool changes, unsure if coordinate systems are still valid, wastes material on positioning errors.
- **Our Solution:** Clear state preservation display, automatic re-validation after each manual intervention, visual confirmation of coordinate system integrity. **System learns his preferred workflow patterns and suggests optimized sequences for recurring job types.**
- **Success Metric:** >95% of multi-tool jobs complete without positioning errors or material waste; >60% of expert users adopt suggested workflow optimizations.

## 7. Competitive Differentiation

### 7.1. vs. Existing G-Code Senders

**Traditional Senders (UGS, CNCjs, etc.):**
- Treat manual operations as afterthoughts
- Binary "manual mode" with no workflow guidance
- No state transition management
- High accident rates during tool changes and touchoff

**Our Approach:**
- Manual operations are first-class workflows with dedicated UX design
- Structured safety workflows prevent common accidents
- Clear state management reduces user confusion
- Measurable safety improvements through guided processes
- **Adaptive learning system that grows with user competency - no other sender provides progressive workflow evolution**
- **Intelligent expertise recognition for experienced users migrating from other tools**

### 7.2. vs. Professional Controllers

**Professional Controllers (Haas, Fanuc, etc.):**
- Handle tool changes and probing automatically within controller firmware
- Expensive, complex setup, not suitable for hobbyist market
- Less flexibility for custom workflows

**Our Approach:**
- Brings professional-level workflow safety to hobbyist hardware
- Maintains flexibility and customization that hobbyists value
- Software-based solution works with existing grblHAL hardware
- Significantly lower cost while improving safety outcomes

### 7.3. Operation Mode Differentiation (Key Innovation)

**Critical Insight: Different CNC Operations Require Fundamentally Different Workflows**

Most existing G-Code senders treat all CNC operations identically, forcing users to adapt universal workflows to specialized needs. **We recognize that CNC routers perform fundamentally different operation types that require tailored coordinate systems and workflows.**

**Mode-Based Workflow System:**

**Through-Cutting Sheet Goods Mode:**
- **Coordinate System**: XY origin on workpiece top (accessible), Z-zero on spoilboard surface (reference plane)
- **Workflow Focus**: Material thickness measurement, spoilboard preservation, cut-through validation
- **Use Cases**: Plywood cutting, MDF projects, aluminum sheet work, production cutting
- **Key Benefit**: Consistent cut-through regardless of material thickness variation

**Surface Operations Mode:**
- **Coordinate System**: Traditional workpiece-top Z-zero for surface operations
- **Workflow Focus**: Surface quality, depth control, feature precision
- **Use Cases**: Sign engraving, 3D carving, surface texturing, inlay work
- **Key Benefit**: Precise depth control relative to workpiece surface

**Production Batch Mode:**
- **Coordinate System**: Fixture-based references for repeated setups
- **Workflow Focus**: Setup repeatability, changeover efficiency, quality consistency
- **Use Cases**: Multiple identical parts, production runs, jig-based work
- **Key Benefit**: Rapid setup changes while maintaining accuracy

**Competitive Advantage:**
- **No Other Sender** provides operation-specific coordinate system workflows
- **Eliminates User Confusion** about when to use different setup approaches
- **Matches Real-World Practice** instead of forcing universal compromises
- **Reduces Setup Errors** by providing appropriate guidance for each operation type
- **Improves Results** through operation-optimized workflows

**Implementation Strategy:**
- Project templates automatically configure appropriate coordinate system approach
- Mode selection guides users to correct workflow for their operation
- Visual indicators and validation specific to each operation type
- Seamless switching between modes for users who do mixed work

This mode-based approach **fundamentally changes how users think about CNC setup**, moving from "one size fits all" to "right tool for the job" - a key differentiator that existing senders cannot easily replicate without architectural changes.

## 8. Feature Prioritization Framework

### 8.1. Safety-First Prioritization

All features are evaluated against their safety impact:

**Priority 1 (Safety Critical):**
- Manual operation workflows (tool change, touchoff)
- State transition management
- Emergency stop functionality
- Boundary validation

**Priority 2 (Reliability Critical):**
- Real-time state synchronization
- Error recovery procedures
- Connection management
- Performance optimization

**Priority 3 (User Experience):**
- UI polish and responsiveness
- Keyboard shortcuts
- Customization options
- Advanced features

### 8.2. Persona-Driven Development

**Brenda-First Features (Beginner Safety):**
- Step-by-step workflow wizards with adaptive pacing
- In-context help and explanations that reduce as competency grows
- Visual confirmation of machine state with progress celebration
- Undo capabilities for manual operations
- **Learning progression tracking and milestone recognition**

**Mark-Efficiency Features (Expert Productivity):**
- Expert Learning Mode for rapid workflow understanding
- Keyboard shortcuts for common workflows
- Batch operation capabilities
- Advanced state monitoring
- Workflow customization options
- **Pattern recognition and workflow optimization suggestions**

**Dual-Benefit Features (Serve Both):**
- Clear visual feedback systems that adapt to user experience level
- Reliable state management with learning-appropriate detail levels
- Performance optimization that maintains responsiveness across all skill levels
- Cross-platform consistency
- **Adaptive workflow speeds that accelerate as competency is demonstrated**
- **VS Code-style configuration system:** GUI for beginners, JSON editing for experts
- **Command palette:** Rapid access to all functions for efficient workflows

## 9. Post-MVP Roadmap Considerations

### 9.1. Immediate Post-MVP (Version 1.1)

Based on manual operation workflow foundation:

**Enhanced Workflow Features:**
- Custom tool change sequences
- Advanced probing cycles integrated with touchoff workflows
- Macro integration within workflow contexts
- Multi-workpiece setup workflows

**Safety Enhancements:**
- Machine learning-based collision prediction
- Advanced boundary checking with tool geometry
- Automated recovery suggestions for common errors

### 9.2. Future Versions (1.x - 2.0)

**Workflow Automation:**
- Semi-automated tool changing with manual verification
- Intelligent workpiece setup suggestions
- Integration with CAM software for enhanced tool validation
- Community-shared workflow templates

**Professional Features:**
- Production job management
- Batch processing capabilities
- Advanced analytics and optimization
- Integration with inventory management systems

## 10. Success Validation Strategy

### 10.1. Quantitative Validation

**Safety Metrics:**
- Track manual operation success rates vs. existing senders
- Measure reduction in user-reported accidents/collisions
- Monitor tool change and touchoff completion rates

**Workflow Metrics:**
- Time-to-completion for common manual operations
- Error recovery success rates
- State transition confusion incidents

### 10.2. Qualitative Validation

**User Journey Testing:**
- Observe first-time tool change experiences
- Document workflow pain points and solutions
- Validate safety feature effectiveness in real scenarios

**Community Feedback:**
- Monitor support requests related to manual operations
- Track feature request patterns
- Measure user confidence improvements through surveys

## 11. Adoption Success Architecture

### 11.1. Post-MVP Growth Strategy

**Rapid Feature Development Capability:**
Our architecture is specifically designed to support the rapid feature iteration required for dominant market adoption in the maker community:

- **Plugin Architecture:** Community can contribute specialized workflows, hardware drivers, and CAM integrations
- **Event-Driven Services:** New features can be added without modifying existing code
- **Learning System Extensibility:** Custom competency tracking for specialized techniques and machine types
- **Progressive UI Framework:** Complex features can be introduced gradually based on user skill level
- **High Development Velocity:** Clean separation enables parallel feature development and rapid response to community needs

### 11.2. Community Ecosystem Development

**Open Source Workflow Marketplace:**
- **Template Sharing:** Users can share and download custom workflow templates
- **Community Validation:** Peer review system for community-contributed workflows
- **Specialized Learning Paths:** Machine-specific and technique-specific progression sequences
- **Integration Hub:** Direct connections to popular CAM software and online learning platforms
- **Hardware Vendor Partnerships:** Official workflow templates for specific machine manufacturers

**Community Engagement Drivers:**
- **Open Source Plugin Development:** Full community access to extension APIs
- **GitHub Integration:** Seamless community contribution workflow
- **Recognition System:** Contributor acknowledgment and community status
- **Learning Community:** Shared progression tracking and peer learning
- **Hardware Ecosystem Support:** Platform drives adoption of grblHAL-compatible hardware

### 11.3. Market Dominance Strategy

**Network Effects for Adoption:**
- **Learning Data:** Anonymized competency progression improves adaptive algorithms for all users
- **Workflow Templates:** Community contributions increase platform value and attract new users
- **Hardware Ecosystem:** Preferred software for grblHAL hardware vendors drives adoption
- **Skill Recognition:** Portable competency profiles create user investment and community retention
- **Developer Community:** Active plugin ecosystem attracts users and creates contribution momentum

**Adoption Barriers for Competitors:**
- **Adaptive Learning System:** Difficult for competitors to replicate without architectural foundation
- **Safety Integration:** Deep integration of safety workflows creates differentiation that's hard to bolt-on
- **Performance Optimization:** Real-time operation requirements create technical barriers to entry
- **Cross-Platform Consistency:** Unified experience across devices difficult to achieve with other frameworks
- **Community Momentum:** Established plugin ecosystem and learning content creates switching friction

### 11.4. Adoption Scalability

**User Base Scaling:**
- **Performance Optimization:** Maintains responsiveness as feature set grows
- **Lazy Loading:** Complex features loaded only when needed to support diverse user needs
- **Background Processing:** Heavy operations in isolates maintain UI responsiveness for all users
- **Progressive Enhancement:** Features gracefully degrade on older hardware, maximizing addressable market

**Community Scaling:**
- **Modular Architecture:** Community can develop features independently without conflicts
- **Plugin Ecosystem:** Distributed development scales beyond core team capacity
- **Version Management:** Data models support backward compatibility for long-term community investment
- **Feature Flags:** Gradual rollout enables safe experimentation with community features
- **Documentation Framework:** Scalable knowledge base grows with community contributions

**Hardware Ecosystem Scaling:**
- **grblHAL Focus:** Deep integration drives adoption of modern CNC hardware
- **Vendor Partnerships:** Official support from hardware manufacturers
- **Machine-Specific Optimizations:** Plugin architecture supports specialized hardware features
- **Cross-Platform Reach:** Single codebase maximizes hardware vendor addressable market
