#!/usr/bin/env python3
"""
Generate App Icon for HealthAI iOS/iPadOS App
Creates all required icon sizes following Apple's guidelines
"""

from PIL import Image, ImageDraw, ImageFont
import os
import math

# Icon sizes required for iOS/iPadOS
ICON_SIZES = {
    # iPhone - App Icon
    "iphone-60pt@2x": 120,
    "iphone-60pt@3x": 180,
    
    # iPhone - Settings
    "iphone-29pt@2x": 58,
    "iphone-29pt@3x": 87,
    
    # iPhone - Spotlight
    "iphone-40pt@2x": 80,
    "iphone-40pt@3x": 120,
    
    # iPhone - Notification
    "iphone-20pt@2x": 40,
    "iphone-20pt@3x": 60,
    
    # iPad - App Icon
    "ipad-76pt@1x": 76,
    "ipad-76pt@2x": 152,
    "ipad-83.5pt@2x": 167,
    
    # iPad - Settings
    "ipad-29pt@1x": 29,
    "ipad-29pt@2x": 58,
    
    # iPad - Spotlight
    "ipad-40pt@1x": 40,
    "ipad-40pt@2x": 80,
    
    # iPad - Notification
    "ipad-20pt@1x": 20,
    "ipad-20pt@2x": 40,
    
    # App Store
    "ios-marketing-1024pt@1x": 1024,
}

def draw_heart(draw, center_x, center_y, size, fill_color):
    """Draw a heart shape - better approximation"""
    # Heart parameters
    heart_width = size * 0.65
    heart_height = size * 0.6
    
    # Heart is centered on the point
    x, y = center_x, center_y
    
    # Create heart shape using two circles and a triangle
    # Left circle - positioned higher and to the left
    left_circle_x = x - heart_width * 0.22
    left_circle_y = y - heart_height * 0.15
    left_radius = heart_width * 0.26
    
    # Right circle - positioned higher and to the right
    right_circle_x = x + heart_width * 0.22
    right_circle_y = y - heart_height * 0.15
    right_radius = heart_width * 0.26
    
    # Draw circles
    left_bbox = [int(left_circle_x - left_radius), int(left_circle_y - left_radius),
                 int(left_circle_x + left_radius), int(left_circle_y + left_radius)]
    right_bbox = [int(right_circle_x - right_radius), int(right_circle_y - right_radius),
                  int(right_circle_x + right_radius), int(right_circle_y + right_radius)]
    
    draw.ellipse(left_bbox, fill=fill_color)
    draw.ellipse(right_bbox, fill=fill_color)
    
    # Draw triangle for bottom point (more acute for better heart shape)
    triangle_points = [
        (int(left_circle_x - left_radius * 0.3), int(left_circle_y + left_radius * 0.4)),
        (int(right_circle_x + right_radius * 0.3), int(right_circle_y + right_radius * 0.4)),
        (int(x), int(y + heart_height * 0.55))
    ]
    draw.polygon(triangle_points, fill=fill_color)

