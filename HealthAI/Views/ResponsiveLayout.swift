import SwiftUI

// MARK: - Size Class Environment
struct SizeClassEnvironment {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    var isRegularHeight: Bool {
        verticalSizeClass == .regular
    }
}

// MARK: - Device Type Detection (for backward compatibility)
struct DeviceType {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    // Use native size classes for responsive design
    // Regular width typically means iPad (or iPhone in landscape)
    static var isRegularWidth: Bool {
        // This will be used in views that can access @Environment
        // For static properties, we fall back to device type
        isIPad
    }
}

// MARK: - Responsive Layout Modifiers (using native SwiftUI)
extension View {
    // Use native adaptive padding based on size class
    func responsivePadding() -> some View {
        self.padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
    }
    
    // Helper to get adaptive padding values
    private var horizontalPadding: CGFloat {
        // Use @Environment in actual view contexts
        // For extension, provide sensible defaults
        DeviceType.isIPad ? 40 : 16
    }
    
    private var verticalPadding: CGFloat {
        DeviceType.isIPad ? 40 : 16
    }
    
    // Use GeometryReader for true responsive spacing
    func responsiveSpacing() -> some View {
        GeometryReader { geometry in
            self
                .padding(.horizontal, geometry.size.width > 700 ? 40 : 16)
        }
    }
}

// MARK: - Adaptive Values Helper
struct AdaptiveValues {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var padding: CGFloat {
        horizontalSizeClass == .regular ? 40 : 16
    }
    
    var spacing: CGFloat {
        horizontalSizeClass == .regular ? 32 : 20
    }
    
    var cardSpacing: CGFloat {
        horizontalSizeClass == .regular ? 32 : 16
    }
    
    var cornerRadius: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
    
    var shadowRadius: CGFloat {
        horizontalSizeClass == .regular ? 12 : 6
    }
}

// MARK: - Responsive Grid Layout (using native SwiftUI)
struct ResponsiveGrid<Content: View>: View {
    let columns: [GridItem]
    let content: Content
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(columns: [GridItem]? = nil, @ViewBuilder content: () -> Content) {
        if let columns = columns {
            self.columns = columns
        } else {
            // Default to single column - will be overridden in body based on size class
            self.columns = [GridItem(.flexible())]
        }
        self.content = content()
    }
    
    private var adaptiveColumns: [GridItem] {
        horizontalSizeClass == .regular ? [
            GridItem(.flexible(), spacing: 24),
            GridItem(.flexible(), spacing: 24)
        ] : [
            GridItem(.flexible())
        ]
    }
    
    private var adaptiveSpacing: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
    
    var body: some View {
        LazyVGrid(columns: columns.isEmpty ? adaptiveColumns : columns, spacing: adaptiveSpacing) {
            content
        }
    }
}

// MARK: - Responsive Card Style (using native SwiftUI)
struct ModernCard<Content: View>: View {
    let content: Content
    let shadowColor: Color
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(shadowColor: Color = .black.opacity(0.1), @ViewBuilder content: () -> Content) {
        self.shadowColor = shadowColor
        self.content = content()
    }
    
    private var cornerRadius: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
    
    private var shadowRadius: CGFloat {
        horizontalSizeClass == .regular ? 12 : 6
    }
    
    private var shadowY: CGFloat {
        horizontalSizeClass == .regular ? 6 : 2
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.regularMaterial)
                    .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            )
    }
}

// MARK: - Responsive Font Extensions (using native SwiftUI)
extension Font {
    // Use native adaptive fonts that scale automatically
    static func responsiveTitle() -> Font {
        .title
    }
    
    static func responsiveHeadline() -> Font {
        .headline
    }
    
    static func responsiveBody() -> Font {
        .body
    }
    
    static func responsiveCaption() -> Font {
        .caption
    }
    
    // Adaptive font size based on size class
    static func adaptiveSize(_ compactSize: CGFloat, regular: CGFloat? = nil) -> Font {
        // In views, use @Environment(\.horizontalSizeClass)
        // For static method, use device type as fallback
        let size = DeviceType.isIPad ? (regular ?? compactSize * 1.5) : compactSize
        return .system(size: size)
    }
}

// MARK: - Responsive Icon Sizes (using native SwiftUI)
struct ResponsiveIcon: ViewModifier {
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var iconSize: CGFloat {
        horizontalSizeClass == .regular ? 40 : 24
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: iconSize))
    }
}

extension Image {
    func responsiveIcon() -> some View {
        self.modifier(ResponsiveIcon())
    }
}


