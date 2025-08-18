# Workpiece Origin Setup Workflow

**Author**: Product Management & System Architecture Team  
**Date**: 2025-07-13  
**Purpose**: Define the workflow for establishing accurate workpiece coordinate systems for G-Code execution

## Executive Summary

Workpiece origin setup is the critical workflow that establishes the relationship between the G-Code coordinate system and the physical workpiece location. This workflow ensures accurate part machining by providing systematic touchoff procedures, coordinate system management, and validation methods that adapt to user competency levels while maintaining precision requirements.

## 1. Workflow Overview

### 1.1 Coordinate System Concepts
```
Coordinate System Hierarchy
├── Machine Coordinates (MPos)
│   ├── Fixed machine reference frame
│   ├── Home position at (0,0,0)
│   └── Never changes once homed
├── Work Coordinates (WPos)
│   ├── Work coordinate systems (Project, Secondary, etc.)
│   ├── Relative to workpiece features
│   └── User-defined origins
└── Part Coordinates
    ├── CAM software coordinate system
    ├── G-Code program zero point
    └── Workpiece feature alignment
```

### 1.2 Origin Setup Methods
- **Corner Reference**: Using workpiece corner as XY origin
  - *When to use*: Single parts, simple rectangular workpieces, one-off projects
  - *Best for*: Beginners, parts that match your CAM setup exactly
- **Center Reference**: Using workpiece center as XY origin
  - *When to use*: Circular parts, symmetrical designs, parts that need centering in fixtures
  - *Best for*: Round stock, symmetrical designs, when CAM was set up with center origin
- **Feature Reference**: Using specific workpiece features (holes, edges)
  - *When to use*: Pre-drilled holes exist, parts with critical alignment requirements
  - *Best for*: Assembly parts, multiple operations on same workpiece, high precision work
- **Fixture Reference**: Using jig or fixture datum points
  - *When to use*: Batch production, repeated setups, complex multi-sided machining
  - *Best for*: Production runs, consistent part positioning, when speed matters more than flexibility

### 1.3 CNC Router Sheet Goods Workflow

**CNC Router Reality:**
CNC routers primarily work with pre-finished sheet goods (plywood, MDF, aluminum sheet) that have thickness variation. The spoilboard becomes the critical reference plane since it's the consistent surface that determines cut-through success.

**Sheet Goods Coordinate System Approach:**
- **XY Origin**: Established on accessible workpiece top surface (corner, edge, or feature)
- **Z Origin**: Established on spoilboard surface (the plane that ensures complete cut-through)
- **Material Thickness**: Measured separately to calculate workpiece bottom position

**Spoilboard-Based Z-Zero Method** (Primary for sheet goods)
  - *When to use*: All through-cutting of sheet goods, production runs, material with thickness variation
  - *Why*: Ensures consistent cut-through regardless of material thickness variation
  - *Process*: Set Z-zero on spoilboard, measure material thickness, calculate safe cut depths
  - *CAM Setup*: G-Code programmed with Z-zero at spoilboard level, negative depths cut into material

**Workpiece Top Z-Zero Method** (Secondary for specialty work)
  - *When to use*: Surface operations only, 3D carving, when material thickness is critical
  - *Limitation*: Requires exact material thickness knowledge for through-cutting
  - *Risk*: Material thickness variation can cause incomplete cuts or excessive spoilboard damage

**Router Sheet Goods Benefits:**
- **Consistent Cut-Through**: Spoilboard reference ensures complete cuts regardless of material variation
- **Spoilboard Preservation**: Controlled penetration depth (typically 0.5-1.0mm) maximizes spoilboard life
- **Production Efficiency**: Same Z-zero works for all sheets of varying thickness
- **Simplified CAM**: Program for worst-case (thickest) material, all thinner material will cut through safely

## 2. Pre-Setup Planning and Assessment

### 2.1 G-Code Analysis and Requirements
**Purpose**: Understand coordinate system requirements from G-Code program

