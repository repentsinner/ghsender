# Planned Features and Product Vision

**Last Updated**: January 18, 2025  
**Status**: Vision document - Most features not yet implemented

## Product Vision

ghSender aims to be the **safest, most reliable, and most user-friendly** G-code sender for grblHAL users, designed to become the **#1 G-code sender platform** that drives grblHAL hardware adoption.

### Core Value Proposition

**Long-term Vision**: Modern, tablet-first interface with low-latency controls and proactive error prevention, giving users confidence to execute projects successfully. An adaptive learning system that grows with users, providing detailed guidance for beginners that gradually evolves into efficient expert workflows.

**Current Reality**: High-performance 3D visualizer with ultra-responsive communication - foundation technology proven, advanced features in development.

## Target Users

### Brenda, the Beginner Hobbyist
- **Profile**: Just purchased first CNC machine, excited to learn progressively
- **Needs**: Detailed guidance that adapts as skills develop
- **Fears**: Crashing machine during manual operations
- **Solution**: Step-by-step workflows with safety validation and progress celebration

### Mark, the Experienced Maker  
- **Profile**: Years of CNC experience, values efficiency and reliability
- **Needs**: Fast, reliable software that doesn't get in the way
- **Challenges**: Learning new workflow paradigms while maintaining productivity
- **Solution**: Expert learning mode with rapid workflow understanding and optimization

## Planned Feature Categories

### 🛡️ **Safety-First Architecture** (Phase 2)

#### **Work Envelope Protection**
- Real-time boundary checking against machine limits
- Visual work envelope display in 3D visualizer
- Pre-flight validation of entire G-code programs
- Tool geometry collision detection

#### **Emergency Systems**
- Hardware emergency stop integration
- Software emergency stop with immediate command halt
- Automatic safe positioning after emergency events
- Recovery procedures with state validation

#### **Validation Engine**
- Pre-run simulation with collision detection
- Feed rate and acceleration limit validation
- Tool change compatibility verification
- Coordinate system integrity checking

### 🔧 **Manual Operation Workflows** (Phase 2)

#### **Tool Change Management**
- Step-by-step tool change guidance
- Automatic safe positioning for tool access
- Tool length measurement and offset calculation
- Tool validation and compatibility checking
- Progress tracking and error recovery

#### **Workpiece Setup**
- Interactive touchoff procedures with multiple probe options
- Coordinate system setup and validation
- Work holding verification and safety checks
- Setup documentation and repeatability

#### **Manual Machine Control**
- Progressive jogging speeds (rapid → medium → fine)
- Safety-validated manual positioning
- Real-time position feedback with work envelope display
- Undo capability for positioning errors

### 🧠 **Adaptive Learning System** (Phase 3)

#### **Skill Assessment**
- Track successful operation completions
- Calculate competency levels for different operation types
- Recognize workflow patterns and optimization opportunities
- Measure learning progression over time

#### **Progressive UI Complexity**
- Start with detailed, confirmed steps for beginners
- Gradually group related operations as competency grows
- Streamline expert workflows while maintaining safety validation
- Provide clear skill level indicators and milestone celebration

#### **Expert Learning Mode**
- Rapid onboarding for experienced users
- Complete workflow experience for understanding
- Immediate graduation to streamlined expert interface
- Pattern recognition and workflow optimization suggestions

### 📱 **Touch-First Interface** (Phase 3)

#### **Tablet Optimization**
- Large, touch-friendly controls optimized for workshop use
- Gesture-based navigation and interaction
- High-contrast display for various lighting conditions
- Ruggedized interface design for shop floor environments

#### **Responsive Design**
- Seamless adaptation from tablet to desktop
- Context-aware control sizing and placement
- Orientation-aware layouts
- Accessibility features for various user needs

### 🔌 **Plugin Architecture** (Phase 3)

#### **VS Code-Style Extensions**
- Community-developed workflow templates
- Hardware-specific drivers and configurations
- CAM software integrations
- Custom macro systems and automation

#### **Marketplace Ecosystem**
- Workflow template sharing and rating
- Plugin discovery and installation
- Community contribution recognition
- Quality assurance and security validation

#### **Configuration Management**
- JSON settings with GUI overlay
- Beginner-friendly guided configuration
- Expert-mode direct JSON editing
- Import/export for sharing and version control

## Detailed Feature Specifications

### **Operation Mode Differentiation** (Key Innovation)

**Through-Cutting Sheet Goods Mode:**
- XY origin on workpiece top, Z-zero on spoilboard surface
- Material thickness measurement workflows
- Cut-through validation and spoilboard preservation
- Optimized for plywood, MDF, aluminum sheet work

**Surface Operations Mode:**
- Traditional workpiece-top Z-zero for surface operations
- Surface quality and depth control focus
- Optimized for engraving, 3D carving, texturing, inlay work

**Production Batch Mode:**
- Fixture-based references for repeated setups
- Setup repeatability and changeover efficiency
- Quality consistency across production runs
- Optimized for multiple identical parts and jig-based work

