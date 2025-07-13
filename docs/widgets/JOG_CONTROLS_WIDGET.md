# Jog Controls Widget Requirements

**Author**: Product Management & System Architecture Team  
**Date**: 2025-07-13  
**Purpose**: Define requirements for the Jog Controls widget - manual machine movement interface

## Executive Summary

The Jog Controls widget provides manual machine movement capabilities and is one of the highest-risk interfaces in CNC operation. It must balance ease of use for beginners with efficiency for experts while maintaining strict safety controls. The widget emphasizes progressive speeds, clear visual feedback, and adaptive behavior based on user competency.

## 1. Core Functionality Requirements

### 1.1 Movement Controls
**Primary Jog Interface:**
- **Directional Controls**: X+/X-, Y+/Y-, Z+/Z- movement buttons
- **Distance Selection**: Preset incremental distances (0.01, 0.1, 1.0, 10.0mm or equivalent imperial)
- **Custom Distance Entry**: User-definable jog distance with input validation
- **Continuous Jog**: Hold-to-jog functionality for fine positioning
- **Speed Control**: Variable jog speed selection (slow, medium, fast, custom)

**Advanced Movement:**
- **Multi-axis Jog**: Diagonal movement (X+Y+, X-Y-, etc.) for efficient positioning
- **Safe Z Movement**: Automatic Z-retract before XY movement option
- **Pre-defined Positions**: Quick movement to configured machine positions
- **Rapid Positioning**: Goto specific coordinates with confirmation and preview

**Feed Rate Control:**
- Visual feed rate slider with real-time adjustment
- Preset speed buttons (10%, 25%, 50%, 100%)
- Custom speed entry with validation against machine limits
- Emergency stop integration with immediate halt capability

### 1.2 Machine State Management
**Job Execution Protection:**
- **Complete UI Lockdown**: Jog controls completely disabled during G-Code execution
- **Clear Status Indication**: Prominent display showing "Job Running - Jog Disabled"
- **Emergency Stop Always Available**: Only emergency stop remains active during job execution
- **Immediate Re-enable**: Jog controls immediately available when job pauses/completes

**State-Based Interface:**
- **Idle State**: Full jog functionality available
- **Alarm State**: Limited jog (only for alarm recovery if safe)
- **Homing State**: Jog disabled until homing complete
- **Manual Mode**: Full jog functionality with enhanced safety

### 1.3 Safety Features
**Pre-movement Validation:**
- Check machine status (must be Idle or Jog mode)
- Validate movement doesn't exceed machine travel limits
- Confirm adequate clearance for Z-axis movements
- Tool collision detection with configured obstacles

**Movement Preview System:**
- **Touch Preview**: Long-press button shows movement path in visualizer
- **Position Preview**: Show ghost tool position at target location
- **Collision Visualization**: Highlight potential collision areas
- **Confirm-to-Execute**: Tap again to execute after preview confirmation

**Real-time Safety:**
- Immediate stop on limit switch activation
- Emergency stop button always accessible and prominent
- Movement visualization showing intended path
- Collision warnings before movement execution

**Progressive Safety (Adaptive Learning):**
- **Beginner Mode**: Confirmations for all movements, slower default speeds
- **Intermediate Mode**: Reduced confirmations, faster defaults
- **Expert Mode**: Minimal confirmations, maximum speed access

## 2. User Experience Requirements

### 2.1 Adaptive Interface Based on Competency

**Beginner Mode (Brenda):**
```
┌─────────────────────────────────────────────────────────┐
│                   JOG CONTROLS                          │
│              Safe Movement Mode Active                  │
├─────────────────────────────────────────────────────────┤
│  Move Distance: [0.1mm ▼] Speed: [Slow ▼]             │
│  ┌─────┐     ┌─────┐     ┌─────┐                       │
│  │ X-  │     │ Y+  │     │ X+  │                       │
│  └─────┘     └─────┘     └─────┘                       │
│              ┌─────┐              ┌─────┐               │
│              │ Y-  │              │ Z+  │               │
│              └─────┘              └─────┘               │
│                                  ┌─────┐               │
│                                  │ Z-  │               │
│                                  └─────┘               │
│  "Click button to move 0.1mm at slow speed"            │
│  [EMERGENCY STOP] - Always visible and large           │
└─────────────────────────────────────────────────────────┘
```

