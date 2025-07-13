# G-Code Execution Workflow

**Author**: Product Management & System Architecture Team  
**Date**: 2025-07-13  
**Purpose**: Define the workflow for executing G-Code programs safely and efficiently with comprehensive monitoring and control

## Executive Summary

G-Code execution is the primary operational workflow where all preparation work culminates in actual machining operations. This workflow emphasizes safety through pre-execution validation, provides real-time monitoring and control, and maintains comprehensive oversight of the machining process while adapting to user competency levels for appropriate intervention capabilities.

## 1. Workflow Overview

### 1.1 Execution Phases
```
G-Code Execution Lifecycle
├── Pre-Execution Validation
│   ├── Program Analysis
│   ├── Setup Verification
│   ├── Safety Checks
│   └── User Confirmation
├── Execution Monitoring
│   ├── Real-time Progress Tracking
│   ├── Performance Monitoring
│   ├── Safety Oversight
│   └── User Interface Updates
├── Intervention Handling
│   ├── Pause Operations
│   ├── Manual Interventions
│   ├── Tool Changes
│   └── Error Recovery
└── Completion Processing
    ├── Job Completion Verification
    ├── Post-job Positioning
    ├── Performance Analysis
    └── Learning System Updates
```

### 1.2 Execution States
- **Pre-execution**: Program loaded but not started
- **Running**: Active G-Code execution in progress
- **Paused**: Temporary halt with resumption capability
- **Manual Intervention**: User-controlled operations during pause
- **Tool Change**: Automatic tool change in progress
- **Error/Alarm**: Execution halted due to error condition
- **Completed**: Job execution finished successfully
- **Aborted**: Job execution terminated by user or error

## 2. Pre-Execution Validation

### 2.1 Program Analysis and Validation
**Purpose**: Ensure G-Code program is safe and ready for execution

**UI Elements Required:**
- G-Code program display with syntax highlighting
- Validation results panel with issue categorization
- Toolpath visualizer with collision detection
- Program statistics and execution estimates

**Validation Components:**
1. **Syntax and Compatibility Analysis**
   - Parse G-Code for syntax errors and warnings
   - Verify command compatibility with grblHAL controller
   - Check for unsupported or deprecated commands
   - Validate modal state consistency throughout program

2. **Toolpath and Safety Analysis**
   - Generate complete toolpath for visualization
   - Perform collision detection against machine geometry
   - Verify all positions within machine travel limits
   - Check for rapid movements through workpiece
   - **Router-specific**: Validate cut depths against spoilboard position
   - **Router-specific**: Analyze through-cutting operations for safe spoilboard penetration

3. **Tool and Operation Validation**
   - Verify all required tools are defined and available
   - Check tool changes against available tool positions
   - Validate feed rates and spindle speeds
   - Assess operation suitability for workpiece material

**Validation Results Display:**
```typescript
interface ValidationResult {
  status: 'valid' | 'warning' | 'error';
  issues: ValidationIssue[];
  programStats: ProgramStatistics;
  estimatedRunTime: number;
  recommendations: string[];
}

interface ValidationIssue {
  severity: 'info' | 'warning' | 'error' | 'critical';
  lineNumber: number;
  category: 'syntax' | 'safety' | 'performance' | 'compatibility';
  description: string;
  suggestion?: string;
  autoFix?: boolean;
}

interface ProgramStatistics {
  totalLines: number;
  totalCommands: number;
  toolChanges: number;
  estimatedDistance: number;
  estimatedMaterial: number;
  feedRateRange: { min: number; max: number };
  spindleSpeedRange: { min: number; max: number };
}
```

**Error Handling:**
- **Critical Errors**: Block execution until resolved
- **Warnings**: Allow execution with user acknowledgment
- **Performance Issues**: Provide optimization suggestions
- **Compatibility Problems**: Offer alternative approaches or workarounds

### 2.2 Setup Verification
**Purpose**: Confirm machine and workpiece setup matches program requirements

**UI Elements Required:**
- Setup checklist with status indicators
- Current machine state display
- Tool and workpiece verification panels
- Coordinate system validation

**Verification Checklist:**
1. **Machine State Verification**
   - Confirm machine is homed and in idle state
   - Verify no active alarms or error conditions
   - Check spindle and coolant system functionality
   - Validate emergency stop system operation

