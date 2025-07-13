# Machine Parking Workflow

**Author**: Product Management & System Architecture Team  
**Date**: 2025-07-13  
**Purpose**: Define the workflow for safely positioning the machine to allow workpiece loading/unloading and maintenance access

## Executive Summary

Machine parking is a critical safety workflow that moves the machine to a predetermined safe position, providing clear access to the work area for workpiece changes, setup operations, and maintenance tasks. The workflow emphasizes safety through collision avoidance and provides different parking strategies based on the current operation context.

## 1. Workflow Overview

### 1.1 Parking Scenarios
```
Parking Contexts
├── Workpiece Loading/Unloading
│   ├── New Job Setup (fresh workpiece)
│   ├── Multi-part Production (workpiece swap)
│   └── Job Completion (remove finished part)
├── Maintenance Access
│   ├── Tool Change Preparation
│   ├── Dust Collection Setup
│   ├── Coolant System Service
│   └── Machine Cleaning
├── Safety Positioning
│   ├── Emergency Shutdown
│   ├── Power Loss Recovery
│   └── Long-term Storage
└── Inspection Operations
    ├── Workpiece Measurement
    ├── Quality Control
    └── Setup Verification
```

### 1.2 Pre-defined Parking Positions
- **Standard Park**: General-purpose position for workpiece access
- **Front Access**: Optimized for front-loading workpieces
- **Tool Change Park**: Position for manual tool changes
- **Maintenance Park**: Maximum clearance for cleaning and service
- **Storage Park**: Long-term storage position (optional safe height)

## 2. Standard Parking Workflow

### 2.1 Entry Points
**Widget Integration:**
- Jog Controls Widget: "PARK" button in pre-defined positions
- Main toolbar: "Park Machine" command
- Command palette: "Machine: Park for Workpiece Access"
- Workflow completion: Automatic parking after job completion
- Emergency procedures: Quick park during alarm recovery

### 2.2 Pre-Park Safety Assessment
**Purpose**: Ensure safe movement to parking position

**UI Elements Required:**
- DRO Widget: Current position display with parking target
- Visualizer: Movement preview with collision detection
- Status indicator: Machine state validation
- Confirmation dialog: Movement summary and safety check

**Assessment Steps:**
1. **Machine State Validation**
   - Verify machine is in Idle state (not running program)
   - Check for active alarms that prevent movement
   - Confirm spindle is stopped and coolant is off
   - Validate tool position is known (machine is homed)

2. **Current Position Analysis**
   - Check if already at or near parking position
   - Calculate required movement distance and time
   - Identify any obstacles in movement path
   - Assess tool clearance requirements

3. **Movement Path Planning**
   - Determine optimal movement sequence (Z-up first, then XY)
   - Calculate safe intermediate positions if needed
   - Verify no collisions with workpiece, fixtures, or accessories
   - Plan movement speeds (rapid vs controlled)

**Error Handling:**
- **Machine Not Homed**: Guide user through homing procedure first
- **Active Alarm**: Display alarm details and resolution steps
- **Spindle Running**: Automatic spindle stop with user confirmation
- **Unknown Tool Position**: Require homing or manual position verification

### 2.3 Movement Preview and Confirmation
**Purpose**: Show user exactly what will happen and get explicit confirmation

**UI Elements Required:**
- Visualizer integration for movement path display
- Movement summary with distances and estimated time
- Adaptive confirmation based on user competency level
- Cancel/modify options before execution

**Preview Display:**
```typescript
interface ParkingPreview {
  currentPosition: Position3D;
  targetPosition: Position3D;
  movementSequence: MovementStep[];
  estimatedTime: number;
  safetyChecks: SafetyCheck[];
  collisionWarnings: CollisionWarning[];
}

interface MovementStep {
  stepNumber: number;
  description: string;
  startPosition: Position3D;
  endPosition: Position3D;
  movementType: 'rapid' | 'controlled';
  feedRate: number;
  purpose: string; // "Safe Z retract", "Move to park XY", etc.
}
```

**Visualizer Integration:**
- **Ghost Tool Path**: Show complete movement sequence
- **Collision Zones**: Highlight any potential collision areas
- **Safe Zones**: Confirm clear path to parking position
- **Intermediate Positions**: Show multi-step movements with sequence numbers
- **Time Estimation**: Display estimated movement time