**Expert Mode (Mark):**
```
┌─────────────────────────────────────────────────────────┐
│  JOG: [0.1▼] [100%▼] │ GOTO: X[____] Y[____] Z[____]  │
│  ← ↑ → ↓ ↑ ↓ [STOP] │ [HOME] [TLS] [TC] [SAFE-Z]    │
└─────────────────────────────────────────────────────────┘
```

### 2.2 Pre-defined Position System

**Standard Machine Positions:**
- **Machine Home**: Return to machine home position (0,0,0 in machine coordinates)
- **Tool Length Sensor (TLS)**: Move to tool length sensor position for manual measurement
- **Tool Change Position**: Move to manual tool change position (safe, accessible location)
- **Parking Position**: Safe position for machine shutdown or maintenance
- **Work Zero**: Current work coordinate system origin ("Project Workpiece", "Secondary Setup", etc.)

**Accessory Positions:**
- **Dust Collection Mount**: Position for attaching/removing dust collection
- **Coolant Connection**: Position for coolant system setup/maintenance
- **Probe Storage**: Location where touch probe is stored when not in use
- **Camera Position**: Optimal position for workpiece inspection camera
- **Custom Positions**: User-defined positions for specific workflows

**Position Management:**
```typescript
interface PredefinedPosition {
  id: string;
  name: string;
  description: string;
  coordinates: Position3D;
  coordinateFrame: 'machine' | 'work';
  safeApproach: boolean; // Move to safe Z first
  speedOverride?: number; // Custom speed for this position
  requiredTools?: number[]; // Which tools can safely use this position
  accessoryRequired?: string; // e.g., "dust_collection_disconnected"
}

const standardPositions: PredefinedPosition[] = [
  {
    id: 'machine_home',
    name: 'Machine Home',
    description: 'Return to machine home position',
    coordinates: { x: 0, y: 0, z: 0 },
    coordinateFrame: 'machine',
    safeApproach: true,
    speedOverride: 80, // Slightly slower for safety
  },
  {
    id: 'tool_length_sensor',
    name: 'Tool Length Sensor',
    description: 'Position for manual tool length measurement',
    coordinates: { x: 150, y: 150, z: -10 }, // Example coordinates
    coordinateFrame: 'machine',
    safeApproach: true,
    speedOverride: 50, // Slower approach for precision
  },
  {
    id: 'tool_change_position',
    name: 'Tool Change',
    description: 'Safe position for manual tool changes',
    coordinates: { x: 50, y: 350, z: 0 },
    coordinateFrame: 'machine',
    safeApproach: true,
    speedOverride: 60,
  }
];
```

**Touch Interface for Positions:**
```
┌─────────────────────────────────────────────────────────┐
│                PREDEFINED POSITIONS                     │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   MACHINE    │  │     TOOL     │  │     TOOL     │   │
│  │     HOME     │  │    LENGTH    │  │    CHANGE    │   │
│  │              │  │   SENSOR     │  │   POSITION   │   │
│  │ Long-press   │  │              │  │              │   │
│  │ to preview   │  │ Long-press   │  │ Long-press   │   │
│  └──────────────┘  │ to preview   │  │ to preview   │   │
│                    └──────────────┘  └──────────────┘   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │    DUST      │  │   COOLANT    │  │    PROBE     │   │
│  │ COLLECTION   │  │ CONNECTION   │  │   STORAGE    │   │
│  │   MOUNT      │  │   POSITION   │  │   POSITION   │   │
│  │              │  │              │  │              │   │
│  │ Long-press   │  │ Long-press   │  │ Long-press   │   │
│  │ to preview   │  │ to preview   │  │ to preview   │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
```

### 2.3 Touch-Optimized Movement Preview System

