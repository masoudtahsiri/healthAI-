# HealthAI+ Color Palette

## Primary Gradient Colors (Splash Screen & App Icon)

The app uses a 4-color gradient that transitions from deep blue to bright cyan:

### 1. Deep Athletic Blue
- **RGB**: (26, 77, 153)
- **RGB Normalized**: (0.1, 0.3, 0.6)
- **Hex**: `#1A4D99`
- **Usage**: Gradient start, heart icon color

### 2. Vibrant Ocean Blue
- **RGB**: (0, 128, 204)
- **RGB Normalized**: (0.0, 0.5, 0.8)
- **Hex**: `#0080CC`
- **Usage**: Gradient middle

### 3. Bright Cyan/Teal
- **RGB**: (51, 179, 230)
- **RGB Normalized**: (0.2, 0.7, 0.9)
- **Hex**: `#33B3E6`
- **Usage**: Gradient middle-to-end

### 4. Electric Cyan
- **RGB**: (102, 204, 255)
- **RGB Normalized**: (0.4, 0.8, 1.0)
- **Hex**: `#66CCFF`
- **Usage**: Gradient end

## Accent Colors

### White
- **Usage**: Text, icons, UI elements on gradient backgrounds
- **Hex**: `#FFFFFF`
- **RGB**: (255, 255, 255)

### System Colors (Dashboard & UI)

- **Blue**: Used for primary actions, links
- **Green**: Used for positive indicators, improving trends
- **Orange**: Used for warnings, declining trends, activity levels
- **Red**: Used for critical alerts
- **Purple**: Used for specific metrics
- **Gray/Secondary**: Used for secondary text and inactive states

## SwiftUI Color Usage

### In SplashView.swift:
```swift
// Gradient colors
Color(red: 0.1, green: 0.3, blue: 0.6)      // Deep athletic blue
Color(red: 0.0, green: 0.5, blue: 0.8)      // Vibrant ocean blue
Color(red: 0.2, green: 0.7, blue: 0.9)      // Bright cyan/teal
Color(red: 0.4, green: 0.8, blue: 1.0)     // Electric cyan

// UI elements
Color.white                                 // Primary text/icon color
Color.white.opacity(0.9)                     // Secondary text
Color.white.opacity(0.7)                     // Tertiary text
Color.white.opacity(0.1)                     // Background circles
```

### In App Icon:
- **Background**: Same 4-color gradient (radial)
- **Heart Circle**: White (`#FFFFFF`)
- **Heart Icon**: Deep athletic blue (`#1A4D99`)
- **Plus Sign**: White (`#FFFFFF`)

## Color Conversion Reference

| Normalized RGB | RGB (0-255) | Hex Code | Name |
|----------------|-------------|----------|------|
| (0.1, 0.3, 0.6) | (26, 77, 153) | #1A4D99 | Deep Athletic Blue |
| (0.0, 0.5, 0.8) | (0, 128, 204) | #0080CC | Vibrant Ocean Blue |
| (0.2, 0.7, 0.9) | (51, 179, 230) | #33B3E6 | Bright Cyan/Teal |
| (0.4, 0.8, 1.0) | (102, 204, 255) | #66CCFF | Electric Cyan |

## Usage Guidelines

1. **Primary Brand Identity**: The 4-color gradient represents the core brand
2. **Splash Screen**: Uses the full gradient as animated background
3. **App Icon**: Uses radial version of the same gradient
4. **White Elements**: Text and icons on gradient backgrounds should be white for contrast
5. **System Colors**: Use iOS system colors for UI elements in dashboard/views for consistency with iOS design language