### **Advanced Safety Features** (Phase 2+)

#### **Machine Learning Collision Prediction**
- Analyze toolpath patterns for potential collision risks
- Learn from near-miss events and user corrections
- Predictive warnings before dangerous operations
- Continuous improvement from community data

#### **Intelligent Error Recovery**
- Context-aware error diagnosis and suggested solutions
- Automatic recovery procedures for common issues
- Learning from successful recovery patterns
- Progressive error prevention through pattern recognition

### **Community Integration** (Phase 3+)

#### **Workflow Marketplace**
- Community-contributed workflow templates
- Machine-specific setup procedures
- Technique-specific learning progressions
- Integration with online learning platforms

#### **Telemetry and Improvement**
- Anonymized usage analytics (opt-in)
- Performance metrics and optimization opportunities
- Error tracking and pattern analysis
- Community learning progression insights

## Implementation Timeline

### **Phase 1: Foundation** (Current - 6 months)
- ✅ High-performance 3D visualization (Complete)
- ✅ Ultra-responsive grblHAL communication (Complete)
- 🚧 Domain-driven architecture refactoring (In Progress)
- 📋 Basic safety validation layer
- 📋 Hardware compatibility validation

### **Phase 2: CNC Controller** (6-12 months)
- 📋 Work envelope protection and collision detection
- 📋 Manual operation workflows (tool changes, touchoff)
- 📋 Real-time machine control interface
- 📋 Program execution with safety validation
- 📋 Emergency systems integration

### **Phase 3: Advanced Features** (12-18 months)
- 📋 Adaptive learning system implementation
- 📋 Touch-optimized tablet interface
- 📋 Plugin architecture and marketplace
- 📋 Advanced safety features with ML
- 📋 Community integration platform

### **Phase 4: Ecosystem Maturity** (18+ months)
- 📋 Advanced workflow automation
- 📋 Enterprise features and management
- 📋 Comprehensive CAM integrations
- 📋 Advanced analytics and optimization
- 📋 Global community platform

## Success Metrics

### **Adoption Metrics**
- Weekly active users
- Hardware vendor partnerships
- Community plugin contributions
- Educational institution adoption

### **Safety Metrics**
- Job success rate (completion without errors)
- Manual operation safety rate (tool changes, touchoff)
- State transition error rate (program/manual mode)
- Accident reduction compared to existing senders

### **Learning Metrics**
- Learning progression rate (beginner to intermediate)
- Workflow efficiency improvement over time
- User satisfaction and confidence growth
- Expert user productivity gains

### **Technical Metrics**
- Application crash rate (<1 per 1000 sessions)
- Response time maintenance (<50ms for critical operations)
- Cross-platform consistency scores
- Performance benchmark leadership

## Competitive Differentiation

### **vs. Traditional G-code Senders**
- **Manual Operations**: First-class workflows vs. afterthoughts
- **Safety Integration**: Proactive prevention vs. reactive error handling
- **Learning System**: Progressive skill development vs. static interfaces
- **Performance**: 125Hz updates vs. typical 10Hz polling

### **vs. Professional Controllers**
- **Cost**: Software solution vs. expensive hardware
- **Flexibility**: Customizable workflows vs. fixed procedures
- **Community**: Open ecosystem vs. proprietary systems
- **Accessibility**: Hobbyist-friendly vs. industrial complexity

### **Key Innovation: Operation-Specific Workflows**
No other G-code sender provides operation-specific coordinate system workflows. This eliminates user confusion about setup approaches and matches real-world CNC practices instead of forcing universal compromises.

## Risk Mitigation

### **Technical Risks**
- **Performance Degradation**: Continuous benchmarking and optimization
- **Platform Fragmentation**: Single Flutter codebase strategy
- **Hardware Compatibility**: Extensive testing program
- **Safety System Complexity**: Incremental implementation with validation

### **Market Risks**
- **User Adoption**: Focus on exceptional user experience
- **Community Building**: Open architecture and contribution recognition
- **Competition**: Maintain performance and feature leadership
- **Hardware Ecosystem**: Deep grblHAL integration partnerships

### **Development Risks**
- **Feature Creep**: Strict persona validation and success metric alignment
- **Architecture Debt**: Proactive refactoring and quality gates
- **Team Scaling**: Clear architecture and contribution guidelines
- **Timeline Pressure**: Incremental delivery with working software

## Validation Strategy

### **User Journey Testing**
- First-time tool change experiences
- Workflow pain point identification
- Safety feature effectiveness validation
- Learning progression measurement

### **Performance Validation**
- Continuous benchmarking against requirements
- Real-world usage pattern testing
- Stress testing with complex operations
- Cross-platform consistency verification

### **Community Feedback**
- Regular user surveys and interviews
- Support request pattern analysis
- Feature request prioritization
- Community contribution facilitation

---

*This document represents the long-term vision for ghSender. Implementation priorities are guided by user needs, safety requirements, and technical feasibility. Current implementation status is tracked in `CURRENT_STATUS.md`.*