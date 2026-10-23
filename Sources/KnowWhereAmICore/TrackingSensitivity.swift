import Foundation

struct TrackingSensitivity {
    let minimumMatches: Int
    let minimumExactMatches: Int
    let minimumCoverage: Double
    let ambiguityMargin: Double

    init(displacement: Int, retractingKnownSpeech: Bool = false, replacingHypothesis: Bool = false) {
        let distance = abs(displacement)
        if displacement < 0 {
            minimumMatches = retractingKnownSpeech && distance <= 3 ? 1 : (distance <= 3 ? 2 : 3)
        } else {
            minimumMatches = distance <= 3 ? 1 : (distance <= 12 ? 2 : 3)
        }
        minimumExactMatches = minimumMatches == 1 ? 0 : (minimumMatches == 2 ? 1 : 3)
        minimumCoverage = max(replacingHypothesis ? 0.65 : 0.5,
                              0.5 + min(0.35, Double(max(0, distance - 3)) * 0.015))
        ambiguityMargin = minimumMatches == 1 ? 0 : (minimumMatches == 2 ? 0.75 : 1 + min(1, Double(distance) / 64))
    }

    func accepts(matches: Int, exact: Int, observed: Int) -> Bool {
        observed > 0 && matches >= minimumMatches && exact >= minimumExactMatches
            && Double(matches) / Double(observed) >= minimumCoverage
    }
}
