#!/usr/bin/env python3
"""
Generate a complex G-code file with approximately 10,000 operations
for performance testing of 3D rendering
"""
import math
import random

def get_random_spindle_speed():
    """Generate a random spindle speed between 15000 and 24000 RPM"""
    return random.randint(15000, 24000)

def write_header(f):
    f.write("; Complex CNC Router Job - 10K Operations Performance Test\n")
    f.write("; Generated for graphics rendering performance testing\n")
    f.write("; Work Area: 200x200mm\n")
    f.write("; Includes multiple toolchanges and spindle speed variations\n\n")
    f.write("G17 G21 G90 G64 P0.025\n")
    f.write("G0 Z25.000\n")
    f.write("T1 M6  ; Load Tool 1 - 6mm End Mill\n")
    f.write("G0 Z10.000\n\n")

def generate_spiral_pattern(f, center_x, center_y, radius, turns, operations_count):
    """Generate a spiral pattern with many operations"""
    spindle_speed = get_random_spindle_speed()
    f.write(f"; ===== SPIRAL PATTERN - {operations_count} operations =====\n")
    f.write(f"M3 S{spindle_speed}  ; Start spindle at {spindle_speed} RPM\n")
    f.write("G4 P2.0  ; Wait 2 seconds for spindle to reach speed\n")
    
    angle_step = (turns * 2 * math.pi) / operations_count
    radius_step = radius / operations_count
    
    for i in range(operations_count):
        angle = i * angle_step
        r = i * radius_step
        x = center_x + r * math.cos(angle)
        y = center_y + r * math.sin(angle)
        z = -0.5 - (i / operations_count) * 1.5  # Varying depth
        
        if i == 0:
            f.write(f"G0 X{x:.3f} Y{y:.3f}\n")
            f.write(f"G1 Z{z:.3f} F300\n")
        else:
            f.write(f"G1 X{x:.3f} Y{y:.3f} F1000\n")
    
    f.write("G0 Z25.000\n")
    f.write("M5  ; Stop spindle\n\n")

def generate_grid_pattern(f, start_x, start_y, size, count, operations_count):
    """Generate a grid pattern with arcs and lines"""
    spindle_speed = get_random_spindle_speed()
    f.write(f"; ===== GRID PATTERN - {operations_count} operations =====\n")
    f.write(f"M3 S{spindle_speed}  ; Start spindle at {spindle_speed} RPM\n")
    f.write("G4 P2.0  ; Wait 2 seconds for spindle to reach speed\n")
    
    step = size / count
    
    op_count = 0
    for i in range(count):
        for j in range(count):
            if op_count >= operations_count:
                break
            
            x = start_x + i * step
            y = start_y + j * step
            
            # Create small patterns in each grid cell
            if op_count == 0:
                f.write(f"G0 X{x:.3f} Y{y:.3f}\n")
                f.write(f"G1 Z-1.000 F300\n")
            
            # Random pattern type for variety
            pattern_type = op_count % 4
            if pattern_type == 0:
                # Square
                f.write(f"G1 X{x+step/2:.3f} Y{y:.3f} F800\n")
                f.write(f"G1 X{x+step/2:.3f} Y{y+step/2:.3f}\n")
                f.write(f"G1 X{x:.3f} Y{y+step/2:.3f}\n")
                f.write(f"G1 X{x:.3f} Y{y:.3f}\n")
                op_count += 4
            elif pattern_type == 1:
                # Circle with arcs
                radius = step / 4
                cx = x + step/4
                cy = y + step/4
                f.write(f"G0 X{cx+radius:.3f} Y{cy:.3f}\n")
                f.write(f"G2 X{cx:.3f} Y{cy+radius:.3f} I{-radius:.3f} J0.000\n")
                f.write(f"G2 X{cx-radius:.3f} Y{cy:.3f} I0.000 J{-radius:.3f}\n")
                f.write(f"G2 X{cx:.3f} Y{cy-radius:.3f} I{radius:.3f} J0.000\n")
                f.write(f"G2 X{cx+radius:.3f} Y{cy:.3f} I0.000 J{radius:.3f}\n")
                op_count += 4
            elif pattern_type == 2:
                # Triangle
                f.write(f"G1 X{x+step/2:.3f} Y{y+step/2:.3f} F800\n")
                f.write(f"G1 X{x:.3f} Y{y+step/2:.3f}\n")
                f.write(f"G1 X{x:.3f} Y{y:.3f}\n")
                op_count += 3
            else:
                # Wave pattern
                for k in range(8):
                    wave_x = x + (k * step/8)
                    wave_y = y + step/4 + (step/4) * math.sin(k * math.pi / 4)
                    f.write(f"G1 X{wave_x:.3f} Y{wave_y:.3f} F800\n")
                    op_count += 1
            
            if op_count >= operations_count:
                break
    
    f.write("G0 Z25.000\n")
    f.write("M5  ; Stop spindle\n\n")