**Long-Press Preview Pattern:**
1. **Long-press** button → Show movement path in visualizer + haptic feedback
2. **Continue holding** → Path remains highlighted, collision areas shown in red
3. **Release to cancel** OR **Tap again to execute** movement
4. **Quick single tap** → Execute immediately (for expert users with confirmations disabled)

**Preview Visualization:**
- **Ghost Tool Position**: Semi-transparent tool at target location
- **Movement Path**: Dotted line showing travel path with intermediate points
- **Collision Zones**: Red highlighting of potential collision areas
- **Safe Zones**: Green highlighting of validated safe travel
- **Speed Indicator**: Visual indication of movement speed (fast/medium/slow)

**Touch Interface (Primary - Tablet Focus):**
- Large, touch-friendly buttons (minimum 44px target size)
- **Long-press for preview**: 500ms hold shows movement preview
- **Double-tap for execution**: Alternative to long-press → tap pattern
- Gesture support for directional movement (swipe-to-jog)
- Multi-touch for diagonal movement (two-finger gestures)
- Haptic feedback for movement start/stop (where available)

**Accessibility Alternatives:**
- **Toggle Preview Mode**: Switch to show all previews on single tap
- **Audio Feedback**: Voice description of intended movement
- **Confirmation Dialog**: Traditional dialog for users who prefer explicit confirmation

**Keyboard Interface (Desktop Support):**
- Arrow keys for XY movement
- Page Up/Down for Z movement
- Number keys for distance selection (1=0.01, 2=0.1, 3=1.0, 4=10.0)
- Shift modifier for continuous movement
- Space bar as emergency stop

**Gamepad/Pendant Support (Future):**
- Analog stick for variable speed directional movement
- Trigger buttons for Z-axis control
- D-pad for incremental movement
- Dedicated emergency stop button

### 2.3 Visual Feedback Systems

**Movement Visualization:**
- Real-time position cursor in integrated visualizer
- Ghost/preview position showing intended movement
- Path preview for multi-step movements
- Collision detection visualization

**Status Indicators:**
- Current jog distance and speed prominently displayed
- Machine status indicator (ready/busy/error)
- Movement progress during long moves
- Limit switch proximity warnings

**Progressive Disclosure:**
- **Beginner**: Detailed explanations, safety warnings, movement confirmations
- **Intermediate**: Essential information, reduced confirmations
- **Expert**: Minimal interface, maximum information density

## 3. Technical Requirements

### 3.1 Performance Specifications
- **Movement Response Time**: <50ms from button press to command transmission
- **UI Responsiveness**: 60fps during all interactions
- **Real-time Updates**: Position updates at machine controller refresh rate
- **Safety Response**: <10ms emergency stop command transmission

### 3.2 Machine State Integration
**State-Dependent UI Behavior:**
```typescript
interface JogControlState {
  machineStatus: 'idle' | 'run' | 'hold' | 'alarm' | 'home' | 'sleep';
  canJog: boolean;
  enabledControls: JogControlType[];
  disabledReason?: string;
}

class JogControlManager {
  updateControlState(machineStatus: MachineStatus): JogControlState {
    switch (machineStatus.state) {
      case 'idle':
        return {
          machineStatus: 'idle',
          canJog: true,
          enabledControls: ['incremental', 'continuous', 'predefined', 'goto'],
        };
      
      case 'run':
        return {
          machineStatus: 'run',
          canJog: false,
          enabledControls: ['emergency_stop'],
          disabledReason: 'Job executing - jog controls disabled for safety',
        };
      
      case 'alarm':
        return {
          machineStatus: 'alarm',
          canJog: false,
          enabledControls: ['emergency_stop'],
          disabledReason: 'Machine in alarm state - resolve alarm to enable jogging',
        };
        
      case 'hold':
        return {
          machineStatus: 'hold',
          canJog: true,
          enabledControls: ['incremental', 'emergency_stop'],
          disabledReason: 'Limited jog mode - job paused',
        };
    }
  }
}
```