2. **Tool Setup Verification**
   - Confirm correct tool is installed for first operation
   - Verify tool length offset is properly set
   - Check tool condition and suitability
   - Validate tool change positions are accessible

3. **Workpiece and Coordinate System Verification**
   - Confirm workpiece origin is properly set
   - Verify coordinate system matches program requirements
   - Check workpiece clamping and stability
   - Validate fixture alignment and clearances

4. **Safety System Verification**
   - Test emergency stop functionality
   - Verify limit switch operation
   - Check safety interlocks and guards
   - Confirm operator safety equipment

**Setup Status Display (Sheet Goods Router):**
```
┌─────────────────────────────────────────────────────────┐
│                 EXECUTION READINESS                     │
├─────────────────────────────────────────────────────────┤
│  Machine Status           ✓ Homed and Idle             │
│  Tool Setup              ✓ Tool #1 (6mm End Mill)      │
│  XY Origin               ✓ Workpiece Corner (X:0 Y:0)  │
│  Z-Zero Reference        ✓ Spoilboard Surface (Z:0)    │
│  Material Thickness      ✓ 12.8mm @Z:+12.8mm          │
│  Safety Systems          ✓ All Systems Operational     │
│  Program Validation      ✓ No Critical Issues          │
│                                                         │
│  Sheet Goods Analysis:                                  │
│  📏 Material spans: Z:0.0 to Z:+12.8mm                │
│  🎯 Program cuts: Z:+12.0 to Z:-0.7mm                 │
│  🛡️  Spoilboard penetration: 0.7mm ✓ Reasonable       │
│  ✅ Complete cut-through confirmed                     │
│                                                         │
│  Warnings (1):                                         │
│  • Tool change required at line 567                    │
│                                                         │
│  Estimated Run Time: 1h 23m                           │
│  Material Removal: ~45 cm³                             │
│  Spoilboard Removal: ~2.1 cm³                          │
│                                                         │
│  [Start Job] [Adjust Cut Depth] [Review Analysis]      │
└─────────────────────────────────────────────────────────┘
```

### 2.3 User Confirmation and Final Checks
**Purpose**: Obtain explicit user confirmation for job execution

**Confirmation Levels by Competency:**

**Beginner (Brenda) Confirmation:**
- Detailed pre-execution checklist with explanations
- Mandatory safety briefing and acknowledgment
- Step-by-step confirmation of each major setup element
- Clear explanation of what will happen during execution

**Intermediate User Confirmation:**
- Summary checklist with key points highlighted
- Safety confirmation with reduced detail
- Quick review of critical setup elements
- Streamlined but thorough confirmation process

**Expert (Mark) Confirmation:**
- Minimal confirmation with key metrics displayed
- Advanced information (toolpath analysis, optimization suggestions)
- Quick execution option with safety override capability
- Performance and efficiency data for optimization

## 3. Execution Monitoring and Control

### 3.1 Real-time Progress Tracking
**Purpose**: Provide comprehensive real-time feedback on job execution

**UI Elements Required:**
- Progress indicators showing completion percentage
- Current operation display with line number
- Real-time position tracking in visualizer
- Performance metrics and time estimates

**Progress Display Integration:**
```typescript
interface ExecutionProgress {
  currentLine: number;
  totalLines: number;
  percentComplete: number;
  currentOperation: string;
  estimatedTimeRemaining: number;
  elapsedTime: number;
  currentPosition: Position3D;
  currentFeedRate: number;
  currentSpindleSpeed: number;
}

interface PerformanceMetrics {
  actualVsEstimatedTime: number;
  averageFeedRate: number;
  materialRemovalRate: number;
  toolUtilization: number;
  pauseTime: number;
  interventionCount: number;
}
```

**Progress Display:**
```
┌─────────────────────────────────────────────────────────┐
│                  JOB EXECUTION                          │
├─────────────────────────────────────────────────────────┤
│  Progress: ████████████░░░░ 75%                        │
│  Line 567 of 756  •  Est. Remaining: 18m 32s          │
│                                                         │
│  Current Operation: Linear Move (G1)                   │
│  Position: X:125.34 Y:67.89 Z:-2.45                   │
│  Feed: 1000 mm/min  •  Spindle: 18000 RPM             │
│                                                         │
│  [Pause] [Emergency Stop] [Override]                   │
│                                                         │
│  Performance:                                           │
│  Efficiency: 95%  •  Material Rate: 12.3 cm³/min      │
└─────────────────────────────────────────────────────────┘
```

