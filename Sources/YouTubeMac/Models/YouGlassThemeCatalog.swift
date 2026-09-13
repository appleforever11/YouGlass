import SwiftUI

enum YouGlassThemeCollection: String, CaseIterable, Codable, Identifiable, Hashable {
    case all
    case vivid
    case calm
    case warm
    case cool
    case nature
    case minimal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All environments"
        case .vivid: "Vivid"
        case .calm: "Calm"
        case .warm: "Warm"
        case .cool: "Cool"
        case .nature: "Nature"
        case .minimal: "Minimal"
        }
    }
}

enum YouGlassThemeFamily: String, CaseIterable, Codable, Identifiable, Hashable {
    case neoCitrus
    case youGlassOriginal
    case electricTide
    case arcticGlass
    case roseQuartz
    case deepOrbit
    case goldenGate
    case silverMist
    case forestRadar
    case emberConsole
    case solarDesk
    case peachChrome
    case auroraBloom
    case midnightVelvet
    case oceanDrive
    case desertRose
    case alpineSage
    case copperNoir
    case lavenderHaze
    case rubySignal
    case monochromeStudio
    case cosmicCoral
    case indigoHarbor
    case paperLantern

    var id: String { rawValue }

    var title: String {
        switch self {
        case .neoCitrus: "Neo Citrus"
        case .youGlassOriginal: "YouGlass Original"
        case .electricTide: "Electric Tide"
        case .arcticGlass: "Arctic Glass"
        case .roseQuartz: "Rose Quartz"
        case .deepOrbit: "Deep Orbit"
        case .goldenGate: "Golden Gate"
        case .silverMist: "Silver Mist"
        case .forestRadar: "Forest Radar"
        case .emberConsole: "Ember Console"
        case .solarDesk: "Solar Desk"
        case .peachChrome: "Peach Chrome"
        case .auroraBloom: "Aurora Bloom"
        case .midnightVelvet: "Midnight Velvet"
        case .oceanDrive: "Ocean Drive"
        case .desertRose: "Desert Rose"
        case .alpineSage: "Alpine Sage"
        case .copperNoir: "Copper Noir"
        case .lavenderHaze: "Lavender Haze"
        case .rubySignal: "Ruby Signal"
        case .monochromeStudio: "Monochrome Studio"
        case .cosmicCoral: "Cosmic Coral"
        case .indigoHarbor: "Indigo Harbor"
        case .paperLantern: "Paper Lantern"
        }
    }

    var subtitle: String {
        switch self {
        case .neoCitrus: "Lemon, lime, and aqua glass"
        case .youGlassOriginal: "Fuchsia, violet, and indigo"
        case .electricTide: "Teal, cyan, and signal green"
        case .arcticGlass: "Ice blue, silver, and periwinkle"
        case .roseQuartz: "Blush, coral, and lavender"
        case .deepOrbit: "Midnight blue and electric indigo"
        case .goldenGate: "Fog, redwood, and warm signal"
        case .silverMist: "Polished silver, slate, and sky"
        case .forestRadar: "Pine, moss, and warm signal"
        case .emberConsole: "Orange, amber, and red glass"
        case .solarDesk: "Sunlit gold, blue, and paper"
        case .peachChrome: "Peach, aqua, and soft chrome"
        case .auroraBloom: "Northern lights over violet glass"
        case .midnightVelvet: "Plum, ink, and starlight"
        case .oceanDrive: "Pacific blue, foam, and sea glass"
        case .desertRose: "Terracotta, rose, and dusk"
        case .alpineSage: "Pine, glacier, and sage"
        case .copperNoir: "Burnished copper and midnight ink"
        case .lavenderHaze: "Soft lilac, cloud, and orchid"
        case .rubySignal: "Ruby, crimson, and champagne"
        case .monochromeStudio: "Graphite, paper, and silver"
        case .cosmicCoral: "Coral flare, orchid, and space blue"
        case .indigoHarbor: "Harbor blue, indigo, and mint"
        case .paperLantern: "Warm paper, saffron, and ink"
        }
    }

    var systemImage: String {
        switch self {
        case .neoCitrus: "sun.max.fill"
        case .youGlassOriginal: "sparkles"
        case .electricTide: "water.waves"
        case .arcticGlass: "snowflake"
        case .roseQuartz: "heart.fill"
        case .deepOrbit: "moon.stars.fill"
        case .goldenGate: "building.2.fill"
        case .silverMist: "cloud.fog.fill"
        case .forestRadar: "leaf.fill"
        case .emberConsole: "flame.fill"
        case .solarDesk: "sun.max.fill"
        case .peachChrome: "circle.grid.2x2.fill"
        case .auroraBloom: "sparkles"
        case .midnightVelvet: "moon.stars.fill"
        case .oceanDrive: "water.waves"
        case .desertRose: "sunset.fill"
        case .alpineSage: "mountain.2.fill"
        case .copperNoir: "circle.lefthalf.filled"
        case .lavenderHaze: "cloud.fill"
        case .rubySignal: "diamond.fill"
        case .monochromeStudio: "circle.lefthalf.filled.righthalf.striped.horizontal"
        case .cosmicCoral: "star.circle.fill"
        case .indigoHarbor: "sailboat.fill"
        case .paperLantern: "lightbulb.fill"
        }
    }

    var collection: YouGlassThemeCollection {
        switch self {
        case .neoCitrus, .youGlassOriginal, .roseQuartz, .emberConsole, .auroraBloom, .rubySignal, .cosmicCoral:
            .vivid
        case .electricTide, .arcticGlass, .deepOrbit, .silverMist, .solarDesk, .oceanDrive, .indigoHarbor:
            .cool
        case .goldenGate, .desertRose, .copperNoir, .paperLantern:
            .warm
        case .forestRadar, .alpineSage:
            .nature
        case .lavenderHaze, .midnightVelvet:
            .calm
        case .monochromeStudio, .peachChrome:
            .minimal
        }
    }

    var isFeatured: Bool {
        switch self {
        case .neoCitrus, .auroraBloom, .midnightVelvet, .paperLantern:
            true
        default:
            false
        }
    }

    var isNew: Bool {
        switch self {
        case .auroraBloom, .midnightVelvet, .oceanDrive, .desertRose, .alpineSage,
             .copperNoir, .lavenderHaze, .rubySignal, .monochromeStudio,
             .cosmicCoral, .indigoHarbor, .paperLantern:
            true
        default:
            false
        }
    }

    var badgeTitle: String? {
        if isNew { return "NEW" }
        return isFeatured ? "FEATURED" : nil
    }

}

struct YouGlassThemeColors {
    let window: Color
    let sidebar: Color
    let content: Color
    let card: Color
    let selected: Color
    let stroke: Color
    let text: Color
    let secondaryText: Color
    let tertiaryText: Color
    let primary: Color
    let secondary: Color
    let tertiary: Color
    let accent: Color
}
