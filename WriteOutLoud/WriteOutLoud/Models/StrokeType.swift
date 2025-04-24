// File: Models/StrokeType.swift
import Foundation

/**
 Defines the basic types of strokes used in Chinese characters.
 Includes the pinyin name for vocalization and an English description.
 The rawValue (String) is used for Codable conformance and JSON representation.
 *** Updated rawValues to match JSON data (e.g., "heng", "shu", "hengzhe") ***
 */
enum StrokeType: String, Codable, CaseIterable, Hashable {
    // Basic stroke types - use rawValues matching the JSON data
    case heng = "heng"              // 横 (héng) - horizontal
    case shu = "shu"                // 竖 (shù) - vertical
    case pie = "pie"                // 撇 (piě) - downward left sweep
    case na = "na"                  // 捺 (nà) - downward right press
    case dian = "dian"              // 点 (diǎn) - dot
    case ti = "ti"                  // 提 (tí) - upward flick (often from heng)

    // Common compound/modifier types (added based on JSON)
    case zhe = "zhe"                // 折 (zhé) - turning (generic modifier)
    case gou = "gou"                // 钩 (gōu) - hook (generic modifier)
    case hengzhe = "hengzhe"        // 横折 (héngzhé) - horizontal turning
    case henggou = "henggou"        // 横钩 (hénggōu) - horizontal hook
    case hengpie = "hengpie"        // 横撇 (héngpiē) - horizontal downward-left
    case hengxiegou = "hengxiegou"  // 横斜钩 (héngxiégōu) - horizontal slanted hook
    case hengzhezhe = "hengzhezhe"      // 横折折 (héngzhézhé) - horizontal turning turning
    case hengzheti = "hengzheti"        // 横折提 (héngzhétí) - horizontal turning upward
    case hengzhewan = "hengzhewan"      // 横折弯 (héngzhéwān) - horizontal turning bend
    case hengzhewangou = "hengzhewangou" // 横折弯钩 (héngzhéwāngōu) - horizontal turning bend hook
    case hengzhezhegou = "hengzhezhegou" // 横折折钩 (héngzhézhégōu) - horizontal turning turning hook
    case hengzhezhepie = "hengzhezhepie" // 横折折撇 (héngzhézhépiě) - horizontal turning turning left

    case shuzhe = "shuzhe"          // 竖折 (shùzhé) - vertical turning
    case shuti = "shuti"            // 竖提 (shùtí) - vertical upward
    case shugou = "shugou"          // 竖钩 (shùgōu) - vertical hook
    case shuwan = "shuwan"          // 竖弯 (shùwān) - vertical bend
    case shuwangou = "shuwangou"    // 竖弯钩 (shùwāngōu) - vertical bend hook
    case shuzhezhe = "shuzhezhe"      // 竖折折 (shùzhézhé) - vertical turning turning
    case shuzhezhegou = "shuzhezhegou" // 竖折折钩 (shùzhézhégōu) - vertical turning turning hook

    case piezhe = "piezhe"          // 撇折 (piězhé) - left turning
    case piedian = "piedian"        // 撇点 (piědiǎn) - left dot

    case xiegou = "xiegou"          // 斜钩 (xiégōu) - slanted hook
    case wangou = "wangou"          // 弯钩 (wāngōu) - bend hook

    case unknown = "unknown"        // Optional: For strokes not easily categorized

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
        // Provide reasonable base names for compound strokes, might need refinement
        case .hengzhe: return "héngzhé"
        case .henggou: return "hénggōu"
        case .hengpie: return "héngpiē"
        case .hengxiegou: return "héngxiégōu"
        case .hengzhezhe: return "héngzhézhé"
        case .hengzheti: return "héngzhétí"
        case .hengzhewan: return "héngzhéwān"
        case .hengzhewangou: return "héngzhéwāngōu"
        case .hengzhezhegou: return "héngzhézhégōu"
        case .hengzhezhepie: return "héngzhézhépiě"
        case .shuzhe: return "shùzhé"
        case .shuti: return "shùtí"
        case .shugou: return "shùgōu"
        case .shuwan: return "shùwān"
        case .shuwangou: return "shùwāngōu"
        case .shuzhezhe: return "shùzhézhé"
        case .shuzhezhegou: return "shùzhézhégōu"
        case .piezhe: return "piězhé"
        case .piedian: return "piědiǎn"
        case .xiegou: return "xiégōu"
        case .wangou: return "wāngōu"
        case .unknown: return "?"
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
        // Provide reasonable descriptions for compound strokes
        case .hengzhe: return "Horizontal-Turning"
        case .henggou: return "Horizontal-Hook"
        case .hengpie: return "Horizontal-Left"
        case .hengxiegou: return "Horizontal-Slanted Hook"
        case .hengzhezhe: return "Horizontal-Turn-Turn"
        case .hengzheti: return "Horizontal-Turn-Up"
        case .hengzhewan: return "Horizontal-Turn-Bend"
        case .hengzhewangou: return "Horizontal-Turn-Bend-Hook"
        case .hengzhezhegou: return "Horizontal-Turn-Turn-Hook"
        case .hengzhezhepie: return "Horizontal-Turn-Turn-Left"
        case .shuzhe: return "Vertical-Turning"
        case .shuti: return "Vertical-Upward"
        case .shugou: return "Vertical-Hook"
        case .shuwan: return "Vertical-Bend"
        case .shuwangou: return "Vertical-Bend-Hook"
        case .shuzhezhe: return "Vertical-Turn-Turn"
        case .shuzhezhegou: return "Vertical-Turn-Turn-Hook"
        case .piezhe: return "Left-Turning"
        case .piedian: return "Left-Dot"
        case .xiegou: return "Slanted Hook"
        case .wangou: return "Bend Hook"
        case .unknown: return "Unknown"
        }
    }
}