### 3.2 Visualizer Integration During Execution
**Purpose**: Provide real-time visual feedback of machining progress

**Visualizer Elements:**
- **Real-time Tool Position**: Current tool location with smooth tracking
- **Completed Toolpath**: Already executed path highlighted in different color
- **Upcoming Path**: Next operations shown with preview
- **Progress Indicator**: Visual completion percentage on toolpath
- **Collision Monitoring**: Real-time collision detection and warnings
- **Sheet Goods Layers**: Visual representation of spoilboard (Z=0) and material (+Z) layers
- **Cut Depth Indication**: Through-cut operations shown penetrating below Z=0 into spoilboard
- **Material Boundaries**: Clear visualization of workpiece top surface and spoilboard reference

**Intelligent Viewport Management:**
- **Auto-follow Mode**: Camera follows tool position like GPS navigation
- **Context Mode**: Zoom out for rapid moves, zoom in for detailed operations
- **Manual Override**: User can take control of viewport with auto-return option
- **Operation-specific Views**: Different zoom levels for different operation types

### 3.3 Performance Monitoring
**Purpose**: Track execution performance and identify optimization opportunities

**Performance Metrics Tracking:**
1. **Execution Efficiency**
   - Actual vs estimated time comparison
   - Feed rate utilization analysis
   - Spindle speed optimization tracking
   - Pause and intervention time impact

2. **Quality Indicators**
   - Position accuracy monitoring
   - Feed rate consistency analysis
   - Spindle speed stability tracking
   - Unexpected stops or alarms

3. **System Performance**
   - Communication latency monitoring
   - Command processing efficiency
   - Real-time update performance
   - Memory and CPU utilization

**Error Handling During Execution:**
- **Communication Interruption**: Automatic pause with recovery procedures
- **Limit Switch Activation**: Immediate stop with position preservation
- **Spindle or Coolant Issues**: Controlled stop with system status assessment
- **Position Deviation**: Monitoring for unexpected position errors

## 4. User Interface State Management

### 4.1 Execution Mode UI Behavior
**Purpose**: Adapt user interface appropriately during job execution

**UI State Changes During Execution:**
```typescript
interface ExecutionUIState {
  jogControlsEnabled: boolean;
  settingsModificationAllowed: boolean;
  fileOperationsAllowed: boolean;
  emergencyStopAlwaysVisible: boolean;
  executionControlsVisible: boolean;
  performanceDataVisible: boolean;
}

const executionUIState: ExecutionUIState = {
  jogControlsEnabled: false, // Completely disabled during execution
  settingsModificationAllowed: false, // No settings changes during job
  fileOperationsAllowed: false, // No file loading/unloading
  emergencyStopAlwaysVisible: true, // Always accessible
  executionControlsVisible: true, // Pause, override controls
  performanceDataVisible: true, // Real-time metrics
};
```

**Jog Controls Widget During Execution:**
- Complete disabling of all jog controls
- Clear visual indication of disabled state
- "JOB RUNNING - JOG DISABLED" overlay
- Emergency stop remains prominently available
- Real-time position display continues to function

**DRO Widget During Execution:**
- Enhanced real-time position updates
- Current operation information display
- Feed rate and spindle speed monitoring
- Progress indicators and time estimates
- Execution status prominently displayed

### 4.2 Execution Control Interface
**Purpose**: Provide appropriate control options during job execution

**Available Controls During Execution:**
1. **Emergency Stop**: Immediate halt of all operations
2. **Pause/Resume**: Controlled pause with safe resumption
3. **Feed Rate Override**: Real-time feed rate adjustment
4. **Spindle Speed Override**: Real-time spindle speed adjustment
5. **Single Block**: Execute one command at a time for debugging

**Real-Time Feeds & Speeds Adjustment Guidance:**

**When to Adjust Feed Rate:**
- **Reduce (50-75%)**: Chatter, poor surface finish, excessive tool deflection, first time with new material
- **Increase (110-125%)**: Good surface finish, no chatter, want faster completion, proven toolpath
- **Emergency Reduce (10-25%)**: Tool breaking sounds, machine binding, obvious problems

