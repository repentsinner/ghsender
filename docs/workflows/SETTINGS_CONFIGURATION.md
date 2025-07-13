# Settings Configuration Workflow

**Author**: Product Management & System Architecture Team  
**Date**: 2025-07-13  
**Purpose**: Define the workflow for configuring both sender application settings and machine controller parameters

## Executive Summary

Settings configuration is a foundational workflow that must accommodate both first-time setup and ongoing maintenance. The workflow integrates VS Code-style JSON configuration with beginner-friendly GUI overlays, allowing users to progress from guided setup to expert-level customization as their competency develops.

## 1. Workflow Overview

### 1.1 Settings Hierarchy
```
Application Settings
├── Machine Configuration
│   ├── Connection Settings (IP, Port, Timeout)
│   ├── Physical Limits (Travel, Speeds, Acceleration)
│   ├── Pre-defined Positions (Home, Tool Change, etc.)
│   └── Safety Settings (Collision Detection, Emergency Stop)
├── User Interface Settings
│   ├── Display Preferences (Units, Precision, Theme)
│   ├── Competency Level (Beginner/Intermediate/Expert)
│   ├── Widget Layouts and Visibility
│   └── Keyboard Shortcuts
├── Workflow Settings
│   ├── Tool Change Procedures
│   ├── Touchoff Methods
│   ├── Learning System Preferences
│   └── Safety Confirmation Levels
└── Controller Configuration (grblHAL Settings)
    ├── Motion Settings ($100-$132)
    ├── Safety Settings ($20-$27)
    ├── Spindle/Coolant ($30-$35)
    └── Advanced Features ($40+)
```

### 1.2 Entry Points
- **First Launch**: Mandatory setup wizard for new installations
- **Settings Menu**: Main application settings access via command palette or menu
- **Machine Setup**: Dedicated machine configuration when connecting to new controller
- **Workflow Customization**: Context-sensitive settings during workflow execution
- **Emergency Reconfiguration**: Quick access during error recovery

## 2. First Launch Setup Wizard

### 2.1 Welcome and Machine Detection
**Purpose**: Establish basic connection and identify machine capabilities

**UI Elements Required:**
- Connection widget with network discovery
- Machine detection display
- Progress indicator showing setup steps
- Skip/Advanced options for expert users

**Workflow Steps:**
1. **Welcome Screen**
   - Brief explanation of setup process
   - Estimated time (5-15 minutes depending on complexity)
   - Option to import existing configuration
   - Expert mode option to skip wizard

2. **Network Discovery**
   - Automatic scan for grblHAL controllers on network
   - Manual IP entry option
   - Connection testing with real-time feedback
   - Save multiple controller profiles option

3. **Controller Identification**
   - Query controller for capabilities and current settings
   - Display controller version and build info
   - Identify available features (spindle control, coolant, etc.)
   - Warn about unsupported features if any

**Error Handling:**
- **No Controllers Found**: Guide user through manual connection setup
- **Connection Timeout**: Provide network troubleshooting steps
- **Unsupported Controller**: Clear explanation of grblHAL requirement
- **Configuration Mismatch**: Offer to reset controller to known good state

### 2.2 Machine Physical Configuration
**Purpose**: Define machine geometry and capabilities

**UI Elements Required:**
- Machine limits input form with validation
- Pre-defined machine type selection (Shapeoko, X-Carve, Custom)
- 3D visualization of machine envelope
- Position testing interface

**Workflow Steps:**
1. **Machine Type Selection**
   - Common machine presets with automatic configuration
   - Custom machine option for manual configuration
   - Import configuration from file option
   - Visual previews of machine types

2. **Travel Limits Configuration**
   - Input fields for X, Y, Z travel limits with validation
   - Real-time visualization in machine envelope display
   - Test movement to verify limits (optional)
   - Safety margin configuration

3. **Pre-defined Position Setup**
   - Tool change position configuration with guided positioning
   - Tool length sensor position (if available)
   - Parking position for workpiece loading
   - Home position verification

**Error Handling:**
- **Invalid Limits**: Real-time validation with clear error messages
- **Movement Test Failure**: Guide user through manual limit verification
- **Position Conflicts**: Automatic collision detection and resolution suggestions
- **Hardware Limits**: Warn when configured limits exceed controller capabilities