**Confirmation Levels by Competency:**
- **Beginner**: Detailed movement description with explicit confirmation required
- **Intermediate**: Summary view with quick confirmation
- **Expert**: Brief notification with auto-execute option

### 2.4 Movement Execution
**Purpose**: Execute parking movement safely with real-time monitoring

**UI Elements Required:**
- DRO Widget: Real-time position updates during movement
- Progress indicator: Movement completion status
- Emergency stop: Always accessible during movement
- Status display: Current movement step and remaining time

**Execution Steps:**
1. **Pre-Movement Final Check**
   - Verify machine still in safe state
   - Confirm no new obstacles detected
   - Check emergency stop functionality
   - Initialize movement monitoring

2. **Controlled Movement Sequence**
   - Execute Z-axis retract to safe height (if needed)
   - Move to parking XY position using rapid traverse
   - Final Z positioning if required
   - Verify arrival at target position

3. **Post-Movement Verification**
   - Confirm machine reached target position within tolerance
   - Verify machine state remains stable
   - Update machine status to "Parked"
   - Log parking completion for learning system

**Real-time Monitoring:**
- Position tracking with expected vs actual comparison
- Feed rate monitoring for consistent movement
- Limit switch monitoring for safety
- Communication integrity checking

**Error Handling During Movement:**
- **Limit Switch Activation**: Immediate stop with position analysis
- **Communication Loss**: Safe stop and recovery procedure
- **Position Deviation**: Stop and alert user to potential mechanical issues
- **Emergency Stop**: Immediate halt with current position recording

## 3. Context-Specific Parking Modes

### 3.1 Workpiece Loading Park
**Purpose**: Optimal positioning for workpiece installation and clamping

**Positioning Strategy:**
- Maximum Y-axis clearance for front access
- Safe Z height to prevent tool/workpiece collision
- Maintain X-axis accessibility for side clamping
- Consider dust collection hose routing

**Workflow Integration:**
- Pre-job setup: Automatic parking before workpiece installation
- Multi-part jobs: Quick park between workpiece swaps
- Setup verification: Park during workpiece measurement
- Fixture access: Position for clamp installation/removal

**UI Enhancements:**
- **Access Visualization**: Show optimal operator position
- **Clearance Indicators**: Display available workspace
- **Clamping Guides**: Highlight accessible clamping points
- **Tool Safety**: Show tool clearance margins

### 3.2 Tool Change Preparation Park
**Purpose**: Position machine for safe manual tool changes

**Positioning Strategy:**
- Move to designated tool change position
- Ensure spindle accessibility from optimal angle
- Provide clearance for tool length measurement
- Position for comfortable operator ergonomics

**Integration with Tool Change Workflow:**
- Automatic parking when M6 command encountered
- Pre-positioning before manual tool change initiation
- Return path planning after tool change completion
- Tool length sensor accessibility optimization

### 3.3 Maintenance Access Park
**Purpose**: Maximum clearance for machine maintenance and cleaning

**Positioning Strategy:**
- Maximum travel on all axes for complete access
- Position away from limit switches for safety
- Optimize for dust collection system disconnection
- Provide access to all machine maintenance points

**Maintenance Integration:**
- **Cleaning Mode**: Position for comprehensive machine cleaning
- **Service Access**: Optimize for mechanical maintenance
- **Lubrication**: Position for grease points and oil service
- **Inspection**: Facilitate visual inspection of all components

## 4. Adaptive Learning Integration

### 4.1 Competency-Based Behavior
**Beginner Users (Brenda):**
- Detailed explanation of parking purpose and safety
- Step-by-step movement description with confirmations
- Extended safety checks with educational information
- Celebration of successful parking completion

**Intermediate Users:**
- Streamlined confirmation with essential information
- Reduced safety explanations but maintained checks
- Quick movement preview with key details
- Progress tracking toward expert-level efficiency

**Expert Users (Mark):**
- Minimal confirmation for routine parking operations
- Advanced options for custom parking positions
- Batch operations (park + other setup tasks)
- Efficiency metrics and optimization suggestions