**When to Adjust Spindle Speed:**
- **Reduce (75-90%)**: Material burning, chips welding together, excessive heat, aluminum galling
- **Increase (110-125%)**: Poor surface finish on plastics, wood burning, need better chip formation
- **Match Material**: Harder materials often need slower speeds, softer materials faster speeds

**What to Listen/Watch For:**
- **Good Cutting**: Steady chip formation, consistent sound, smooth surface finish
- **Feed Too Fast**: Chatter, poor finish, tool deflection, machine struggling
- **Feed Too Slow**: Built-up edge on tool, burnishing, excessive tool wear
- **Speed Too Fast**: Burning, welding chips, tool overheating, poor chip color
- **Speed Too Slow**: Poor finish, chattering, tool rubbing instead of cutting

**Override Controls:**
```
┌─────────────────────────────────────────────────────────┐
│                 EXECUTION OVERRIDES                     │
├─────────────────────────────────────────────────────────┤
│  Feed Rate: [────●────] 100%  (1000 mm/min)           │
│  Spindle:   [──●──────]  75%  (13500 RPM)             │
│                                                         │
│  Quick Adjust: [50%] [75%] [100%] [125%] [150%]        │
│  Emergency: [SLOW 25%] [STOP FEED] [NORMAL 100%]       │
│                                                         │
│  Single Block: [Off] [On] - Step through line by line  │
│  Dry Run: [Off] [On] - No Z-moves, test XY motion     │
└─────────────────────────────────────────────────────────┘
```

**Material-Specific Starting Points:**
- **Aluminum**: Start at 75% feed, 100% spindle, watch for galling
- **Steel**: Start at 100% feed, 75-90% spindle, listen for chatter  
- **Wood**: Start at 125% feed, 100% spindle, watch for burning
- **Plastic**: Start at 75% feed, 75% spindle, prevent melting
- **Unknown Material**: Start at 50% everything, increase carefully

**Error Handling for Override Operations:**
- **Invalid Override Values**: Limit overrides to safe ranges
- **Controller Rejection**: Handle override command failures gracefully
- **Performance Impact**: Warn about extreme override values
- **Safety Limits**: Prevent overrides that compromise safety

## 5. Pause and Manual Intervention

### 5.1 Controlled Pause Operations
**Purpose**: Safely pause execution for manual intervention

**UI Elements Required:**
- Pause confirmation and options
- Manual intervention controls
- Resume preparation checklist
- State preservation indicators

**Pause Execution Steps:**
1. **Controlled Stop**
   - Complete current G-Code command before stopping
   - Position spindle and coolant to safe state
   - Preserve exact execution state for resumption
   - Update UI to reflect paused state

2. **Manual Mode Activation**
   - Enable manual intervention capabilities
   - Provide access to jog controls with restrictions
   - Allow tool changes and workpiece adjustments
   - Maintain position awareness and safety

3. **State Preservation**
   - Record exact program position and modal state
   - Preserve feed rate and spindle speed settings
   - Maintain coordinate system and offset information
   - Track all changes made during manual intervention

**Manual Intervention Controls:**
```
┌─────────────────────────────────────────────────────────┐
│                 JOB PAUSED - MANUAL MODE                │
├─────────────────────────────────────────────────────────┤
│  Paused at Line: 234  •  Time Paused: 3m 15s          │
│  Position: X:67.45 Y:123.67 Z:-1.25                   │
│                                                         │
│  Manual Operations Available:                           │
│  • [Jog Controls] - Limited movement                   │
│  • [Tool Change] - Manual tool change procedure        │
│  • [Workpiece Adjust] - Minor position corrections     │
│  • [Measurement] - Quality control checks              │
│                                                         │
│  Resume Job:                                            │
│  [Pre-Resume Check] [Resume Execution] [Abort Job]     │
│                                                         │
│  Warning: Return to exact position before resuming     │
└─────────────────────────────────────────────────────────┘
```

### 5.2 Resume Preparation and Validation
**Purpose**: Ensure safe and accurate job resumption after manual intervention

**Resume Validation Steps:**
1. **Position Verification**
   - Verify tool is at correct position for resumption
   - Check that no workpiece or fixture changes affect job
   - Confirm coordinate system integrity
   - Validate tool length offset accuracy