### 2.3 User Experience Preferences
**Purpose**: Configure adaptive learning and interface preferences

**UI Elements Required:**
- Experience level selection with descriptions
- Learning preferences configuration
- Interface layout selection
- Accessibility options

**Workflow Steps:**
1. **Experience Level Assessment**
   - Self-assessment questionnaire (How long have you used CNCs?)
   - Demonstration of interface differences at each level
   - Option to change later with clear explanation
   - Impact explanation for each choice

2. **Learning System Configuration**
   - Enable/disable adaptive learning
   - Set progression speed preferences
   - Configure celebration and feedback preferences
   - Safety confirmation level preferences

3. **Interface Customization**
   - Unit preferences (metric/imperial) with conversion examples
   - Color theme selection (light/dark/high-contrast)
   - Widget visibility and arrangement preferences
   - Accessibility feature configuration

**Error Handling:**
- **Conflicting Preferences**: Guide user through resolution with explanations
- **Accessibility Conflicts**: Automatic compatibility checking and suggestions
- **Invalid Combinations**: Prevent problematic combinations with clear explanations

## 3. Ongoing Settings Management

### 3.1 VS Code-Style Configuration System
**Implementation Architecture:**
```typescript
interface AppSettings {
  machine: MachineConfiguration;
  ui: UserInterfaceSettings;
  workflows: WorkflowSettings;
  learning: LearningSettings;
  controller: ControllerSettings;
}

// Example settings.json structure
{
  "machine": {
    "connection": {
      "hostname": "192.168.1.100",
      "port": 23,
      "timeout": 5000
    },
    "limits": {
      "x": { "min": 0, "max": 800 },
      "y": { "min": 0, "max": 800 },
      "z": { "min": -100, "max": 0 }
    },
    "predefinedPositions": {
      "home": { "x": 0, "y": 0, "z": 0 },
      "toolChange": { "x": 50, "y": 350, "z": 0 },
      "toolLengthSensor": { "x": 150, "y": 150, "z": -10 }
    }
  },
  "ui": {
    "units": "metric",
    "precision": 3,
    "theme": "dark",
    "competencyLevel": "intermediate"
  },
  "workflows": {
    "toolChange": {
      "requireConfirmation": true,
      "autoSafeHeight": true,
      "adaptiveSpeed": true
    }
  }
}
```

### 3.2 GUI Settings Interface
**For Beginners/Intermediate Users:**

**Machine Settings Panel:**
```
┌─────────────────────────────────────────────────────────┐
│                 MACHINE CONFIGURATION                   │
├─────────────────────────────────────────────────────────┤
│  Connection                                             │
│  IP Address: [192.168.1.100] Test Connection: [✓]      │
│  Port: [23]              Timeout: [5000ms]             │
│                                                         │
│  Travel Limits (mm)                                     │
│  X-Axis: Min [0.000] Max [800.000]                     │
│  Y-Axis: Min [0.000] Max [800.000]                     │
│  Z-Axis: Min [-100.000] Max [0.000]                    │
│  [Test Limits] [Import from Controller]                │
│                                                         │
│  Pre-defined Positions                                  │
│  ┌─────────────────┐ ┌─────────────────┐               │
│  │ Tool Change Pos │ │ Tool Length Sns │               │
│  │ X: 50.000       │ │ X: 150.000      │               │
│  │ Y: 350.000      │ │ Y: 150.000      │               │
│  │ Z: 0.000        │ │ Z: -10.000      │               │
│  │ [Set Current]   │ │ [Set Current]   │               │
│  └─────────────────┘ └─────────────────┘               │
│                                                         │
│  [Advanced Settings...] [Export Config] [Import Config]│
└─────────────────────────────────────────────────────────┘
```

### 3.3 Controller Settings Integration
**Purpose**: Configure grblHAL controller parameters safely

**UI Elements Required:**
- Controller parameter browser with descriptions
- Real-time parameter validation
- Backup/restore functionality
- Parameter grouping by function

