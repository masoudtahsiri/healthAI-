#!/usr/bin/env python3
"""
Create app icons from provided image
Resizes the source image to all required iOS/iPadOS icon sizes
"""

from PIL import Image
import os

# Source image
SOURCE_IMAGE = "/Users/masoudtahsiri/health/6.png"

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

def create_icons_from_image():
    """Resize source image to all required icon sizes"""
    
    # Load source image
    if not os.path.exists(SOURCE_IMAGE):
        print(f"Error: Source image '{SOURCE_IMAGE}' not found!")
        return False
    
    try:
        source_img = Image.open(SOURCE_IMAGE)
        print(f"Loaded source image: {source_img.size}, {source_img.mode}")
        
        # Convert to RGB if needed (remove alpha channel for app icons)
        if source_img.mode != 'RGB':
            print(f"Converting from {source_img.mode} to RGB...")
            # Create white background for images with transparency
            if source_img.mode in ('RGBA', 'LA'):
                background = Image.new('RGB', source_img.size, (255, 255, 255))
                if source_img.mode == 'RGBA':
                    background.paste(source_img, mask=source_img.split()[3])  # Use alpha channel as mask
                else:
                    background.paste(source_img)
                source_img = background
            else:
                source_img = source_img.convert('RGB')
        
        output_dir = "/Users/masoudtahsiri/health/HealthAI/Assets.xcassets/AppIcon.appiconset"
        os.makedirs(output_dir, exist_ok=True)
        
        print(f"\nGenerating app icons from source image...")
        print(f"Output directory: {output_dir}\n")
        
        generated_files = []
        
        for icon_name, size in ICON_SIZES.items():
            print(f"Generating {icon_name} ({size}x{size})...", end=" ")
            
            # Resize image with high-quality resampling
            resized = source_img.resize((size, size), Image.Resampling.LANCZOS)
            
            # Determine filename
            if "iphone" in icon_name:
                filename = f"icon-{icon_name.replace('iphone-', '')}.png"
            elif "ipad" in icon_name:
                filename = f"icon-{icon_name.replace('ipad-', '')}.png"
            elif "ios-marketing" in icon_name:
                filename = "icon-1024x1024.png"
            else:
                filename = f"icon-{icon_name}.png"
            
            filepath = os.path.join(output_dir, filename)
            resized.save(filepath, 'PNG', optimize=True)
            generated_files.append((icon_name, filename, size))
            print(f"✓ Created {filename}")
        
        print(f"\n✓ Generated {len(generated_files)} icon files successfully!")
        return True
        
    except Exception as e:
        print(f"Error processing image: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = create_icons_from_image()
    if success:
        print("\n✓ App icon generation complete!")
        print("\nNext steps:")
        print("1. Clean build folder in Xcode (Shift+Cmd+K)")
        print("2. Build the project (Cmd+B)")
        print("3. Run the app to see the new icons")
    else:
        print("\n✗ Failed to generate icons. Please check the error above.")