**UI Elements Required:**
- G-Code parser display showing coordinate usage
- Workpiece boundary visualization
- Origin point identification in visualizer
- Coordinate system requirement summary

**Analysis Steps:**
1. **G-Code Coordinate Analysis**
   - Parse G-Code for coordinate system usage (Project Workpiece, Secondary Setup, etc.)
   - Identify minimum and maximum coordinate values
   - Determine critical features and tolerances
   - Calculate workpiece envelope requirements

2. **Origin Point Identification**
   - Identify implied origin point from G-Code coordinates
   - Determine optimal reference features on workpiece
   - Assess accessibility for touchoff operations
   - Plan touchoff sequence for efficiency and accuracy

3. **Precision Requirements Assessment**
   - Identify critical dimensions and tolerances
   - Determine required touchoff accuracy
   - Assess impact of setup errors on part quality
   - Plan validation procedures for setup verification

**Error Handling:**
- **Missing Coordinate System**: Default to "Project Workpiece" with user notification
- **Excessive Workpiece Size**: Warning about machine envelope limits
- **Inaccessible Features**: Guide toward alternative reference methods
- **Precision Conflicts**: Recommend appropriate touchoff methods

### 2.2 Workpiece and Fixture Assessment
**Purpose**: Evaluate physical workpiece for optimal origin setup

**UI Elements Required:**
- Workpiece measurement input forms
- Fixture and clamping consideration display
- Access planning visualization
- Reference feature identification guide

**Assessment Components:**
1. **Physical Workpiece Analysis**
   - Workpiece dimensions and geometry
   - Surface quality and accessibility
   - Feature locations and tolerances
   - Material characteristics affecting touchoff

2. **Fixture and Clamping Evaluation**
   - Clamp locations and accessibility restrictions
   - Fixture datum points and relationships
   - Workpiece deflection considerations
   - Tool clearance around clamping areas

3. **Reference Feature Selection**
   - Evaluate corner accessibility and quality
   - Assess edge straightness and condition
   - Identify best features for accurate touchoff
   - Plan approach angles and tool requirements

**Error Handling:**
- **Poor Surface Quality**: Recommend surface preparation or alternative references
- **Clamping Interference**: Guide through fixture adjustment or alternative clamping
- **Inaccessible Features**: Provide alternative reference feature options
- **Deflection Concerns**: Recommend support strategies or setup modifications

## 3. Coordinate System Selection and Setup

### 3.1 Work Coordinate System Management
**Purpose**: Select and prepare appropriate work coordinate system

**UI Elements Required:**
- Work coordinate system selector (Project Workpiece, Secondary Setup, etc.)
- Current offset display in DRO Widget
- Coordinate system status indicators
- Previous setup history and recall options

**Coordinate System Selection:**
```typescript
interface WorkCoordinateSystem {
  id: 'G54' | 'G55' | 'G56' | 'G57' | 'G58' | 'G59';  // Technical ID for controller
  name: string;
  description: string;
  currentOffset: Position3D;
  lastModified: Date;
  associatedJob?: string;
  locked: boolean; // Prevent accidental modification
}

interface CoordinateSystemManager {
  availableSystems: WorkCoordinateSystem[];
  activateSystem(id: string): void;
  setOffset(id: string, offset: Position3D): void;
  clearOffset(id: string): void;
  lockSystem(id: string, lock: boolean): void;
}
```

**When to Use Multiple Coordinate Systems:**
- **Project Workpiece (G54)**: Your main part setup - use this for single parts and primary operations
- **Secondary Setup (G55)**: When you need to flip the part or do a second operation
  - *Example*: Machine the top of a part, then flip and machine the bottom
  - *Example*: Different clamping setup for finishing operations
- **Fixture A/B/C (G56-G58)**: When you have dedicated fixtures for repeated setups
  - *Example*: Vise jaw position A for small parts, position B for large parts
  - *Example*: Rotary table at 0°, 90°, 180° positions