**Visual State Indication:**
```typescript
interface UIStateVisual {
  overlayOpacity: number; // 0 = fully enabled, 0.7 = disabled overlay
  statusText: string;
  statusColor: 'normal' | 'warning' | 'error';
  allowedActions: string[];
}

// Example: During job execution
const runningState: UIStateVisual = {
  overlayOpacity: 0.7,
  statusText: "JOB RUNNING - JOG DISABLED",
  statusColor: 'warning',
  allowedActions: ['emergency_stop'],
};
```

### 3.3 Command Generation
**G-Code Generation:**
```typescript
interface JogCommand {
  type: 'incremental' | 'absolute' | 'predefined';
  axis: 'X' | 'Y' | 'Z' | 'XY' | 'XZ' | 'YZ' | 'XYZ';
  distance?: number;
  direction?: number; // +1 or -1
  targetPosition?: Position3D;
  feedRate: number;
  safeApproach?: boolean;
}

interface PredefinedPositionCommand extends JogCommand {
  type: 'predefined';
  positionId: string;
  safeApproach: boolean;
  approachHeight?: number;
}

class JogCommandGenerator {
  generateJogCommand(params: JogCommand): string[] {
    if (params.type === 'predefined') {
      return this.generatePredefinedPositionCommands(params as PredefinedPositionCommand);
    }
    // Generate appropriate grblHAL jog commands
    // Example: $J=G91 X10 F1000
  }
  
  generatePredefinedPositionCommands(params: PredefinedPositionCommand): string[] {
    const commands: string[] = [];
    const position = this.getPredefinedPosition(params.positionId);
    
    if (params.safeApproach) {
      // First move to safe Z height
      commands.push(`G0 Z${params.approachHeight || 10}`);
      // Then move XY to position
      commands.push(`G0 X${position.x} Y${position.y}`);
      // Finally move to target Z
      commands.push(`G0 Z${position.z}`);
    } else {
      // Direct movement
      commands.push(`G0 X${position.x} Y${position.y} Z${position.z}`);
    }
    
    return commands;
  }
  
  validateCommand(command: JogCommand, machineState: MachineState): ValidationResult {
    // Ensure movement stays within machine limits
    // Check for collisions with configured obstacles
    // Validate feed rate against machine capabilities
    // Verify machine state allows jogging
  }
}
```

### 3.3 Safety Integration
**Limit Checking:**
```typescript
interface MovementValidator {
  validateMovement(
    currentPosition: Position3D,
    movement: Movement,
    machineLimits: MachineLimits
  ): ValidationResult;
  
  checkCollisions(
    currentPosition: Position3D,
    targetPosition: Position3D,
    toolGeometry: ToolGeometry,
    obstacles: Obstacle[]
  ): CollisionResult;
}
```

## 4. Workflow Integration Requirements

### 4.1 Tool Change Integration
**During Tool Changes:**
- Automatic safe height positioning
- Tool change position shortcuts
- Restricted movement zones (prevent collision with tool changer)
- Tool length offset awareness in movement calculations

### 4.2 Workpiece Touchoff Integration
**Touchoff Support:**
- Progressive approach speeds (rapid → medium → fine)
- Contact detection integration
- Automatic coordinate system setting
- Undo/retry capabilities for touchoff operations

### 4.3 Probing Integration
**Probe Operations:**
- Slow, controlled movement speeds during probing
- Probe contact detection and automatic stop
- Multiple axis probing with guided workflows
- Measurement result integration with coordinate systems

## 5. Learning System Integration

### 5.1 Competency Tracking
**Skill Assessment Metrics:**
- Successful movement completions without errors
- Appropriate speed selection for different operations
- Emergency stop usage (unnecessary activation indicates over-caution)
- Collision avoidance during complex movements

**Progression Indicators:**
```typescript
interface JogCompetencyMetrics {
  successfulMovements: number;
  averageSpeedSelection: number;
  collisionAvoidanceRate: number;
  emergencyStopRate: number;
  precisionAccuracy: number; // How close to intended position
}
```

