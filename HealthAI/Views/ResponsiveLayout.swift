import SwiftUI

// MARK: - Device Type Detection
struct DeviceType {
    static var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    static var isIPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    static var isCompactWidth: Bool {
        #if os(iOS)
        // Use UITraitCollection for modern iOS API
        // For this static property, we'll use a default assumption
        // Individual views can use their trait collection when needed
        true // Default to compact, views will override as needed
        #else
        false
        #endif
    }
}

// MARK: - Responsive Layout Modifiers
extension View {
    func responsivePadding() -> some View {
        self.padding(DeviceType.isIPad ? 32 : 16)
    }
    
    func responsiveSpacing() -> CGFloat {
        DeviceType.isIPad ? 32 : 20
    }
    
    func cardSpacing() -> CGFloat {
        DeviceType.isIPad ? 24 : 16
    }
}

// MARK: - Responsive Grid Layout
struct ResponsiveGrid<Content: View>: View {
    let columns: [GridItem]
    let content: Content
    
    init(columns: [GridItem]? = nil, @ViewBuilder content: () -> Content) {
        if let columns = columns {
            self.columns = columns
        } else {
            self.columns = DeviceType.isIPad ? [
                GridItem(.flexible(), spacing: 24),
                GridItem(.flexible(), spacing: 24)
            ] : [
                GridItem(.flexible())
            ]
        }
        self.content = content()
    }
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: DeviceType.isIPad ? 24 : 16) {
            content
        }
    }
}

// MARK: - Responsive Card Style
struct ModernCard<Content: View>: View {
    let content: Content
    let shadowColor: Color
    
    init(shadowColor: Color = .black.opacity(0.1), @ViewBuilder content: () -> Content) {
        self.shadowColor = shadowColor
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: DeviceType.isIPad ? 20 : 16)
                    .fill(.regularMaterial)
                    .shadow(color: shadowColor, radius: DeviceType.isIPad ? 8 : 6, x: 0, y: DeviceType.isIPad ? 4 : 2)
            )
    }
}

// MARK: - Responsive Font Extensions
extension Font {
    static func responsiveTitle() -> Font {
        DeviceType.isIPad ? .largeTitle : .title
    }
    
    static func responsiveHeadline() -> Font {
        DeviceType.isIPad ? .title2 : .headline
    }
    
    static func responsiveBody() -> Font {
        DeviceType.isIPad ? .title3 : .body
    }
    
    static func responsiveCaption() -> Font {
        DeviceType.isIPad ? .body : .caption
    }
}

// MARK: - Responsive Icon Sizes
struct ResponsiveIcon: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: DeviceType.isIPad ? 32 : 24))
    }
}

extension Image {
    func responsiveIcon() -> some View {
        self.modifier(ResponsiveIcon())
    }
}