- **Prototype Setup (G59)**: For testing or experimental setups
  - *Example*: Testing new toolpaths before running on good material
  - *Example*: Quick measurements or probe operations

**Setup Steps:**
1. **System Selection**
   - Choose appropriate work coordinate system based on your operation:
     - First time with this part? Use "Project Workpiece"
     - Flipping part for second operation? Use "Secondary Setup"
     - Using a fixture repeatedly? Create a named fixture coordinate system
   - Display current offset values if any exist
   - Provide clear/reset options for fresh setup
   - Confirm selection with user

2. **Previous Setup Review**
   - Display any existing offsets for selected system
   - Show last modification date and associated job
   - Provide options to keep, modify, or clear existing offsets
   - Warn about impact of changes on other jobs

3. **Setup Method Selection**
   - Choose touchoff method based on workpiece and requirements
   - Select reference features and approach strategy
   - Configure precision requirements and validation
   - Plan touchoff sequence for efficiency

**Error Handling:**
- **System Already in Use**: Warn about impact on other operations
- **Conflicting Offsets**: Provide clear explanation and resolution options
- **Lock Conflicts**: Guide through unlocking procedures if authorized
- **Invalid Selections**: Prevent invalid combinations with clear explanations

### 3.2 Reference Method Configuration
**Purpose**: Configure specific touchoff method and parameters

**Method-Specific Configuration:**

**Corner Reference Setup:**
- Select corner (front-left, rear-right, etc.)
- Configure approach direction and safety margins
- Set edge-finding technique (visual, feel, probe)
- Define X and Y touchoff sequence

**Center Reference Setup:**
- Define center-finding method (measured, calculated)
- Configure workpiece dimensions for calculation
- Set approach pattern for center verification
- Plan validation measurements

**Feature Reference Setup:**
- Identify specific features (holes, bosses, edges)
- Configure feature-specific touchoff procedures
- Set precision requirements for feature location
- Plan verification and validation methods

## 4. XY Origin Touchoff Procedure

### 4.1 Edge Finding Workflow
**Purpose**: Systematically locate workpiece edges for accurate XY origin

**UI Elements Required:**
- Jog Controls Widget with fine positioning capability
- DRO Widget showing real-time position
- Touchoff guidance display with visual aids
- Progress indicator for multi-step touchoff

**Edge Finding Steps:**
1. **X-Axis Edge Location**
   - Position tool above workpiece at safe height
   - Approach suspected edge location
   - Use progressive speeds: rapid → medium → fine
   - Contact detection through feel or probe feedback

2. **Precise Edge Finding**
   - Establish initial edge contact
   - Back away from edge by known distance
   - Approach edge again for verification
   - Record edge position with high precision

3. **Y-Axis Edge Location**
   - Move to Y-axis edge finding position
   - Repeat systematic approach procedure
   - Maintain consistent contact technique
   - Record Y-axis edge position

4. **Origin Calculation**
   - Calculate actual origin point from edge positions
   - Account for tool diameter and approach method
   - Apply workpiece dimension offsets if needed
   - Validate calculated origin position

**Adaptive Guidance by Competency:**

**Beginner (Brenda) Guidance:**
```
┌─────────────────────────────────────────────────────────┐
│                X-AXIS EDGE FINDING                      │
├─────────────────────────────────────────────────────────┤
│  Step 1: Position above workpiece left edge            │
│                                                         │
│  Current Position: X: 45.234  Y: 67.890  Z: 5.000     │
│                                                         │
│  Instructions:                                          │
│  1. Use [0.1mm] jog to approach the edge slowly        │
│  2. Stop when tool just touches the workpiece          │
│  3. You should feel slight resistance                  │
│  4. Click [Record Edge] when positioned correctly      │
│                                                         │
│  [Jog X-] [0.1mm] [Jog X+]     [Record Edge]          │
│                                                         │
│  Need help? [Show Visual Guide] [Contact Support]      │
└─────────────────────────────────────────────────────────┘
```