### 5.2 Adaptive Behavior
**Beginner → Intermediate Progression:**
- Reduce confirmation dialogs for safe movements
- Increase default jog speeds
- Enable multi-axis movement options
- Introduce advanced positioning features

**Intermediate → Expert Progression:**
- Provide compact interface options
- Enable keyboard shortcuts
- Allow custom movement macros
- Reduce safety warnings for routine operations

### 5.3 Learning Feedback
**Positive Reinforcement:**
- Celebrate successful precision movements
- Acknowledge speed/efficiency improvements
- Provide progress indicators for skill development
- Milestone achievements for movement accuracy

**Guidance System:**
- Suggest optimal speeds for different operations
- Recommend movement sequences for efficiency
- Provide tips for avoiding common mistakes
- Contextual help for complex positioning tasks

## 6. Safety Design Principles

### 6.1 Emergency Stop Integration
**Always Accessible:**
- Large, prominent emergency stop button in all interface modes
- Multiple activation methods (touch, keyboard, external)
- Visual confirmation of emergency stop activation
- Clear instructions for emergency stop recovery

**Predictable Behavior:**
- Consistent stop behavior across all movement types
- Immediate cessation of all movement commands
- Clear status indication during stopped state
- Simple recovery procedure with safety checks

### 6.2 Movement Validation
**Pre-movement Checks:**
```typescript
interface MovementSafetyCheck {
  checkMachineLimits(movement: Movement): boolean;
  checkToolCollisions(movement: Movement): boolean;
  checkFixtureCollisions(movement: Movement): boolean;
  checkSafeZClearance(movement: Movement): boolean;
  validateFeedRate(feedRate: number): boolean;
}
```

**Real-time Monitoring:**
- Continuous position validation during movement
- Limit switch monitoring with predictive warnings
- Feed rate monitoring for overload conditions
- Emergency stop readiness during all operations

### 6.3 Error Recovery
**Common Error Scenarios:**
- Limit switch activation during movement
- Communication loss during jog operation
- Tool collision detection activation
- Emergency stop activation

**Recovery Procedures:**
- Clear error status indication
- Step-by-step recovery instructions
- Automatic safe positioning when possible
- Guided troubleshooting for persistent issues

## 7. UI/UX Design Requirements

### 7.1 Layout Principles
**Visual Hierarchy:**
- Emergency stop most prominent
- Current movement controls primary focus
- Status information clearly visible
- Advanced features accessible but not dominant

**Touch Optimization:**
- Minimum 44px touch targets
- Adequate spacing between controls
- Visual feedback for touch interactions
- Gesture recognition for advanced users

### 7.2 Responsive Design
**Tablet Layout (Primary - Idle State):**
```
┌─────────────────────────────────────────────────────────┐
│  EMERGENCY STOP                    Speed: [50%    ▼]    │
├─────────────────────────────────────────────────────────┤
│  Distance: [0.1mm ▼]              │  Position Display   │
│                                   │  X: 100.000         │
│  ┌─────┐  ┌─────┐  ┌─────┐       │  Y:  50.000         │
│  │ X-  │  │ Y+  │  │ X+  │       │  Z:  -2.500         │
│  └─────┘  └─────┘  └─────┘       │                     │
│           ┌─────┐                 │  ┌─────────────────┐ │
│           │ Y-  │                 │  │      HOME       │ │
│           └─────┘                 │  │  Long-press to  │ │
│  ┌─────┐           ┌─────┐       │  │    preview      │ │
│  │ Z+  │           │ Z-  │       │  └─────────────────┘ │
│  └─────┘           └─────┘       │  ┌─────────────────┐ │
│                                   │  │  MORE POSITIONS │ │
│                                   │  └─────────────────┘ │
└─────────────────────────────────────────────────────────┘
```

