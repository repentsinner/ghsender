#!/usr/bin/env python3
"""
Generate a complex G-code file with a parameterized work envelope
and modal feed rates for performance testing of 3D rendering.
"""
import math
import random
import argparse
import os

class GCodeGenerator:
    """
    Generates and scales a G-code program to fit a specified work envelope.
    """
    def __init__(self, work_envelope):
        self.work_envelope = work_envelope
        self.commands = []

    def add_command(self, cmd, **kwargs):
        kwargs['cmd'] = cmd
        self.commands.append(kwargs)

    def add_comment(self, text):
        self.add_command('comment', text=text)

    def add_raw(self, gcode):
        self.add_command('raw', gcode=gcode)

    def add_g0(self, x=None, y=None, z=None):
        self.add_command('G0', x=x, y=y, z=z)

    def add_g1(self, x=None, y=None, z=None, f=None):
        self.add_command('G1', x=x, y=y, z=z, f=f)

    def add_g2(self, x=None, y=None, i=None, j=None, f=None):
        self.add_command('G2', x=x, y=y, i=i, j=j, f=f)

    def add_m3(self, s):
        self.add_command('M3', s=s)

    def add_m5(self):
        self.add_command('M5')

    def add_m6(self, t, comment):
        self.add_command('M6', t=t, comment=comment)

    def add_dwell(self, p):
        self.add_command('G4', p=p)

    def generate_and_write(self, filename):
        # Find bounds of all coordinates in the program
        coords = [cmd for cmd in self.commands if any(k in cmd for k in ['x', 'y', 'z'])]
        if not coords:
            self._write_file(filename, self.commands)
            print("No coordinates found to scale. Wrote unscaled G-code.")
            return

        min_x = min((c['x'] for c in coords if c.get('x') is not None), default=0)
        max_x = max((c['x'] for c in coords if c.get('x') is not None), default=0)
        min_y = min((c['y'] for c in coords if c.get('y') is not None), default=0)
        max_y = max((c['y'] for c in coords if c.get('y') is not None), default=0)
        min_z = min((c['z'] for c in coords if c.get('z') is not None), default=0)
        max_z = max((c['z'] for c in coords if c.get('z') is not None), default=0)

        original_width = max_x - min_x
        original_depth = max_y - min_y
        original_height = max_z - min_z

        # Calculate scale factor to maintain aspect ratio
        scale_x = self.work_envelope['width'] / original_width if original_width > 1e-6 else float('inf')
        scale_y = self.work_envelope['depth'] / original_depth if original_depth > 1e-6 else float('inf')
        scale_z = self.work_envelope['height'] / original_height if original_height > 1e-6 else float('inf')
        scale_factor = min(s for s in [scale_x, scale_y, scale_z] if s > 0)

        # Transform all coordinates
        transformed_commands = []
        for cmd in self.commands:
            new_cmd = cmd.copy()
            if 'x' in new_cmd and cmd['x'] is not None: new_cmd['x'] = (cmd['x'] - min_x) * scale_factor
            if 'y' in new_cmd and cmd['y'] is not None: new_cmd['y'] = (cmd['y'] - min_y) * scale_factor
            if 'z' in new_cmd and cmd['z'] is not None: new_cmd['z'] = (cmd['z'] - min_z) * scale_factor
            if 'i' in new_cmd and cmd['i'] is not None: new_cmd['i'] *= scale_factor
            if 'j' in new_cmd and cmd['j'] is not None: new_cmd['j'] *= scale_factor
            transformed_commands.append(new_cmd)

        self._write_file(filename, transformed_commands)

    def _write_file(self, filename, commands):
        """Writes the command list to a file with modal feed rates."""
        with open(filename, 'w') as f:
            current_feed_rate = None
            for cmd_data in commands:
                cmd = cmd_data['cmd']
                line_parts = []

                if cmd == 'comment':
                    f.write(f"; {cmd_data['text']}\n")
                    continue
                elif cmd == 'raw':
                    f.write(f"{cmd_data['gcode']}\n")
                    continue

                line_parts.append(cmd)

                if 't' in cmd_data: line_parts.append(f"T{cmd_data['t']}")
                if 's' in cmd_data: line_parts.append(f"S{cmd_data['s']}")
                if 'p' in cmd_data: line_parts.append(f"P{cmd_data['p']:.1f}")

                if 'x' in cmd_data and cmd_data['x'] is not None: line_parts.append(f"X{cmd_data['x']:.3f}")
                if 'y' in cmd_data and cmd_data['y'] is not None: line_parts.append(f"Y{cmd_data['y']:.3f}")
                if 'z' in cmd_data and cmd_data['z'] is not None: line_parts.append(f"Z{cmd_data['z']:.3f}")
                if 'i' in cmd_data and cmd_data['i'] is not None: line_parts.append(f"I{cmd_data['i']:.3f}")
                if 'j' in cmd_data and cmd_data['j'] is not None: line_parts.append(f"J{cmd_data['j']:.3f}")

                if 'f' in cmd_data and cmd_data['f'] is not None:
                    feed = cmd_data['f']
                    if current_feed_rate != feed:
                        line_parts.append(f"F{feed}")
                        current_feed_rate = feed

                line = " ".join(line_parts)
                if 'comment' in cmd_data and cmd_data['comment']:
                    line += f"  ; {cmd_data['comment']}"

                f.write(line + "\n")