**Expert (Mark) Guidance:**
```
┌─────────────────────────────────────────────────────────┐
│  X-Edge: [Touch & Record] Y-Edge: [Touch & Record]     │
│  Origin: [Calculate] [Apply] Tool Ø: 6.00mm           │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Tool Compensation and Offset Calculation
**Purpose**: Account for tool geometry in origin calculations

**Tool Compensation Logic:**
```typescript
interface ToolCompensation {
  toolDiameter: number;
  edgeContact: Position3D;
  approachDirection: 'left' | 'right' | 'front' | 'back';
  compensationMethod: 'center' | 'edge';
}

function calculateOriginOffset(
  edgePosition: Position3D,
  toolDiameter: number,
  approachDirection: string,
  targetOrigin: 'corner' | 'center'
): Position3D {
  const toolRadius = toolDiameter / 2;
  let offsetPosition = { ...edgePosition };
  
  // Apply tool radius compensation based on approach direction
  switch (approachDirection) {
    case 'left':
      offsetPosition.x += toolRadius; // Tool center to edge
      break;
    case 'right':
      offsetPosition.x -= toolRadius;
      break;
    case 'front':
      offsetPosition.y -= toolRadius;
      break;
    case 'back':
      offsetPosition.y += toolRadius;
      break;
  }
  
  return offsetPosition;
}
```

**Validation and Verification:**
1. **Measurement Verification**
   - Double-check edge positions with repeat measurements
   - Verify tool diameter compensation calculations
   - Confirm origin position makes sense geometrically
   - Cross-check with workpiece dimensions if known

2. **Position Validation**
   - Move to calculated origin position
   - Verify position relationships to workpiece features
   - Check clearances and accessibility
   - Confirm no interference with fixtures or clamps

## 5. Sheet Goods Origin Setup Procedure

### 5.1 Sheet Goods Workflow Overview
**Purpose**: Establish XY origin on workpiece top and Z-zero on spoilboard for consistent through-cutting

**Sheet Goods Setup Philosophy:**
1. **XY Origin**: Touch off on workpiece top surface where access is easy (corner, edge, feature)
2. **Z-Zero**: Touch off on spoilboard to establish the cut-through reference plane
3. **Material Thickness**: Measure to calculate workpiece position relative to spoilboard
4. **Cut Depths**: Program in CAM as negative depths from spoilboard (Z-zero)

### 5.2 Complete Sheet Goods Setup Workflow

**UI Elements Required:**
- XY edge finding with tool radius compensation
- Z-axis touchoff controls for spoilboard reference
- Material thickness measurement and validation
- Cut depth calculator showing material vs. spoilboard penetration

**Step 1: XY Origin on Workpiece Top**
1. **Workpiece Edge Finding**
   - Position tool above workpiece at safe height
   - Use accessible edges/corners on workpiece top surface
   - Perform standard edge finding procedure (left edge, front edge)
   - Apply tool radius compensation to calculate true workpiece corner
   - Set XY origin at calculated workpiece reference point

**Step 2: Spoilboard Z-Zero Setup**
2. **Move to Spoilboard Access Area**
   - Move to area where spoilboard is exposed (adjacent to workpiece)
   - Ensure spoilboard area is clean and representative
   - Position tool over solid spoilboard area for touchoff
   - Verify safe access without hitting clamps or workpiece

3. **Spoilboard Z-Zero Touchoff**
   - Lower tool to spoilboard surface using progressive speeds
   - Establish contact with spoilboard top surface  
   - **Set this position as Z-zero in work coordinates**
   - Verify spoilboard touchoff with small test moves

**Step 3: Material Thickness Measurement**
4. **Workpiece Thickness Detection**
   - Move tool over workpiece area for thickness measurement
   - Lower tool to workpiece top surface (same touchoff method)
   - Calculate material thickness = Current Z position (should be positive)
   - Validate thickness against expected material specification
   - Store thickness for cut depth calculations

**Step 4: Cut Depth Validation**
5. **G-Code Depth Analysis**
   - Parse G-Code for deepest Z position (most negative value)
   - Calculate actual cut depth = |G-Code min Z| - Material thickness  
   - Validate spoilboard penetration is reasonable (0.5-2.0mm typical)
   - Warn if cuts would be incomplete or excessively deep

**Sheet Goods Origin Setup Interface:**
```
┌─────────────────────────────────────────────────────────┐
│              SHEET GOODS ORIGIN SETUP                   │
├─────────────────────────────────────────────────────────┤
│  Step 1: XY Origin (Workpiece Top)                     │
│  ✓ Left Edge: X=0.000  ✓ Front Edge: Y=0.000          │
│                                                         │
│  Step 2: Z-Zero (Spoilboard Surface)                   │
│  Move to spoilboard area for Z-zero reference          │
│  Current Z: 15.234 mm above home                       │
│                                                         │
│  [Jog Down 1mm] [Jog Down 0.1mm] [Set Spoilboard Zero]│
│                                                         │
│  Step 3: Material Thickness                            │
│  🎯 Spoilboard Z-Zero: Set at Z=0.000                  │
│  📏 Move over workpiece to measure thickness...        │
│                                                         │
│  Material Information:                                  │
│  📏 Measured Thickness: 12.8 mm (Z position above zero)│
│  📋 Expected Thickness: [12.7] mm (user input)        │
│  📊 Variation: +0.1 mm ✓ Within tolerance             │
│                                                         │
│  Cut Depth Analysis:                                    │
│  📐 G-Code Max Depth: -13.5 mm (from spoilboard)      │
│  🔍 Through material: 12.8 mm                          │
│  🛡️  Spoilboard cut: 0.7 mm ✓ Reasonable              │
│                                                         │
│  [Complete Setup] [Adjust Depths] [Re-measure]         │
└─────────────────────────────────────────────────────────┘
```

**Contact Detection Methods for Router Operations:**

**Touch Probe Method (Recommended for routers):**
- Electronic probe with automatic contact detection
- Consistent, repeatable measurements for both surfaces
- Eliminates operator skill requirements
- Ideal for production setups and accurate through-cutting
- *Process*: Probe workpiece top, move to spoilboard area, probe spoilboard

**Manual Touchoff Method:**
- Visual/feel contact detection with cutting tool
- Paper test method for consistent reference
- Requires more operator skill but universally available
- *Process*: Manual touchoff on workpiece, move to spoilboard, manual touchoff

**Hybrid Method:**
- Probe for workpiece top (higher accuracy needed)
- Manual touchoff for spoilboard (less critical precision)
- Balances accuracy with equipment requirements

### 5.3 Sheet Goods Z-Offset Calculation 
**Purpose**: Calculate spoilboard-based coordinate system for consistent through-cutting

**Sheet Goods Offset Calculation:**
```typescript
interface SheetGoodsZConfiguration {
  spoilboardPosition: number; // Machine coordinate of spoilboard surface
  workpieceTopPosition: number; // Machine coordinate of workpiece top
  detectionMethod: 'surface' | 'paper' | 'probe';
  paperThickness?: number;
  probeOffset?: number;
  expectedMaterialThickness?: number;
  maxSpoilboardCut: number; // Maximum allowable spoilboard penetration
}