**Tablet Layout (Job Running State):**
```
┌─────────────────────────────────────────────────────────┐
│           🔴 EMERGENCY STOP ONLY 🔴                     │
├─────────────────────────────────────────────────────────┤
│                                   │  Position Display   │
│        JOB RUNNING                │  X: 150.250         │
│      JOG DISABLED                 │  Y:  75.500         │
│                                   │  Z:  -5.000         │
│   [Grayed out jog controls]       │                     │
│   [All buttons disabled]          │  Current Operation: │
│                                   │  Linear Move        │
│                                   │  Feed: 1000 mm/min  │
│                                   │                     │
│   Controls will re-enable         │  Progress: 45%      │
│   when job completes or pauses    │  Est. Time: 12 min  │
└─────────────────────────────────────────────────────────┘
```

**Pre-defined Positions Expanded View:**
```
┌─────────────────────────────────────────────────────────┐
│                MACHINE POSITIONS                        │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │   MACHINE    │  │     TOOL     │  │     TOOL     │   │
│  │     HOME     │  │    LENGTH    │  │    CHANGE    │   │
│  │   X: 0.000   │  │   SENSOR     │  │   POSITION   │   │
│  │   Y: 0.000   │  │  X: 150.000  │  │   X: 50.000  │   │
│  │   Z: 0.000   │  │  Y: 150.000  │  │  Y: 350.000  │   │
│  │              │  │   Z: -10.000 │  │   Z: 0.000   │   │
│  │ [Long-press  │  │              │  │              │   │
│  │  to preview] │  │ [Long-press  │  │ [Long-press  │   │
│  └──────────────┘  │  to preview] │  │  to preview] │   │
│                    └──────────────┘  └──────────────┘   │
├─────────────────────────────────────────────────────────┤
│                ACCESSORY POSITIONS                      │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │    DUST      │  │   COOLANT    │  │    PROBE     │   │
│  │ COLLECTION   │  │ CONNECTION   │  │   STORAGE    │   │
│  │  X: 400.000  │  │  X: 100.000  │  │  X: 200.000  │   │
│  │  Y: 100.000  │  │  Y: 400.000  │  │  Y: 200.000  │   │
│  │   Z: 50.000  │  │   Z: 20.000  │  │   Z: 10.000  │   │
│  │              │  │              │  │              │   │
│  │ [Long-press  │  │ [Long-press  │  │ [Long-press  │   │
│  │  to preview] │  │  to preview] │  │  to preview] │   │
│  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Desktop Compact Layout:**
```
┌─────────────────────────────────────────────────────────┐
│ [STOP] Jog: [0.1▼] [50%▼] │ ←↑→↓ Z±│ [HOME][GOTO]    │
└─────────────────────────────────────────────────────────┘
```

### 7.3 Accessibility Features
**Visual Accessibility:**
- High contrast button designs
- Clear labeling with icons and text
- Scalable interface elements
- Motion reduction options

**Motor Accessibility:**
- Large touch targets for limited dexterity
- Alternative input methods (voice, switch access)
- Customizable button layouts
- Reduced interaction complexity options

## 8. Integration Points

### 8.1 Machine Communication
**Command Transmission:**
- Direct integration with CncService for command sending
- Real-time position feedback integration
- Machine status monitoring for jog capability
- Emergency stop signal routing

**Error Handling:**
- Communication timeout detection
- Command acknowledgment verification
- Machine alarm condition handling
- Graceful degradation during communication issues

### 8.2 Visualizer Integration
**Position Visualization:**
- Real-time cursor updates during movement
- Movement preview before execution
- Collision visualization
- Path history display

**Movement Preview Integration:**
```typescript
interface MovementPreview {
  startPosition: Position3D;
  targetPosition: Position3D;
  movementPath: Position3D[];
  collisionZones: CollisionZone[];
  safeZones: SafeZone[];
  estimatedTime: number;
  feedRate: number;
}

class JogVisualizerBridge {
  showMovementPreview(command: JogCommand): MovementPreview {
    const preview = this.calculateMovementPreview(command);
    
    // Send preview to visualizer
    this.visualizer.displayMovementPreview({
      path: preview.movementPath,
      collisions: preview.collisionZones,
      safeZones: preview.safeZones,
      ghostToolPosition: preview.targetPosition,
      pathStyle: 'dashed_blue',
      duration: 'until_cancelled',
    });
    
    return preview;
  }
  