**Parameter Categories:**
1. **Motion Configuration**
   - Steps per mm for each axis (how many motor steps equal 1mm movement) [grblHAL $100-$102]
     - *How to calculate*: (Motor steps per revolution × Microstep setting) ÷ (Belt pitch × Pulley teeth) for belt drive
     - *How to calculate*: (Motor steps per revolution × Microstep setting) ÷ Thread pitch for lead screw
     - *Testing procedure*: Use built-in calibration wizard to measure actual movement vs. commanded movement
   - Maximum movement speeds and acceleration limits [grblHAL $110-$132]
     - *Starting point*: Use 50% of theoretical maximum for feed rates, increase until you hear skipping
     - *Acceleration*: Start conservative (500mm/s²), increase until movement becomes jerky
   - Motor timing and pulse settings [grblHAL $0-$2]
     - *Default guidance*: Most stepper drivers work with 10 microseconds, try 5-25 range for problems

2. **Safety and Machine Limits**
   - Software travel limits (prevent moves beyond safe area) [grblHAL $20-$23]
   - Physical limit switch configuration [grblHAL $5, $22]
   - Homing procedure setup (how machine finds reference position) [grblHAL $24-$27]
   - Emergency stop and safety interlock settings

3. **Spindle and Coolant Systems**
   - Spindle control configuration (start/stop, speed control) [grblHAL $30-$32]
   - Spindle speed configuration
   - Coolant control settings

4. **Advanced Features**
   - Tool change position and behavior settings [grblHAL $40+]
   - Touch probe configuration and sensitivity [grblHAL probe settings]
   - Communication timing and protocol settings

**Workflow Steps:**
1. **Parameter Discovery**
   - Query controller for all supported parameters
   - Display current values with descriptions
   - Identify parameters that differ from defaults
   - Group related parameters logically

2. **Safe Parameter Modification**
   - Backup current settings before changes
   - Validate parameter ranges against controller limits
   - Preview impact of changes where possible
   - Staged application with rollback capability

3. **Motor Calibration Testing Procedure**

**Built-in Steps Per MM Calibration Wizard:**
```
┌─────────────────────────────────────────────────────────┐
│              STEPS PER MM CALIBRATION                   │
├─────────────────────────────────────────────────────────┤
│  X-Axis Calibration                                     │
│                                                         │
│  Current Setting: 80.0 steps/mm                        │
│  Theoretical: 80.0 steps/mm (from machine specs)       │
│                                                         │
│  Test Procedure:                                        │
│  1. [Position at Current Location]                     │
│  2. Command 100mm move: [Move +100mm]                  │
│  3. Measure actual distance moved: [____] mm           │
│                                                         │
│  Calculated Correction: 80.0 × (100 ÷ measured) =     │
│  New Steps/MM: [80.8] (3% correction needed)           │
│                                                         │
│  [Apply Correction] [Test Again] [Manual Entry]        │
│                                                         │
│  💡 Tip: Use calipers or ruler, measure multiple times │
└─────────────────────────────────────────────────────────┘
```

**Step-by-Step Motor Configuration Process:**

**Phase 1: Calculate Theoretical Steps/MM**
1. **Find Your Drive System Values:**
   - Motor: Steps per revolution (usually 200 for 1.8° steppers)
   - Driver: Microstep setting (1, 2, 4, 8, 16, or 32)
   - Mechanical: Belt pitch & pulley teeth OR lead screw pitch

2. **Common Drive System Examples:**
   ```
   GT2 Belt + 20-tooth pulley:
   (200 steps × 16 microsteps) ÷ (2mm pitch × 20 teeth) = 80 steps/mm
   
   GT2 Belt + 16-tooth pulley:
   (200 steps × 16 microsteps) ÷ (2mm pitch × 16 teeth) = 100 steps/mm
   
   8mm Lead Screw:
   (200 steps × 16 microsteps) ÷ 8mm pitch = 400 steps/mm
   
   5mm Lead Screw:
   (200 steps × 8 microsteps) ÷ 5mm pitch = 320 steps/mm
   ```

**Phase 2: Test and Calibrate**
1. **Set theoretical value** in grblHAL settings
2. **Home the machine** to establish reference
3. **Command precise movements** (100mm recommended)
4. **Measure actual movement** with calipers/ruler
5. **Calculate correction**: New = Old × (Commanded ÷ Actual)
6. **Apply correction** and test again
7. **Repeat until accuracy is within 0.1mm**