2. **System State Verification**
   - Restore spindle speed and coolant state
   - Verify feed rate and modal state preservation
   - Check emergency stop and safety system function
   - Confirm communication with controller

3. **Safety Assessment**
   - Check for any changes that affect job safety
   - Verify clearances and collision avoidance
   - Assess workpiece clamping and stability
   - Confirm operator safety and positioning

**Error Handling for Resume Operations:**
- **Position Deviation**: Guide user through position correction
- **State Inconsistency**: Resolve modal state conflicts before resumption
- **Safety Issues**: Address safety concerns before allowing resume
- **Communication Problems**: Re-establish controller communication

## 6. Tool Change During Execution

### 6.1 Automatic Tool Change Integration
**Purpose**: Handle tool change commands during program execution

**UI Elements Required:**
- Tool change notification and guidance
- Current and next tool information
- Tool change progress indicators
- Manual intervention interface for tool changes

**Tool Change Workflow Integration:**
1. **Tool Change Detection**
   - Identify tool change commands during program parsing
   - Pre-position machine at tool change location
   - Pause execution and notify user of required tool change
   - Provide clear guidance for tool change procedure

2. **Manual Tool Change Execution**
   - Guide user through systematic tool change workflow
   - Verify new tool installation and security
   - Perform tool length measurement if required
   - Update tool offsets and machine state

3. **Post-Tool Change Validation**
   - Verify correct tool installation and offset
   - Test tool operation and safety
   - Position tool for job resumption
   - Resume program execution from correct state

**Tool Change Status Display:**
```
┌─────────────────────────────────────────────────────────┐
│                   TOOL CHANGE REQUIRED                  │
├─────────────────────────────────────────────────────────┤
│  Job Progress: ████████░░░░ 60% Complete               │
│  Current Tool: #1 (6mm End Mill)                       │
│  Next Tool: #3 (3mm End Mill)                          │
│                                                         │
│  Tool Change Location: X:50 Y:350 Z:0                  │
│  [Move to Tool Change Position]                        │
│                                                         │
│  Tool Change Steps:                                     │
│  1. ✓ Move to tool change position                     │
│  2. □ Remove current tool                              │
│  3. □ Install new tool                                 │
│  4. □ Measure tool length                              │
│  5. □ Resume job execution                             │
│                                                         │
│  [Start Tool Change Workflow]                          │
└─────────────────────────────────────────────────────────┘
```

## 7. Error Handling and Recovery

### 7.1 Execution Error Categories
**Purpose**: Categorize and handle different types of execution errors

**Error Classifications:**
1. **Communication Errors**
   - Controller communication loss
   - Command transmission failures
   - Status update interruptions
   - Network connectivity issues

2. **Machine Errors**
   - Limit switch activation
   - Spindle or coolant system failures
   - Position feedback errors
   - Mechanical issues or binding

3. **Program Errors**
   - Invalid command sequences
   - Coordinate system problems
   - Tool-related errors
   - Unexpected program termination

4. **Safety System Activation**
   - Emergency stop activation
   - Safety interlock triggering
   - Collision detection activation
   - Operator safety interventions

### 7.2 Error Recovery Procedures
**Purpose**: Provide systematic recovery from execution errors

**Recovery Workflow:**
1. **Immediate Safety Response**
   - Secure machine in safe state
   - Assess immediate safety risks
   - Preserve position and state information
   - Notify user of error condition

2. **Error Analysis and Diagnosis**
   - Identify specific error cause and type
   - Assess impact on job execution
   - Determine recovery options and requirements
   - Provide clear explanation to user

3. **Recovery Options**
   - **Resume from Current Position**: Continue from error point
   - **Resume from Previous Safe Point**: Backtrack to safe location
   - **Manual Intervention**: Allow user correction of issues
   - **Job Restart**: Restart job from beginning
   - **Job Termination**: Safe abort with cleanup

4. **Recovery Validation**
   - Verify error correction effectiveness
   - Test system functionality before resumption
   - Confirm safety systems operation
   - Validate job execution capability