  clearMovementPreview(): void {
    this.visualizer.clearMovementPreview();
  }
  
  executeMovement(command: JogCommand): void {
    this.clearMovementPreview();
    this.cncService.sendCommand(command);
  }
}
```

**Visual Preview Elements:**
- **Ghost Tool**: Semi-transparent tool representation at target position
- **Movement Path**: Dotted line showing travel path with direction arrows
- **Collision Warnings**: Red highlight areas where collision might occur
- **Safe Path Confirmation**: Green highlight for validated safe movement
- **Speed Visualization**: Line thickness or color intensity indicating movement speed
- **Multi-Step Movements**: Numbered waypoints for complex movements (e.g., safe approach)

**Interactive Features:**
- Click-to-jog in visualizer (with same preview system)
- Visual distance measurement between current and target positions
- Coordinate system visualization during position selection
- Work envelope boundary display with clearance indicators
- Real-time collision detection updates as machine configuration changes

### 8.3 Settings and Preferences
**User Customization:**
- Default jog distances and speeds
- Interface layout preferences
- Safety confirmation levels
- Keyboard shortcut customization

**Machine Configuration:**
- Machine-specific travel limits
- Feed rate limits and defaults
- Tool-specific collision geometry
- Custom position shortcuts

## 9. Testing Requirements

### 9.1 Safety Testing
**Emergency Stop Testing:**
- Response time verification (<10ms)
- Reliability testing under various conditions
- Recovery procedure validation
- Cross-platform consistency verification

**Limit Checking:**
- Movement validation accuracy
- Collision detection effectiveness
- False positive/negative rates
- Edge case handling (near limits, etc.)

### 9.2 Usability Testing
**Beginner User Testing:**
- First-time jog operation success rate
- Safety feature comprehension
- Error recovery capability
- Learning progression effectiveness

**Expert User Testing:**
- Interface efficiency metrics
- Advanced feature utilization
- Workflow integration effectiveness
- Customization option usage

### 9.3 Performance Testing
**Response Time Testing:**
- Button press to command transmission latency
- UI responsiveness during intensive operations
- Real-time update performance
- Memory usage during extended operation

## 10. Future Enhancement Considerations

### 10.1 Advanced Features (Post-MVP)
- **Macro Recording**: Record and replay movement sequences
- **Path Planning**: Optimized multi-point movement paths
- **Voice Control**: Voice commands for hands-free operation
- **Gesture Control**: Advanced gesture recognition for movement

### 10.2 Hardware Integration
- **External Pendants**: USB/wireless jog pendant support
- **Gamepad Controllers**: Standard gaming controller integration
- **Touchscreen Optimization**: Multi-touch gesture support
- **Haptic Feedback**: Tactile feedback for movement operations

### 10.3 Workflow Automation
- **Smart Positioning**: AI-assisted optimal positioning
- **Collision Avoidance**: Automatic safe path planning
- **Speed Optimization**: Automatic speed selection based on operation
- **Pattern Recognition**: Learn user movement patterns for prediction

## 11. Success Metrics

### 11.1 Safety Metrics
- Zero collision incidents due to jog control failures
- <1% false emergency stop activations
- 100% limit switch respect (no overtravel incidents)
- User-reported confidence increase in manual operations

### 11.2 Efficiency Metrics
- 50% reduction in positioning time vs existing senders
- 90% first-attempt success rate for precision positioning
- User preference ratings vs traditional jog interfaces
- Workflow completion time improvements

### 11.3 Learning Progression Metrics
- 80% of users advance from beginner to intermediate within 10 operations
- 60% of users adopt advanced features within first month
- Reduction in support requests for jog-related issues
- User satisfaction scores for learning progression system

The Jog Controls widget represents one of the most critical safety interfaces in the application, requiring careful balance between accessibility for beginners and efficiency for experts while maintaining uncompromising safety standards.