def create_base_icon(size):
    """Create app icon based on splash screen design: heart logo with + sign"""
    width, height = size, size
    center_x, center_y = width // 2, height // 2
    max_radius = int(math.sqrt(center_x**2 + center_y**2))
    
    # Create gradient background matching splash screen
    # Colors from splash: Deep athletic blue -> Vibrant ocean blue -> Bright cyan -> Electric cyan
    # Convert to RGB: 
    # (0.1, 0.3, 0.6) -> (26, 77, 153)
    # (0.0, 0.5, 0.8) -> (0, 128, 204)
    # (0.2, 0.7, 0.9) -> (51, 179, 230)
    # (0.4, 0.8, 1.0) -> (102, 204, 255)
    
    img = Image.new('RGB', (size, size), color='#1A4D99')
    draw = ImageDraw.Draw(img)
    
    # Create radial gradient matching splash screen
    steps = min(60, max_radius // 2)
    for i in range(steps):
        ratio = i / steps
        
        # Interpolate through the 4 gradient colors
        if ratio < 0.33:
            # First to second color
            r = int(26 + (0 - 26) * (ratio / 0.33))
            g = int(77 + (128 - 77) * (ratio / 0.33))
            b = int(153 + (204 - 153) * (ratio / 0.33))
        elif ratio < 0.66:
            # Second to third color
            local_ratio = (ratio - 0.33) / 0.33
            r = int(0 + (51 - 0) * local_ratio)
            g = int(128 + (179 - 128) * local_ratio)
            b = int(204 + (230 - 204) * local_ratio)
        else:
            # Third to fourth color
            local_ratio = (ratio - 0.66) / 0.34
            r = int(51 + (102 - 51) * local_ratio)
            g = int(179 + (204 - 179) * local_ratio)
            b = int(230 + (255 - 230) * local_ratio)
        
        color = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))
        
        # Draw concentric circles for gradient
        radius = int((steps - i) * max_radius / steps)
        if radius > 0:
            bbox = [center_x - radius, center_y - radius, 
                   center_x + radius, center_y + radius]
            draw.ellipse(bbox, fill=color)
    
    # Calculate icon group size (heart + plus sign)
    # Total width should be about 65% of icon size
    total_symbol_width = int(size * 0.65)
    heart_size = int(total_symbol_width * 0.55)  # Heart takes 55% of total width
    plus_size = int(total_symbol_width * 0.35)   # Plus takes 35% of total width
    spacing = int(total_symbol_width * 0.10)     # 10% spacing
    
    # Calculate positions - center the group
    group_start_x = center_x - total_symbol_width // 2
    heart_center_x = group_start_x + heart_size // 2
    plus_center_x = group_start_x + heart_size + spacing + plus_size // 2
    
    # Draw heart inside a circle (heart.circle.fill style)
    circle_radius = int(heart_size * 0.5)
    
    # Draw circle background for heart (white circle like splash screen)
    circle_bbox = [heart_center_x - circle_radius, center_y - circle_radius,
                   heart_center_x + circle_radius, center_y + circle_radius]
    draw.ellipse(circle_bbox, fill='#FFFFFF')
    
    # Draw heart shape inside circle - use gradient blue color for visibility
    heart_draw_size = int(circle_radius * 1.25)
    # Use blue color from gradient for heart (matches splash aesthetic, visible on white)
    # Deep athletic blue from gradient start
    heart_color = (26, 77, 153)  # Deep blue from gradient, visible on white circle
    draw_heart(draw, heart_center_x, center_y, heart_draw_size, 
               fill_color=heart_color)
    
    # Draw plus sign to the right
    plus_thickness = max(3, int(plus_size * 0.25))
    plus_length = int(plus_size * 0.6)
    
    # Vertical bar of plus
    plus_v_x1 = plus_center_x - plus_thickness // 2
    plus_v_y1 = center_y - plus_length // 2
    plus_v_x2 = plus_center_x + plus_thickness // 2
    plus_v_y2 = center_y + plus_length // 2
    draw.rounded_rectangle([plus_v_x1, plus_v_y1, plus_v_x2, plus_v_y2], 
                          radius=plus_thickness//3, fill='#FFFFFF')
    
    # Horizontal bar of plus
    plus_h_x1 = plus_center_x - plus_length // 2
    plus_h_y1 = center_y - plus_thickness // 2
    plus_h_x2 = plus_center_x + plus_length // 2
    plus_h_y2 = center_y + plus_thickness // 2
    draw.rounded_rectangle([plus_h_x1, plus_h_y1, plus_h_x2, plus_h_y2], 
                          radius=plus_thickness//3, fill='#FFFFFF')
    
    return img

def generate_icons():
    """Generate all required icon sizes"""
    output_dir = "HealthAI/Assets.xcassets/AppIcon.appiconset"
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    print("Generating app icons...")
    
    generated_files = []
    
    for icon_name, size in ICON_SIZES.items():
        print(f"Generating {icon_name} ({size}x{size})...")
        icon = create_base_icon(size)
        
        # Determine filename and platform/idiom from icon name
        if "iphone" in icon_name:
            filename = f"icon-{icon_name.replace('iphone-', '')}.png"
        elif "ipad" in icon_name:
            filename = f"icon-{icon_name.replace('ipad-', '')}.png"
        elif "ios-marketing" in icon_name:
            filename = "icon-1024x1024.png"
        else:
            filename = f"icon-{icon_name}.png"
        
        filepath = os.path.join(output_dir, filename)
        icon.save(filepath, 'PNG', optimize=True)
        generated_files.append((icon_name, filename, size))
        print(f"  ✓ Created {filename}")
    
    print(f"\n✓ Generated {len(generated_files)} icon files")
    return generated_files

if __name__ == "__main__":
    try:
        generated_files = generate_icons()
        print("\n✓ App icon generation complete!")
        print("\nNote: Update Contents.json with the generated filenames.")
    except Exception as e:
        print(f"Error generating icons: {e}")
        import traceback
        traceback.print_exc()