interface SheetGoodsZResult {
  spoilboardZero: number; // Set to 0.000 (work coordinate zero)
  materialThickness: number; // Positive value above spoilboard
  workpieceTopOffset: number; // Positive Z value of workpiece top
  maxSafeCutDepth: number; // Most negative safe Z value
  recommendedCutDepth: number; // Recommended depth for G-Code programming
}

function calculateSheetGoodsZOffsets(
  config: SheetGoodsZConfiguration
): SheetGoodsZResult {
  let spoilboardSurface = config.spoilboardPosition;
  let workpieceTop = config.workpieceTopPosition;
  
  // Apply detection method corrections
  switch (config.detectionMethod) {
    case 'paper':
      spoilboardSurface += config.paperThickness || 0.1;
      workpieceTop += config.paperThickness || 0.1;
      break;
    case 'probe':
      spoilboardSurface += config.probeOffset || 0;
      workpieceTop += config.probeOffset || 0;
      break;
  }
  
  // Spoilboard becomes Z-zero in work coordinates
  const materialThickness = workpieceTop - spoilboardSurface;
  const maxSafeCutDepth = -(config.maxSpoilboardCut || 1.0); // Negative depth into spoilboard
  const recommendedCutDepth = materialThickness + (config.maxSpoilboardCut || 1.0);
  
  return {
    spoilboardZero: 0.0, // Work coordinate Z-zero
    materialThickness, // Positive height above spoilboard
    workpieceTopOffset: materialThickness,
    maxSafeCutDepth,
    recommendedCutDepth
  };
}
```

**Sheet Goods Coordinate System:**
```
┌─────────────────────────────────────────────────────────┐
│             SHEET GOODS COORDINATE SYSTEM               │
├─────────────────────────────────────────────────────────┤
│  Z-Zero Reference: Spoilboard Surface                  │
│                                                         │
│  Coordinate Positions:                                  │
│  🛡️  Spoilboard Surface: Z = 0.000 mm (ZERO)           │
│  📏 Workpiece Top:       Z = +12.8 mm (above zero)     │
│  ⚡ Air/Clearance:       Z = +20.0 mm (above zero)     │
│                                                         │
│  CAM Programming Guide:                                 │
│  🎯 Cut through material: Z = -0.7 mm (into spoilboard)│
│  🔪 Surface operations:   Z = +12.8 to +12.0 mm        │
│  ✈️  Rapid/clearance:     Z = +20.0 mm or higher       │
│                                                         │
│  G-Code Validation:                                     │
│  📊 Program max depth: -0.7 mm ✓ Safe for spoilboard  │
│  📐 Program min height: +12.0 mm ✓ Clears workpiece    │
│                                                         │
│  [Apply Coordinate System] [Export CAM Setup]          │
└─────────────────────────────────────────────────────────┘
```
```

