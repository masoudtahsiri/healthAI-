import SwiftUI

enum DateRangeType: String, CaseIterable {
    case daily = "Today"
    case weekly = "This Week"
    case monthly = "This Month"
    case sixMonths = "6 Months"
    case yearly = "This Year"
    
    var icon: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar"
        case .monthly: return "calendar.badge.clock"
        case .sixMonths: return "calendar.circle"
        case .yearly: return "calendar.badge.exclamationmark"
        }
    }
    
    var color: Color {
        switch self {
        case .daily: return .orange
        case .weekly: return .blue
        case .monthly: return .purple
        case .sixMonths: return .indigo
        case .yearly: return .green
        }
    }
    
    // Short label for compact display (like Apple Health app)
    var shortLabel: String {
        switch self {
        case .daily: return "D"
        case .weekly: return "W"
        case .monthly: return "M"
        case .sixMonths: return "6M"
        case .yearly: return "Y"
        }
    }
}

struct DateRangePicker: View {
    @Binding var selectedRange: DateRangeType
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    private var adaptiveSpacing: CGFloat {
        horizontalSizeClass == .regular ? 12 : 8
    }
    
    private var adaptiveFontSize: CGFloat {
        horizontalSizeClass == .regular ? 16 : 14
    }
    
    private var adaptivePadding: CGFloat {
        horizontalSizeClass == .regular ? 12 : 10
    }
    
    private var adaptiveCornerRadius: CGFloat {
        horizontalSizeClass == .regular ? 12 : 10
    }
    
    private var adaptiveHorizontalPadding: CGFloat {
        horizontalSizeClass == .regular ? 24 : 16
    }
    
    var body: some View {
        HStack(spacing: adaptiveSpacing) {
            ForEach([DateRangeType.daily, .weekly, .monthly, .sixMonths, .yearly], id: \.self) { range in
                Button(action: {
                    selectedRange = range
                }) {
                    Text(range.shortLabel)
                        .font(.system(size: adaptiveFontSize, weight: .semibold))
                        .foregroundColor(selectedRange == range ? .white : .primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, adaptivePadding)
                        .background(
                            RoundedRectangle(cornerRadius: adaptiveCornerRadius)
                                .fill(selectedRange == range ? 
                                    AnyShapeStyle(range.color) : 
                                    AnyShapeStyle(.ultraThinMaterial)) // Use material for unselected
                        )
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Date Range Utilities

class DateRangeCalculator {
    static func getDates(for range: DateRangeType) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let today = Date()
        
        switch range {
        case .daily:
            // Today's data
            let start = calendar.startOfDay(for: today)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
            
        case .weekly:
            // Current calendar week (Sunday to Saturday)
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!
            let end = calendar.date(byAdding: .day, value: 1, to: today)!
            return (startOfWeek, end)
            
        case .monthly:
            // Current calendar month
            let components = calendar.dateComponents([.year, .month], from: today)
            let start = calendar.date(from: components)!
            let end = calendar.date(byAdding: .day, value: 1, to: today)!
            return (start, end)
            
        case .sixMonths:
            // Last 6 calendar months
            let monthComponents = calendar.dateComponents([.year, .month], from: today)
            let startOfCurrentMonth = calendar.date(from: monthComponents)!
            let start = calendar.date(byAdding: .month, value: -5, to: startOfCurrentMonth)!
            let end = calendar.date(byAdding: .day, value: 1, to: today)!
            return (start, end)
            
        case .yearly:
            // Current calendar year
            let year = calendar.component(.year, from: today)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            let end = calendar.date(byAdding: .day, value: 1, to: today)!
            return (start, end)
        }
    }
    
    static func getDayCount(for range: DateRangeType) -> Int {
        let dates = getDates(for: range)
        let days = Calendar.current.dateComponents([.day], from: dates.start, to: dates.end).day ?? 0
        return max(1, days)
    }
}