def generate_text_engraving(f, text, start_x, start_y, char_size, operations_count):
    """Generate text engraving with many small line segments"""
    spindle_speed = get_random_spindle_speed()
    f.write(f"; ===== TEXT ENGRAVING '{text}' - {operations_count} operations =====\n")
    f.write(f"M3 S{spindle_speed}  ; Start spindle at {spindle_speed} RPM\n")
    f.write("G4 P2.0  ; Wait 2 seconds for spindle to reach speed\n")
    
    # Simple character patterns (flipped Y coordinates to read correctly from top)
    char_patterns = {
        'g': [(0.4,0.4), (0.4,0.2), (0.2,0.2), (0,0.4), (0,0.6), (0,0.8), (0.2,1), (0.4,1), (0.4,0.8), (0.4,1.2), (0.2,1.2), (0,1.2)],  # lowercase g with descender
        'h': [(0,1), (0,0), (0,0.5), (0.2,0.5), (0.4,0.5), (0.4,1)],  # lowercase h
        's': [(0.4,0.2), (0.2,0.2), (0,0.4), (0,0.5), (0.2,0.6), (0.4,0.6), (0.4,0.8), (0.2,1), (0,1)],  # lowercase s
        'e': [(0,0.6), (0.4,0.6), (0.4,0.4), (0.2,0.2), (0,0.4), (0,0.8), (0.2,1), (0.4,1)],  # lowercase e
        'n': [(0,1), (0,0.2), (0,0.5), (0.2,0.2), (0.4,0.2), (0.4,1)],  # lowercase n
        'd': [(0.4,1), (0.4,0), (0.4,0.2), (0.2,0.2), (0,0.4), (0,0.8), (0.2,1), (0.4,1)],  # lowercase d
        'r': [(0,1), (0,0.2), (0,0.5), (0.2,0.2), (0.4,0.4)]  # lowercase r
    }
    
    op_count = 0
    char_x = start_x
    
    for char in text:
        if char in char_patterns and op_count < operations_count:
            pattern = char_patterns[char]
            first_point = True
            
            for point in pattern:
                x = char_x + point[0] * char_size
                y = start_y + point[1] * char_size
                
                if first_point:
                    f.write(f"G0 X{x:.3f} Y{y:.3f}\n")
                    f.write(f"G1 Z-0.3 F200\n")
                    first_point = False
                else:
                    f.write(f"G1 X{x:.3f} Y{y:.3f} F400\n")
                
                op_count += 1
                if op_count >= operations_count:
                    break
            
            f.write("G0 Z2.000\n")
            char_x += char_size * 1.2
    
    f.write("G0 Z25.000\n")
    f.write("M5  ; Stop spindle\n\n")

