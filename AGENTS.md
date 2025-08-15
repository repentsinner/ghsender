# ghSender - CNC Machine Control Application

## Project Overview
Flutter-based CNC machine controller application with high-performance graphics rendering and real-time machine communication. Originally started as a graphics performance spike comparing flutter_gpu and flutter_scene rendering, evolved into a full CNC control application with grblHAL firmware support.

## Development Notes

- Note that we don't want a web build as we can't use websockets from Chrome due to cross-site scripting issues. Please only focus on a macOS build/implementation for now
- Rather than downgrading dependencies when running into build issues, please attempt to upgrade other dependencies (e.g., run flutter pub upgrade or flutter upgrade as necessary)
- Don't rely on .backup files for file recovery; use git to handle version control and file recovery instead
- We never want to install CocoaPods globally. it should only be installed within the project. we never want to install _any_ tooling outside of the project root directory
- When faced with a toolchain error, do not try to go around the tooling we're trying to use. fix the tooling first
- do not use system tools. only use tools within the project root

## Context Management Protocol

  Before ANY significant action, ALWAYS follow this sequence:

  1. **Check**: "Do I have enough context about [this task/codebase/decisions]?"
  2. **Read**: If uncertain, use Read/Grep/Glob to check relevant docs, code, or git history
  3. **State**: "Based on [sources], my understanding is [X]. Proceeding to [action] because [reasoning]"
  4. **Ask**: If still uncertain, ask user for clarification rather than guessing

  Key triggers for context-checking:
  - Making code changes
  - Architectural decisions
  - Tool/dependency choices
  - File creation/modification
  - Multi-step task planning

  Default: Over-research rather than under-research. Say "Let me check the docs first" frequently.
- please only use the build and run tools provided by the devops agent in the @tools directory. please do not directly run tools from the toolchain directory. if you need a tool, please consult the devops agent and have it modify @tools/build.sh for you
- always use lib/utils/logger.dart to log diagnostics output. never use print
- avoid magic numbers in the codebase where possible. create intelligently named variables if needed. prefer library enums or constants

## Graphics Rendering & Performance

### Critical Requirements (MUST REMEMBER)
1. **NO Canvas Drawing in GPU Renderer**: flutter_gpu must use actual GPU APIs, not Canvas shortcuts
2. **flutter_gpu API is Complete**: flutter_scene is built on flutter_gpu, proving the API works
3. **Shaders are Required**: Conceptual GPU rendering without shaders provides no performance benefit
4. **True Batching**: Must render all 120,000 triangles in 1 draw call, not 10,000 shortcuts

### Current Implementation Status
✅ **flutter_gpu_shaders setup complete**: Dependencies resolved, build hook created
✅ **Shader files created**: vertex, fragment, and wireframe shaders written
✅ **API fixes applied**: Corrected flutter_gpu method signatures

### Flutter GPU API Corrections Made
- ✅ Shader access: `gpu.ShaderLibrary.fromAsset()` instead of `gpu.shaderLibrary`
- ✅ Buffer management: `HostBuffer.emplace()` instead of `DeviceBuffer`
- ✅ Drawing: `bindIndexBuffer()` + `drawIndexed(count)` instead of `drawIndexed(buffer, count)`
- ✅ Uniforms: `getUniformSlot()` for shader binding
- ✅ Pipeline creation: Simple `createRenderPipeline(vertex, fragment)` call

### Shader Development Workflow
- **IMPORTANT**: Shader changes require `flutter clean` before `flutter run` to force recompilation
- Flutter does not automatically detect shader source file changes
- Always run `flutter clean && flutter run` after editing .vert/.frag files

## File Structure
```
lib/
├── main.dart                         # App entry and window configuration
├── bloc/                            # BLoC state management
│   ├── communication/               # CNC communication management
│   ├── file_manager/               # G-code file handling
│   ├── machine_controller/         # Real-time machine state
│   ├── problems/                   # System problem tracking
│   └── profile/                    # Machine profile management
├── gcode/                          # G-code parsing and processing
├── models/                         # Data models
├── renderers/                      # Graphics rendering engines
├── scene/                          # 3D scene management
└── ui/                             # User interface components
    ├── layouts/                    # VSCode-inspired layout
    ├── screens/                    # Main application screens
    └── widgets/                    # Reusable UI components

shaders/
├── line_vertex.vert               # Line rendering vertex shader
└── line_fragment.frag             # Line rendering fragment shader

shaders/ghsender.shaderbundle.json             # Shader compilation config
hook/build.dart                              # Native assets build hook
```

## Performance Testing Instructions
1. Run app with `./tools/build.sh build-single . macos`
2. Use graphics controls to adjust line rendering parameters
3. Observe FPS performance with large G-code files
4. Test real-time machine communication at 60Hz

## Critical Test Management Rules
- **NEVER DELETE UNIT TESTS**: Unit tests are sacred and must never be removed
- **ALWAYS COMMIT TESTS**: When you create tests, immediately commit them to git
- **TEST-DRIVEN DEVELOPMENT**: Write tests first, then implementation
- **VERIFY TESTS EXIST**: Before marking any task complete, verify all tests are committed
- **NO EXCEPTIONS**: There is never a valid reason to delete working unit tests

## Important Technical Notes
- flutter_gpu API is NOT incomplete - it's fully functional
- flutter_scene proves flutter_gpu works (it's built on top of it)
- Sample code exists in flutter_gpu showing proper usage patterns
- Must use actual GPU shaders for meaningful performance comparison
- All BLoC state management designed for 60Hz real-time machine control
- state management is accomplished via BLoC in this project
- reference https://github.com/grblHAL/core/wiki/For-sender-developers to understand how best to interact with grblHAL
- "Don't convert a value to a different representation and immediately convert it back to the 
  original representation - this only degrades precision and adds unnecessary computation."