**Error Handling:**
- **Inconsistent Contact**: Guide through improved technique and retry
- **Surface Damage**: Assess damage severity and provide alternatives
- **Deflection Detected**: Recommend workpiece support or alternative methods
- **Measurement Error**: Provide validation procedures and correction options

## 6. Origin Validation and Testing

### 6.1 Setup Verification Procedures
**Purpose**: Confirm origin setup accuracy before job execution

**UI Elements Required:**
- Validation test movement controls
- Position verification display
- Test pattern execution options
- Accuracy assessment results

**Verification Methods:**
1. **Position Verification**
   - Move to key coordinate positions (0,0), (max X, max Y)
   - Verify positions align with expected workpiece features
   - Check clearances and boundary conditions
   - Confirm coordinate system relationships

2. **Boundary Testing**
   - Test movement to G-Code program boundaries
   - Verify all positions are within machine travel
   - Check for collisions with fixtures or clamps
   - Validate safe clearances throughout envelope

3. **Precision Verification**
   - Return to origin position and verify accuracy
   - Test coordinate system consistency
   - Measure key dimensions if possible
   - Compare against expected values

**Test Patterns for Validation:**
- **Corner-to-Corner**: Move between workpiece corners
- **Center Reference**: Move to calculated center position
- **Feature Check**: Move to known feature locations
- **Envelope Test**: Trace workpiece boundary at safe height

### 6.2 Learning System Integration
**Purpose**: Track setup accuracy and improve workflow guidance