### 4.2 Learning Progression Tracking
**Competency Metrics:**
- Successful parking completions without errors
- Time from initiation to completion
- Appropriate parking mode selection for context
- Safety awareness during movement operations

**Progression Indicators:**
- Reduce confirmation requirements as competency increases
- Introduce advanced features (custom positions, batch operations)
- Provide efficiency coaching and optimization tips
- Enable expert-level shortcuts and automation

## 5. Safety Features and Error Recovery

### 5.1 Collision Prevention
**Pre-Movement Validation:**
- 3D path analysis using machine geometry model
- Obstacle detection based on configured fixtures
- Tool geometry considerations for clearance
- Workpiece boundary respect during movement

**Real-time Safety:**
- Continuous position monitoring during movement
- Predictive collision detection with immediate stop
- Limit switch integration with safe stop procedures
- Emergency stop with position preservation

### 5.2 Error Recovery Procedures
**Common Error Scenarios:**

**Parking Movement Interrupted:**
1. **Assessment**: Determine current position and safe state
2. **Analysis**: Identify cause of interruption (limits, communication, etc.)
3. **Recovery**: Provide options to complete, retry, or manual intervention
4. **Learning**: Update safety parameters based on incident

**Position Accuracy Issues:**
1. **Detection**: Compare expected vs actual final position
2. **Validation**: Check if position is acceptable for intended purpose
3. **Correction**: Offer fine adjustment or complete retry
4. **Prevention**: Update movement parameters for future operations

**Communication Loss During Parking:**
1. **Detection**: Monitor communication integrity continuously
2. **Safe State**: Ensure machine stops safely at last known position
3. **Recovery**: Re-establish communication and verify machine state
4. **Continuation**: Resume from safe intermediate position if possible

### 5.3 User Notification System
**Information Levels:**
- **Success**: Parking completed successfully with position confirmation
- **Warning**: Parking completed but with minor deviations or issues
- **Error**: Parking failed with specific reason and recovery options
- **Critical**: Safety system activation requiring immediate attention

**Notification Methods:**
- **Visual**: Color-coded status indicators in DRO and status widgets
- **Audio**: Completion tones and error alerts (configurable)
- **Haptic**: Vibration feedback on touch devices for key events
- **Persistent**: Status bar indicators for ongoing parking state

## 6. Integration with Other Workflows

### 6.1 Job Execution Integration
**Pre-Job Parking:**
- Automatic workpiece access positioning before job setup
- Tool change preparation positioning
- Safety positioning for job validation and preview

**Post-Job Parking:**
- Automatic parking after successful job completion
- Error recovery positioning after job failures
- Maintenance positioning after intensive operations

### 6.2 Tool Management Integration
**Tool Change Coordination:**
- Automatic parking before manual tool changes
- Position optimization for tool length sensor access
- Return path planning after tool change completion
- Multi-tool job positioning between operations

### 6.3 Workpiece Setup Integration
**Setup Workflow Support:**
- Parking for initial workpiece installation
- Position optimization for coordinate system setup
- Access positioning for measurement and validation
- Clearance for workpiece adjustment and alignment

## 7. Performance and Efficiency Metrics

### 7.1 Parking Performance Targets
- **Movement Time**: <30 seconds for standard parking operations
- **Position Accuracy**: ±0.1mm from target parking position
- **Safety Response**: <1 second emergency stop activation
- **Success Rate**: >99.5% successful parking completions

### 7.2 User Experience Metrics
- **Task Completion Rate**: >95% successful parking without assistance
- **Time to Proficiency**: Beginner to intermediate progression <5 parking operations
- **Error Recovery Success**: >90% successful recovery from parking errors
- **User Satisfaction**: >4.5/5 rating for parking workflow usability

### 7.3 Adaptive Learning Effectiveness
- **Competency Recognition Accuracy**: >90% correct skill level assessment
- **Workflow Adaptation Success**: >80% user acceptance of adapted workflows
- **Progression Rate**: Measurable improvement in efficiency over time
- **Safety Maintenance**: No degradation in safety adherence as workflows adapt

This parking workflow provides the foundation for safe machine positioning across all operational contexts while adapting to user skill levels and maintaining consistent safety standards.