**Error Recovery UI:**
```
┌─────────────────────────────────────────────────────────┐
│                     EXECUTION ERROR                     │
├─────────────────────────────────────────────────────────┤
│  Error Type: Y-Axis Limit Switch Activated             │
│  Position: X:125.45 Y:400.00 Z:-2.50                  │
│  Line: 445 of 756  •  Time Elapsed: 45m 12s           │
│                                                         │
│  Error Description:                                     │
│  Y-axis limit switch activated during rapid move.      │
│  Machine stopped safely at current position.           │
│                                                         │
│  Recovery Options:                                      │
│  1. [Check and Clear Limits] - Verify safe clearance  │
│  2. [Manual Position] - Jog to safe position          │
│  3. [Resume from Line 440] - Restart before move      │
│  4. [Abort Job] - Terminate job safely                │
│                                                         │
│  [Troubleshooting Guide] [Contact Support]             │
└─────────────────────────────────────────────────────────┘
```

## 8. Job Completion and Analysis

### 8.1 Completion Verification
**Purpose**: Verify successful job completion and final state

**Completion Verification Steps:**
1. **Program Completion Confirmation**
   - Verify all G-Code commands executed successfully
   - Check for any skipped or failed operations
   - Confirm final position and machine state
   - Validate completion against program expectations

2. **Quality Assessment**
   - Provide opportunity for quality inspection
   - Document any issues or observations
   - Record completion time and performance metrics
   - Assess overall job success and quality

3. **Machine State Finalization**
   - Park machine in appropriate position
   - Secure spindle and coolant systems
   - Update tool usage and condition records
   - Prepare for next operation or shutdown

### 8.2 Performance Analysis and Learning
**Purpose**: Analyze job performance and update learning systems

**Performance Analysis:**
```typescript
interface JobPerformanceAnalysis {
  plannedTime: number;
  actualTime: number;
  efficiency: number;
  pauseTime: number;
  interventionCount: number;
  errorCount: number;
  materialRemovalRate: number;
  toolUtilization: number;
  qualityAssessment: QualityMetrics;
}

interface LearningSystemUpdate {
  userCompetencyAssessment: CompetencyMetrics;
  workflowOptimizations: OptimizationSuggestion[];
  performanceImprovements: PerformanceRecommendation[];
  safetyObservations: SafetyAssessment;
}
```

**Job Completion Report:**
```
┌─────────────────────────────────────────────────────────┐
│                   JOB COMPLETED                         │
├─────────────────────────────────────────────────────────┤
│  Job: workpiece_v2.nc                               │
│  Completion Time: 1h 18m 45s (Est: 1h 23m)            │
│  Efficiency: 96%  •  Material Removed: 42.3 cm³       │
│                                                         │
│  Performance Summary:                                   │
│  • Tool Changes: 2 (Est: 2)                           │
│  • Pause Time: 3m 15s                                 │
│  • Manual Interventions: 1                            │
│  • No Errors or Alarms                                │
│                                                         │
│  Recommendations:                                       │
│  • Feed rate could be increased by 5% for efficiency  │
│  • Tool change time improved - great progress!        │
│                                                         │
│  [Save Report] [Start New Job] [Machine Maintenance]   │
└─────────────────────────────────────────────────────────┘
```

## 9. Integration with Learning System

### 9.1 Competency Assessment During Execution
**Purpose**: Continuously assess and update user competency based on execution performance

**Assessment Metrics:**
- Response time to alerts and interventions
- Appropriate use of override controls
- Quality of manual interventions during pauses
- Error recovery effectiveness
- Safety compliance during execution

### 9.2 Adaptive Workflow Enhancement
**Purpose**: Improve workflow efficiency based on execution experience

**Learning Integration:**
- Optimize default settings based on user preferences
- Suggest workflow improvements based on performance patterns
- Adapt notification and guidance levels based on competency
- Provide personalized tips and recommendations

## 10. Success Metrics and Performance Targets

### 10.1 Execution Performance Targets
- **Job Success Rate**: >98% jobs complete without critical errors
- **Execution Efficiency**: >90% actual vs estimated time accuracy
- **User Intervention Rate**: <5% jobs requiring manual intervention
- **Error Recovery Rate**: >95% successful recovery from recoverable errors

### 10.2 User Experience Metrics
- **Confidence in Execution**: User comfort with unattended operation
- **Error Understanding**: User comprehension of error conditions
- **Recovery Success**: User ability to recover from execution issues
- **Learning Progression**: Measurable improvement in execution efficiency

This G-Code execution workflow provides comprehensive oversight and control of the machining process while maintaining safety and adapting to user competency levels for optimal operation.