import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let brandPrimary = Color(hex: "BB4A00")
    static let brandSecondary = Color(hex: "FE8019")
    
    // MARK: - Warning Colors
    static let warningPrimary = Color(hex: "D79921")
    static let warningSecondary = Color(hex: "FABD2F")
    
    // MARK: - Success Colors
    static let successPrimary = Color(hex: "98971A")
    static let successSecondary = Color(hex: "BDBB26")
    
    // MARK: - Error Colors
    static let errorPrimary = Color(hex: "CC241D")
    static let errorSecondary = Color(hex: "FB4934")
    
    // MARK: - Border Colors
    static let borderHard = Color(hex: "333333")
    static let borderSoft = Color(hex: "777777")
    
    // MARK: - Background Colors
    static let backgroundHard = Color(hex: "1E1E1E")
    static let backgroundMedium = Color(hex: "232323")
    static let backgroundSoft = Color(hex: "2C2C2C")
    static let backgroundAppBody = Color(hex: "1E1E1E").opacity(0.95)
    static let backgroundSidebarTopbar = Color(hex: "1E1E1E").opacity(0.90)
    
    // MARK: - Text Colors
    static let text0 = Color(hex: "FFFFFF") // Brightest
    static let text1 = Color(hex: "EEEEEE")
    static let text2 = Color(hex: "CCCCCC")
    static let text3 = Color(hex: "AAAAAA")
    static let text4 = Color(hex: "777777") // Darkest
    
    // MARK: - Hex Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

}

// MARK: - Alternative organized approach with nested structs
extension Color {
    struct Brand {
        static let primary = Color(hex: "BB4A00")
        static let secondary = Color(hex: "FE8019")
    }
    
    struct Warning {
        static let primary = Color(hex: "D79921")
        static let secondary = Color(hex: "FABD2F")
    }
    
    struct Success {
        static let primary = Color(hex: "98971A")
        static let secondary = Color(hex: "BDBB26")
    }
    
    struct Error {
        static let primary = Color(hex: "CC241D")
        static let secondary = Color(hex: "FB4934")
    }
    
    struct Border {
        static let hard = Color(hex: "333333")
        static let soft = Color(hex: "777777")
    }
    
    struct Background {
        static let hard = Color(hex: "1E1E1E")
        static let medium = Color(hex: "232323")
        static let soft = Color(hex: "2C2C2C")
        static let appBody = Color(hex: "1E1E1E").opacity(0.95)
        static let sidebarTopbar = Color(hex: "1E1E1E").opacity(0.90)
    }
    
    struct Text {
        static let level0 = Color(hex: "FFFFFF") // Brightest
        static let level1 = Color(hex: "EEEEEE")
        static let level2 = Color(hex: "CCCCCC")
        static let level3 = Color(hex: "AAAAAA")
        static let level4 = Color(hex: "777777") // Darkest
    }
}