def generate_fractal_pattern(f, x, y, size, depth, operations_count):
    """Generate a fractal-like pattern with recursive structure"""
    spindle_speed = get_random_spindle_speed()
    f.write(f"; ===== FRACTAL PATTERN - {operations_count} operations =====\n")
    f.write(f"M3 S{spindle_speed}  ; Start spindle at {spindle_speed} RPM\n")
    f.write("G4 P2.0  ; Wait 2 seconds for spindle to reach speed\n")
    
    def koch_snowflake_segment(start_x, start_y, end_x, end_y, iteration, max_iter):
        if iteration >= max_iter:
            f.write(f"G1 X{end_x:.3f} Y{end_y:.3f} F600\n")
            return 1
        
        # Divide line into thirds
        dx = (end_x - start_x) / 3
        dy = (end_y - start_y) / 3
        
        x1 = start_x + dx
        y1 = start_y + dy
        x2 = start_x + 2*dx  
        y2 = start_y + 2*dy
        
        # Calculate peak of triangle
        peak_x = x1 + dx/2 - dy * math.sqrt(3)/2
        peak_y = y1 + dy/2 + dx * math.sqrt(3)/2
        
        ops = 0
        ops += koch_snowflake_segment(start_x, start_y, x1, y1, iteration+1, max_iter)
        ops += koch_snowflake_segment(x1, y1, peak_x, peak_y, iteration+1, max_iter)
        ops += koch_snowflake_segment(peak_x, peak_y, x2, y2, iteration+1, max_iter)
        ops += koch_snowflake_segment(x2, y2, end_x, end_y, iteration+1, max_iter)
        return ops
    
    # Start fractal pattern
    f.write(f"G0 X{x:.3f} Y{y:.3f}\n")
    f.write(f"G1 Z-1.0 F300\n")
    
    # Create multiple fractal segments
    total_ops = 0
    segments = 6
    for i in range(segments):
        if total_ops >= operations_count:
            break
        angle = (2 * math.pi * i) / segments
        end_x = x + size * math.cos(angle)
        end_y = y + size * math.sin(angle)
        
        remaining_ops = operations_count - total_ops
        max_depth = min(depth, int(math.log2(remaining_ops)) if remaining_ops > 1 else 1)
        
        ops = koch_snowflake_segment(x, y, end_x, end_y, 0, max_depth)
        total_ops += ops
    
    f.write("G0 Z25.000\n")
    f.write("M5  ; Stop spindle\n\n")

def add_tool_change(f, tool_number, tool_description):
    """Add a tool change sequence"""
    f.write(f"; ===== TOOL CHANGE TO T{tool_number} =====\n")
    f.write("G0 Z25.000  ; Raise to safe height\n")
    f.write("G0 X0 Y0  ; Move to tool change position\n")
    f.write("M5  ; Stop spindle\n")
    f.write("G4 P3.0  ; Wait for spindle to stop\n")
    f.write(f"T{tool_number} M6  ; Change to Tool {tool_number} - {tool_description}\n")
    f.write("G4 P5.0  ; Tool change delay\n\n")

def main():
    filename = "/Users/ritchie/development/ghsender/spike/graphics_performance_spike/assets/complex_10k.nc"
    
    with open(filename, 'w') as f:
        write_header(f)
        
        # Generate different patterns with toolchanges between them
        generate_spiral_pattern(f, 50, 50, 40, 20, 2000)
        
        add_tool_change(f, 2, "3mm Ball End Mill")
        generate_grid_pattern(f, 10, 10, 80, 20, 3000)
        
        add_tool_change(f, 3, "1/8 V-Bit")  
        generate_spiral_pattern(f, 150, 50, 30, 15, 1500)
        
        add_tool_change(f, 4, "0.5mm Engraving Bit")
        generate_text_engraving(f, "ghsender", 20, 120, 10, 1000)
        
        add_tool_change(f, 5, "2mm End Mill")
        generate_fractal_pattern(f, 150, 150, 25, 4, 1500)
        
        add_tool_change(f, 6, "4mm Compression Bit")
        generate_grid_pattern(f, 120, 10, 60, 15, 1000)
        
        # Add finishing operations
        f.write("; ===== FINISHING =====\n")
        f.write("G0 Z25.000\n")
        f.write("G0 X0 Y0  ; Return to home\n")
        f.write("M5  ; Stop spindle\n")
        f.write("M30  ; End program\n")
    
    print(f"Generated G-code file: {filename}")
    
    # Count operations and toolchanges
    with open(filename, 'r') as f:
        lines = f.readlines()
        g_lines = [line for line in lines if line.strip().startswith('G') and any(cmd in line for cmd in ['G0', 'G1', 'G2', 'G3'])]
        m_lines = [line for line in lines if 'M6' in line or 'M3' in line or 'M5' in line]
        tool_changes = [line for line in lines if 'M6' in line]
        spindle_commands = [line for line in lines if 'M3 S' in line]
        
        print(f"Total G-code operations: {len(g_lines)}")
        print(f"Total tool changes: {len(tool_changes)}")
        print(f"Total spindle start commands: {len(spindle_commands)}")
        print(f"Spindle speed range: 15000-24000 RPM")

if __name__ == "__main__":
    main()