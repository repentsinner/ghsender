# DRO (Digital Readout) Widget Requirements

**Author**: Product Management & System Architecture Team  
**Date**: 2025-07-13  
**Purpose**: Define requirements for the Digital Readout widget - the primary machine position display component

## Executive Summary

The DRO (Digital Readout) widget is the central information display for machine position and status. It must provide clear, real-time feedback on machine state while adapting to different user competency levels and operational contexts. Unlike traditional static DROs, this widget emphasizes contextual information and progressive disclosure.

## 1. Core Functionality Requirements

### 1.1 Position Display
**Primary Position Information:**
- **Work Coordinates (WPos)**: Current position in active work coordinate system ("Project Workpiece", "Secondary Setup", etc.)
- **Machine Coordinates (MPos)**: Absolute position relative to machine home
- **Distance to Go (DTG)**: Remaining distance in current move (during job execution)
- **Coordinate System Indicator**: Clear display of active coordinate system ("Project Workpiece (G54)", "Secondary Setup (G55)", etc.)

**Display Precision:**
- Configurable decimal places (0.001mm default, 0.0001" for imperial)
- Units switching (metric/imperial) with clear indication
- Large, easily readable fonts optimized for tablet viewing
- High contrast for workshop lighting conditions

**Real-time Updates:**
- Position updates at controller refresh rate (typically 10-50Hz)
- Smooth interpolation to avoid flickering or jumping numbers
- <16ms latency from controller update to display change
- Maintain 60fps refresh rate during updates

### 1.2 Machine Status Display
**Operational State:**
- Machine status (Idle, Run, Hold, Alarm, Sleep, etc.)
- Feed rate percentage and actual feed rate
- Spindle speed (commanded vs actual if available)
- Coolant status (flood, mist, off)

**Safety Indicators:**
- Emergency stop status
- Limit switch status
- Probe status
- Tool length offset active/inactive
- Work coordinate system offsets active

**Visual Hierarchy:**
- Critical information (position, status) prominently displayed
- Secondary information (feed rate, spindle) clearly visible but not dominant
- Alarm conditions immediately visible with appropriate color coding
- Progressive disclosure based on user competency level

## 2. User Experience Requirements

### 2.1 Adaptive Display Based on User Competency

**Beginner Mode (Brenda):**
- Large, clear position numbers with units explicitly shown
- Verbose status descriptions ("Machine is ready to run job")
- Coordinate system explanation ("Currently using Project Workpiece coordinate system")
- Safety status prominently displayed with explanations
- Tool information clearly labeled ("Tool #1: 1/4" End Mill")

**Intermediate Mode:**
- Compact layout with essential information prioritized
- Abbreviated status indicators that are still clear
- Quick reference for coordinate systems
- Reduced explanatory text

**Expert Mode (Mark):**
- Dense information display with maximum information density
- Minimal explanatory text
- Advanced information like acceleration, jerk settings
- Customizable information priority

### 2.2 Contextual Information Display

**During Different Operations:**
- **Manual Jogging**: Emphasize position changes, show jog increments
- **Tool Changes**: Display tool change position, current tool info
- **Workpiece Touchoff**: Show coordinate system being set ("Setting Project Workpiece Origin"), offset values
- **Job Execution**: Emphasize progress, time remaining, current operation
- **Probing**: Show probe status, contact detection, measurement results

**Workflow Integration:**
- Highlight relevant information during guided workflows
- Dim irrelevant information to reduce cognitive load
- Provide visual cues for next expected actions
- Show workflow progress context

## 3. Technical Requirements

### 3.1 Performance Specifications
- **Update Latency**: <16ms from data receipt to display update
- **Refresh Rate**: 60fps display refresh capability
- **Memory Usage**: <10MB for DRO widget including position history
- **CPU Usage**: <5% CPU utilization during normal operation

### 3.2 Data Sources Integration
**Machine State Integration:**
```typescript
interface DRODataSource {
  machinePosition: Position3D;
  workPosition: Position3D;
  machineStatus: MachineStatus;
  activeCoordinateSystem: CoordinateSystem;
  feedRate: { commanded: number; actual: number };
  spindleSpeed: { commanded: number; actual: number };
  toolInfo: ToolInfo | null;
  workOffsets: Map<CoordinateSystem, Position3D>;
}
```

**Real-time Subscriptions:**
- Subscribe to machine position stream from CncService
- Listen for status changes from machine controller
- React to coordinate system changes
- Update display for tool changes and offset modifications

### 3.3 State Management
**Local State:**
- Display units (metric/imperial)
- Precision settings (decimal places)
- Information density level (beginner/intermediate/expert)
- Position history for trend analysis

**Synchronized State:**
- Current machine and work positions
- Active coordinate system and offsets
- Machine status and operational mode
- Tool information and offsets

## 4. UI/UX Design Requirements

### 4.1 Layout Structure
```
┌─────────────────────────────────────────────────────────┐
│                    Machine Status                       │
│          IDLE • Project Workpiece • METRIC             │
├─────────────────────────────────────────────────────────┤
│  WORK POSITION          │  MACHINE POSITION            │
│  X:  100.000 mm         │  X:  150.000 mm              │
│  Y:   50.000 mm         │  Y:  125.000 mm              │
│  Z:   -2.500 mm         │  Z:   47.500 mm              │
├─────────────────────────────────────────────────────────┤
│  Feed: 1000 mm/min      │  Spindle: 18000 RPM          │
│  Tool: #1 (6mm End)     │  Coolant: OFF                │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Visual Design Principles
**Typography:**
- Monospace font for position numbers to prevent jumping
- Clear hierarchy with position numbers as primary focus
- Sufficient contrast for workshop lighting conditions
- Scalable font sizes for different screen sizes and user preferences

**Color Coding:**
- **Green**: Normal operation, successful operations
- **Red**: Alarms, errors, emergency conditions
- **Yellow/Orange**: Warnings, attention needed
- **Blue**: Information, coordinate system indicators
- **Gray**: Inactive or secondary information

**Interactive Elements:**
- Clickable coordinate system display to switch between work coordinate systems ("Project Workpiece", "Secondary Setup", etc. with G54-G59 codes as reference)
- Touch/click on position values for zeroing operations with clear confirmation dialogs
- Units toggle for quick metric/imperial switching with clear current unit display
- Context menu for advanced settings with human-readable descriptions

### 4.3 Responsive Design
**Tablet Optimization:**
- Touch-friendly target sizes (minimum 44px)
- Appropriate spacing for finger interaction
- Landscape and portrait layout adaptations
- Zoom capability for vision accessibility

**Desktop Compatibility:**
- Keyboard shortcuts for common operations
- Mouse hover states for interactive elements
- Resizable widget for different screen configurations
- Integration with application window management

## 5. Accessibility Requirements

### 5.1 Visual Accessibility
- High contrast mode support
- Scalable text for vision impairments
- Clear visual hierarchy and spacing
- Support for system accessibility settings

### 5.2 Motor Accessibility
- Large touch targets for users with motor impairments
- Voice control integration potential
- Gesture alternatives for complex interactions
- Reduced motion options for vestibular disorders

### 5.3 Cognitive Accessibility
- Clear, simple language in status descriptions
- Consistent layout and interaction patterns
- Progress indicators for long operations
- Error messages with clear remediation steps

## 6. Integration Requirements

### 6.1 Workflow System Integration
- **Tool Change Workflow**: Display tool change position, highlight relevant coordinates
- **Touchoff Workflow**: Show coordinate system being modified, offset calculations
- **Probing Workflow**: Display probe results, measurement accuracy
- **Job Execution**: Show progress, estimated time remaining, current operation

### 6.2 Learning System Integration
- **Competency Tracking**: Record successful coordinate system operations
- **Progressive Disclosure**: Adapt information density based on user skill level
- **Help Integration**: Contextual help for coordinate system concepts
- **Milestone Celebration**: Acknowledge successful precision operations

### 6.3 Settings Integration
- **Machine Configuration**: Display machine-specific information (travel limits, etc.)
- **User Preferences**: Respect display units, precision, and layout preferences
- **Workspace Settings**: Integrate with project-specific coordinate systems
- **Theme Integration**: Respect application theme and color preferences

## 7. Error Handling and Safety

### 7.1 Data Validation
- Validate position data ranges against machine configuration
- Detect and handle communication timeouts gracefully
- Show clear indicators when data is stale or unavailable
- Graceful degradation when partial data is available

### 7.2 Safety Features
- Prominent display of alarm conditions
- Clear indication when machine is not homed
- Warning indicators for unusual positions (near limits, etc.)
- Emergency stop status always visible

### 7.3 Recovery Procedures
- Clear indication of how to resolve alarm conditions
- Guidance for re-establishing communication
- Recovery suggestions for position tracking errors
- Integration with help system for troubleshooting

## 8. Testing Requirements

### 8.1 Performance Testing
- Position update latency under various load conditions
- Display refresh rate during intensive operations
- Memory usage over extended operation periods
- CPU utilization during real-time updates

### 8.2 Usability Testing
**Brenda (Beginner) Testing:**
- Understanding of coordinate system concepts
- Ability to interpret machine status
- Success rate for basic position monitoring tasks
- Comprehension of safety indicators

**Mark (Expert) Testing:**
- Information density preferences
- Workflow efficiency with compact display
- Advanced feature discoverability
- Integration with expert workflows

### 8.3 Accuracy Testing
- Position display accuracy vs actual machine position
- Coordinate system transformation accuracy
- Real-time update accuracy under various conditions
- Data consistency across different operational modes

## 9. Future Enhancement Considerations

### 9.1 Advanced Features (Post-MVP)
- Position history graphing for trend analysis
- Predictive display showing upcoming positions
- Integration with CAM software for toolpath preview
- Advanced coordinate system management (fixture offsets, etc.)

### 9.2 Customization Capabilities
- User-configurable information layouts
- Custom field additions for specific machine types
- Plugin integration for specialized display needs
- Export/import of display configurations

### 9.3 Analytics Integration
- Track user interaction patterns for UX optimization
- Monitor information comprehension rates
- Identify common confusion points for improvement
- Performance metrics for continuous optimization

## 10. Success Metrics

### 10.1 Quantitative Metrics
- Position update latency <16ms
- 60fps refresh rate maintenance
- User task completion time reduction vs existing senders
- Error rate reduction in coordinate system operations

### 10.2 Qualitative Metrics
- User confidence in machine status understanding
- Reduced support requests for position-related questions
- Positive feedback on information clarity and usefulness
- Successful workflow completion rates

This DRO widget serves as the primary information hub for machine operation, providing the real-time feedback essential for safe and efficient CNC operation while adapting to user skill levels and operational contexts.