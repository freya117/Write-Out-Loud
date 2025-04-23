// File: Models/StrokeType.swift
import Foundation

/**
 Defines the basic types of strokes used in Chinese characters.
 Includes the pinyin name for vocalization and an English description.
 The rawValue (String) is used for Codable conformance and JSON representation.
 */
enum StrokeType: String, Codable, CaseIterable, Hashable {
    // Basic stroke types - use descriptive rawValues for JSON clarity
    case heng = "horizontal"       // 横 (héng) - horizontal
    case shu = "vertical"          // 竖 (shù) - vertical
    case pie = "downward_left"     // 撇 (piě) - downward left sweep
    case na = "downward_right"     // 捺 (nà) - downward right press
    case dian = "dot"              // 点 (diǎn) - dot
    case ti = "upward"             // 提 (tí) - upward flick (often from heng)

    // Common compound/modifier types (can be expanded)
    case zhe = "turning"           // 折 (zhé) - turning (often combined, e.g., héngzhé)
    case gou = "hook"              // 钩 (gōu) - hook (often combined, e.g., shùgōu)
    // Consider adding more complex combinations if needed by analysis/display, e.g.:
    // case wan = "bend"           //弯 (wān) - bend (e.g., shùwān)
    // case xie = "slanting"       // 斜 (xié) - slanting hook (e.g., xiégōu)

    // case unknown = "unknown" // Optional: For strokes not easily categorized

    /// The Pinyin pronunciation name, often used for vocalization feedback.
    /// NOTE: This might differ from the `name` property in the `Stroke` struct,
    /// which holds the *specific* name to be spoken (e.g., "shùgōu" vs. base "gōu").
    var basePinyinName: String {
        switch self {
        case .heng: return "héng"
        case .shu: return "shù"
        case .pie: return "piě"
        case .na: return "nà"
        case .dian: return "diǎn"
        case .ti: return "tí"
        case .gou: return "gōu" // Base name
        case .zhe: return "zhé" // Base name
        // case .wan: return "wān"
        // case .xie: return "xié"
        // case .unknown: return "?"
        }
    }

    /// An English description of the basic stroke type.
    var description: String {
        switch self {
        case .heng: return "Horizontal"
        case .shu: return "Vertical"
        case .pie: return "Downward Left"
        case .na: return "Downward Right"
        case .dian: return "Dot"
        case .ti: return "Upward Flick"
        case .gou: return "Hook (Modifier)"
        case .zhe: return "Turning (Modifier)"
        // case .wan: return "Bend"
        // case .xie: return "Slanting Hook"
        // case .unknown: return "Unknown"
        }
    }
}