def get_random_spindle_speed():
    """Generate a random spindle speed between 15000 and 24000 RPM"""
    return random.randint(15000, 24000)

def write_header(g):
    g.add_comment("Complex CNC Router Job - 10K Operations Performance Test")
    g.add_comment("Generated for graphics rendering performance testing")
    g.add_comment(f"Scaled to Work Area: {g.work_envelope['width']}x{g.work_envelope['depth']}x{g.work_envelope['height']}mm")
    g.add_comment("Includes multiple toolchanges and spindle speed variations")
    g.add_raw("G17 G21 G90 G64 P0.025")
    g.add_g0(z=25.000)
    g.add_m6(t=1, comment="Load Tool 1 - 6mm End Mill")
    g.add_g0(z=10.000)
    g.add_raw("")

def generate_spiral_pattern(g, center_x, center_y, radius, turns, operations_count):
    """Generate a spiral pattern with many operations"""
    spindle_speed = get_random_spindle_speed()
    g.add_comment(f"===== SPIRAL PATTERN - {operations_count} operations =====")
    g.add_m3(s=spindle_speed)
    g.add_dwell(p=2.0)
    
    angle_step = (turns * 2 * math.pi) / operations_count
    radius_step = radius / operations_count
    
    for i in range(operations_count):
        angle = i * angle_step
        r = i * radius_step
        x = center_x + r * math.cos(angle)
        y = center_y + r * math.sin(angle)
        z = -0.5 - (i / operations_count) * 1.5  # Varying depth
        
        if i == 0:
            g.add_g0(x=x, y=y)
            g.add_g1(z=z, f=300)
        else:
            g.add_g1(x=x, y=y, f=1000)
    
    g.add_g0(z=25.000)
    g.add_m5()
    g.add_raw("")

def generate_grid_pattern(g, start_x, start_y, size, count, operations_count):
    """Generate a grid pattern with arcs and lines"""
    spindle_speed = get_random_spindle_speed()
    g.add_comment(f"===== GRID PATTERN - {operations_count} operations =====")
    g.add_m3(s=spindle_speed)
    g.add_dwell(p=2.0)
    
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
                g.add_g0(x=x, y=y)
                g.add_g1(z=-1.000, f=300)
            
            # Random pattern type for variety
            pattern_type = op_count % 4
            if pattern_type == 0:
                # Square
                g.add_g1(x=x+step/2, y=y, f=800)
                g.add_g1(x=x+step/2, y=y+step/2)
                g.add_g1(x=x, y=y+step/2)
                g.add_g1(x=x, y=y)
                op_count += 4
            elif pattern_type == 1:
                # Circle with arcs
                radius = step / 4
                cx = x + step/4
                cy = y + step/4
                g.add_g0(x=cx+radius, y=cy)
                g.add_g2(x=cx, y=cy+radius, i=-radius, j=0.000)
                g.add_g2(x=cx-radius, y=cy, i=0.000, j=-radius)
                g.add_g2(x=cx, y=cy-radius, i=radius, j=0.000)
                g.add_g2(x=cx+radius, y=cy, i=0.000, j=radius)
                op_count += 4
            elif pattern_type == 2:
                # Triangle
                g.add_g1(x=x+step/2, y=y+step/2, f=800)
                g.add_g1(x=x, y=y+step/2)
                g.add_g1(x=x, y=y)
                op_count += 3
            else:
                # Wave pattern
                for k in range(8):
                    wave_x = x + (k * step/8)
                    wave_y = y + step/4 + (step/4) * math.sin(k * math.pi / 4)
                    g.add_g1(x=wave_x, y=wave_y, f=800)
                    op_count += 1
            
            if op_count >= operations_count:
                break
    
    g.add_g0(z=25.000)
    g.add_m5()
    g.add_raw("")