**Phase 3: Speed and Acceleration Tuning**
1. **Start at 50% of calculated maximum** feed rate
2. **Gradually increase** until you hear motor skipping/stalling
3. **Back off 10-20%** for safety margin
4. **Test acceleration** starting at 500mm/s², increase until jerky
5. **Verify no lost steps** during rapid direction changes

4. **Testing and Validation**
   - Test critical parameters (homing, limits) safely
   - Verify machine behavior after changes
   - Performance impact assessment
   - Rollback mechanism for problematic changes

**Error Handling:**
- **Invalid Parameter Values**: Real-time validation with allowed ranges
- **Controller Rejection**: Clear explanation of why parameter was rejected
- **Communication Errors**: Automatic retry with fallback to manual entry
- **Unsafe Combinations**: Warning about parameter interactions

## 4. Contextual Settings Access

### 4.1 Workflow-Specific Settings
**During Tool Change Workflow:**
- Quick access to tool change position settings
- Confirmation level adjustment
- Safe height preferences
- Tool validation settings

**During Workpiece Setup:**
- Coordinate system preferences
- Touchoff method selection
- Safety margin configuration
- Undo/retry settings

**During Job Execution:**
- Feed rate override limits
- Pause behavior settings
- Progress notification preferences
- Emergency stop behavior

### 4.2 Learning System Integration
**Competency-Based Settings Access:**
- **Beginner**: Guided forms with explanations and examples
- **Intermediate**: Tabbed interface with grouped settings
- **Expert**: Direct JSON editing with IntelliSense

**Progressive Disclosure:**
- Hide advanced options until user demonstrates competency
- Gradually reveal more configuration options
- Provide "simple/advanced" mode toggles
- Remember user preferences for setting complexity

## 5. Error Handling and Recovery

### 5.1 Configuration Validation
**Real-time Validation:**
- Parameter range checking with immediate feedback
- Cross-parameter dependency validation
- Physical limit safety checking
- Communication parameter verification

**Pre-Application Testing:**
- Non-destructive parameter testing where possible
- Motion simulation for movement-related settings
- Safety system verification
- Communication reliability testing

### 5.2 Recovery Mechanisms
**Configuration Backup:**
- Automatic backup before any changes
- Named configuration snapshots
- Export/import for sharing configurations
- Factory reset to known good state

**Error Recovery:**
- Step-by-step rollback procedures
- Partial configuration recovery
- Emergency communication restoration
- Safe mode operation during recovery

### 5.3 User Notification System
**Error Severity Levels:**
1. **Info**: Setting successfully applied, minor warnings
2. **Warning**: Setting applied but may have unexpected effects
3. **Error**: Setting rejected, explanation and resolution steps
4. **Critical**: Configuration corruption, emergency recovery needed

**Notification Methods:**
- Toast notifications for routine changes
- Modal dialogs for warnings requiring acknowledgment
- Persistent status indicators for ongoing issues
- In-context help for parameter-specific guidance

## 6. Advanced Configuration Features

### 6.1 Configuration Profiles
**Machine Profiles:**
- Multiple machine configurations
- Quick switching between machines
- Profile-specific settings inheritance
- Shared settings across profiles

**User Profiles:**
- Personal preference sets
- Competency level progression tracking
- Custom workflow configurations
- Learning history preservation

### 6.2 Collaborative Configuration
**Team Sharing:**
- Export standardized configurations
- Version control integration for configurations
- Template configurations for common setups
- Organizational settings management

**Community Integration:**
- Share/download community configurations
- Vendor-provided machine configurations
- Configuration validation and rating system
- Update notifications for configuration improvements

## 7. Success Metrics

### 7.1 Setup Completion Metrics
- First-time setup completion rate >90%
- Average setup time <15 minutes for typical machines
- Settings validation error rate <5%
- User satisfaction with setup process >4.5/5

### 7.2 Ongoing Usage Metrics
- Frequency of settings changes after initial setup
- Expert mode adoption rate among advanced users
- Configuration error rate during normal operation
- Support request rate for settings-related issues

This settings configuration workflow provides the foundation for all other workflows by establishing reliable machine communication and user preferences that adapt as competency develops.