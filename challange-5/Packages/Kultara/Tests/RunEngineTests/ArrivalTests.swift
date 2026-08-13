import ContentKit
import Foundation
import Testing
@testable import RunEngine

/// `FR-ARR-01` is two conditions, and the second one is the one that matters.
///
/// Every test here that passes with only the distance check is written so it fails without the
/// accuracy check — proving the guard exists rather than confirming the happy path.
struct ArrivalEvaluatorTests {

    static let gate = Coordinate(lat: -8.6570, lon: 115.2160)

    private func fix(
        lat: Double, lon: Double, accuracy: Double
    ) -> LocationFix {
        LocationFix(
            coordinate: Coordinate(lat: lat, lon: lon),
            horizontalAccuracyM: accuracy,
            timestamp: Date())
    }

    @Test func aFixInsideTheRadiusWithGoodAccuracyArrives() throws {
        let decision = ArrivalEvaluator.decide(
            fix: fix(lat: -8.6571, lon: 115.2161, accuracy: 10),
            target: Self.gate, radiusM: 75)
        #expect(decision.isArrived)
        #expect(decision.distanceM < 75)
    }

    @Test func aCellTowerFixDoesNotUnlockACheckpointItMerelyOverlaps() throws {
        // The whole reason the accuracy half exists: a 500 m fix centred on the gate is consistent
        // with standing in the next neighbourhood.
        let decision = ArrivalEvaluator.decide(
            fix: fix(lat: -8.6570, lon: 115.2160, accuracy: 500),
            target: Self.gate, radiusM: 75)
        #expect(!decision.isArrived)
        #expect(decision == .accuracyInsufficient(distanceM: decision.distanceM, accuracyM: 500))
    }

    @Test func aPreciseFixOutsideTheRadiusDoesNotArrive() throws {
        let decision = ArrivalEvaluator.decide(
            fix: fix(lat: -8.6650, lon: 115.2160, accuracy: 5),
            target: Self.gate, radiusM: 75)
        #expect(!decision.isArrived)
        if case .outsideRadius(let distance, _) = decision {
            #expect(distance > 75)
        } else {
            Issue.record("Expected outsideRadius, got \(decision)")
        }
    }

    @Test func accuracyExactlyAtTheRadiusIsAccepted() throws {
        // The boundary belongs to the walker: `FR-ARR-01` says "no worse than the radius".
        let decision = ArrivalEvaluator.decide(
            fix: fix(lat: -8.6570, lon: 115.2160, accuracy: 75),
            target: Self.gate, radiusM: 75)
        #expect(decision.isArrived)
    }

    @Test func aTighterRadiusRejectsAFixTheLooserOneAccepted() throws {
        // FR-ARR-07 — the radius is content, tuned per place, and the rule has to actually read it.
        let sample = fix(lat: -8.6570, lon: 115.2160, accuracy: 60)
        #expect(ArrivalEvaluator.decide(fix: sample, target: Self.gate, radiusM: 75).isArrived)
        #expect(!ArrivalEvaluator.decide(fix: sample, target: Self.gate, radiusM: 40).isArrived)
    }

    @Test func accuracyIsReducedFarFromTheCheckpointAndRaisedOnApproach() throws {
        // NFR-BAT-03.
        #expect(ArrivalEvaluator.desiredAccuracyM(forDistanceM: 1200) == 100)
        #expect(ArrivalEvaluator.desiredAccuracyM(forDistanceM: 120) == 10)
    }

    @Test func distanceIsMeasuredOnTheGlobeNotOnTheNumbers() throws {
        // A degree of latitude is ~111 km; a naive difference of coordinates would report 0.001.
        let a = Coordinate(lat: -8.6570, lon: 115.2160)
        let b = Coordinate(lat: -8.6580, lon: 115.2160)
        let metres = Geo.distanceM(a, b)
        #expect(metres > 105 && metres < 120)
    }
}