def generate_text_engraving(g, text, start_x, start_y, char_size, operations_count):
    """Generate text engraving with many small line segments"""
    spindle_speed = get_random_spindle_speed()
    g.add_comment(f"===== TEXT ENGRAVING '{text}' - {operations_count} operations =====")
    g.add_m3(s=spindle_speed)
    g.add_dwell(p=2.0)
    
    # Simple character patterns (right-handed coordinate system with Y increasing upward)
    char_patterns = {
        'g': [(0.4,0.6), (0.4,0.8), (0.2,0.8), (0,0.6), (0,0.4), (0,0.2), (0.2,0), (0.4,0), (0.4,0.2), (0.4,-0.2), (0.2,-0.2), (0,-0.2)],  # lowercase g with descender
        'h': [(0,0), (0,1), (0,0.5), (0.2,0.5), (0.4,0.5), (0.4,0)],  # lowercase h
        's': [(0.4,0.8), (0.2,0.8), (0,0.6), (0,0.5), (0.2,0.4), (0.4,0.4), (0.4,0.2), (0.2,0), (0,0)],  # lowercase s
        'e': [(0,0.4), (0.4,0.4), (0.4,0.6), (0.2,0.8), (0,0.6), (0,0.2), (0.2,0), (0.4,0)],  # lowercase e
        'n': [(0,0), (0,0.8), (0,0.5), (0.2,0.8), (0.4,0.8), (0.4,0)],  # lowercase n
        'd': [(0.4,0), (0.4,1), (0.4,0.8), (0.2,0.8), (0,0.6), (0,0.2), (0.2,0), (0.4,0)],  # lowercase d
        'r': [(0,0), (0,0.8), (0,0.5), (0.2,0.8), (0.4,0.6)]  # lowercase r
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
                    g.add_g0(x=x, y=y)
                    g.add_g1(z=-0.3, f=200)
                    first_point = False
                else:
                    g.add_g1(x=x, y=y, f=400)
                
                op_count += 1
                if op_count >= operations_count:
                    break
            
            g.add_g0(z=2.000)
            char_x += char_size * 1.2
    
    g.add_g0(z=25.000)
    g.add_m5()
    g.add_raw("")

def generate_fractal_pattern(g, x, y, size, depth, operations_count):
    """Generate a fractal-like pattern with recursive structure"""
    spindle_speed = get_random_spindle_speed()
    g.add_comment(f"===== FRACTAL PATTERN - {operations_count} operations =====")
    g.add_m3(s=spindle_speed)
    g.add_dwell(p=2.0)
    
    def koch_snowflake_segment(start_x, start_y, end_x, end_y, iteration, max_iter):
        if iteration >= max_iter:
            g.add_g1(x=end_x, y=end_y, f=600)
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
    g.add_g0(x=x, y=y)
    g.add_g1(z=-1.0, f=300)
    
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
    
    g.add_g0(z=25.000)
    g.add_m5()
    g.add_raw("")

def add_tool_change(g, tool_number, tool_description):
    """Add a tool change sequence"""
    g.add_comment(f"===== TOOL CHANGE TO T{tool_number} =====")
    g.add_g0(z=25.000)
    g.add_g0(x=0, y=0)
    g.add_m5()
    g.add_dwell(p=3.0)
    g.add_m6(t=tool_number, comment=f"Change to Tool {tool_number} - {tool_description}")
    g.add_dwell(p=5.0)
    g.add_raw("")

def main():
    parser = argparse.ArgumentParser(
        description="Generate a complex G-code file for performance testing.",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--width', type=float, default=285.0, help='Work envelope width (X-axis) in mm.')
    parser.add_argument('--depth', type=float, default=172.0, help='Work envelope depth (Y-axis) in mm.')
    parser.add_argument('--height', type=float, default=38.0, help='Work envelope height (Z-axis) in mm.')
    args = parser.parse_args()

    work_envelope = {'width': args.width, 'depth': args.depth, 'height': args.height}

    # Get the project root directory (parent of tools/)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    filename = os.path.join(project_root, "assets", "complex_10k.nc")
    
    generator = GCodeGenerator(work_envelope)
    
    write_header(generator)
    
    # Generate different patterns with toolchanges between them
    generate_spiral_pattern(generator, 50, 50, 40, 20, 2000)
    
    add_tool_change(generator, 2, "3mm Ball End Mill")
    generate_grid_pattern(generator, 10, 10, 80, 20, 3000)
    
    add_tool_change(generator, 3, "1/8 V-Bit")
    generate_spiral_pattern(generator, 150, 50, 30, 15, 1500)
    
    add_tool_change(generator, 4, "0.5mm Engraving Bit")
    generate_text_engraving(generator, "ghsender", 20, 120, 10, 1000)
    
    add_tool_change(generator, 5, "2mm End Mill")
    generate_fractal_pattern(generator, 150, 150, 25, 4, 1500)
    
    add_tool_change(generator, 6, "4mm Compression Bit")
    generate_grid_pattern(generator, 120, 10, 60, 15, 1000)
    
    # Add finishing operations
    generator.add_comment("===== FINISHING =====")
    generator.add_g0(z=25.000)
    generator.add_g0(x=0, y=0)
    generator.add_m5()
    generator.add_raw("M30")

    generator.generate_and_write(filename)
    
    print(f"Generated G-code file: {filename}")
    
    # Count operations and toolchanges
    with open(filename, 'r') as f:
        lines = f.readlines()
        g_lines = [line for line in lines if line.strip().startswith(('G0', 'G1', 'G2', 'G3'))]
        m_lines = [line for line in lines if 'M6' in line or 'M3' in line or 'M5' in line]
        tool_changes = [line for line in lines if 'M6' in line]
        spindle_commands = [line for line in lines if 'M3 S' in line]
        
        print(f"Total G-code operations: {len(g_lines)}")
        print(f"Total tool changes: {len(tool_changes)}")
        print(f"Total spindle start commands: {len(spindle_commands)}")
        print(f"Spindle speed range: 15000-24000 RPM")

if __name__ == "__main__":
    main()