**Competency Assessment:**
```typescript
interface OriginSetupCompetency {
  setupAccuracy: number; // Measured deviation from expected
  setupTime: number; // Time to complete setup
  retouchoffRate: number; // Frequency of setup corrections
  validationSuccess: number; // Success rate of validation tests
  methodConsistency: number; // Consistency in method selection
}

interface AdaptiveOriginWorkflow {
  guidanceLevel: 'detailed' | 'standard' | 'minimal';
  validationRequirement: 'comprehensive' | 'standard' | 'basic';
  autoAdvanceSteps: boolean;
  expertShortcuts: boolean;
  precisionAssistance: boolean;
}
```

**Learning Progression:**
- **Beginner → Intermediate**: Reduce validation requirements after 10 successful setups
- **Intermediate → Expert**: Enable shortcuts and batch operations after consistent accuracy
- **Error Response**: Temporarily increase guidance after any significant setup errors
- **Method Optimization**: Suggest optimal methods based on success patterns

## 7. Advanced Origin Setup Features

### 7.1 Multi-Setup Operations
**Purpose**: Handle multiple workpieces or complex fixture setups

**Multi-Workpiece Coordination:**
- Coordinate system assignment for each workpiece
- Batch origin setup procedures
- Validation across multiple setups
- Job coordination with multiple origins

**Fixture Integration:**
- Fixture datum point utilization
- Automatic offset calculation from fixture references
- Fixture-based coordinate system management
- Integration with CAM fixture setups

### 7.2 Precision Enhancement Features
**Purpose**: Achieve higher accuracy for critical applications

**Advanced Touchoff Methods:**
- Edge finding with probe cycles
- Center finding with automatic calculation
- Multi-point averaging for improved accuracy
- Temperature compensation for precision work

**Quality Assurance Integration:**
- Setup documentation and traceability
- Measurement uncertainty calculation
- Validation against CAD dimensions
- Setup repeatability assessment

## 8. Error Recovery and Troubleshooting

### 8.1 Common Setup Issues
**Touchoff Accuracy Problems:**
- Inconsistent edge detection
- Tool deflection during contact
- Surface irregularities affecting accuracy
- Workpiece movement during setup

**Coordinate System Confusion:**
- Wrong coordinate system selection
- Offset application errors
- Mixed coordinate system usage
- Reference point misidentification

**Validation Failures:**
- Position accuracy outside tolerance
- Boundary check failures
- Feature alignment problems
- Repeatability issues

### 8.2 Recovery Procedures
**Systematic Error Resolution:**
1. **Problem Identification**: Clear error description with probable causes
2. **Impact Assessment**: Evaluate effect on job execution
3. **Correction Options**: Multiple resolution paths based on situation
4. **Verification**: Confirm correction effectiveness
5. **Prevention**: Update procedures to prevent recurrence

**Undo and Retry Capabilities:**
- Quick reset to previous coordinate system state
- Partial setup retention during corrections
- Step-by-step undo for complex setups
- Backup/restore for experimental setups

## 9. Integration with Job Execution

### 9.1 Pre-Job Validation
**Final Setup Verification:**
- Complete coordinate system validation
- G-Code program compatibility check
- Workpiece alignment verification
- Safety clearance confirmation

### 9.2 Job Execution Preparation
**Seamless Transition to Machining:**
- Automatic coordinate system activation
- Tool position verification relative to origin
- Final safety checks and confirmations
- Job execution readiness assessment

## 10. Success Metrics and Performance

### 10.1 Setup Accuracy Targets
- **Position Accuracy**: ±0.001" for precision applications
- **Setup Time**: <10 minutes for routine workpiece setups
- **Repeatability**: ±0.0005" for repeated setups
- **Validation Success**: >95% pass rate on first attempt

### 10.2 User Experience Metrics
- **Learning Progression**: Measurable accuracy improvement over time
- **Error Rate**: <3% setup errors requiring job restart
- **User Confidence**: Increased confidence in setup procedures
- **Workflow Efficiency**: Reduced setup time with maintained accuracy

This workpiece origin setup workflow ensures accurate, reliable coordinate system establishment while adapting to user skill levels and maintaining the precision requirements for successful CNC machining operations.