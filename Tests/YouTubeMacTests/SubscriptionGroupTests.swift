import XCTest
@testable import YouTubeMac

final class SubscriptionGroupTests: XCTestCase {
    private let channels = [
        SubscriptionItem(id: "channel-a", name: "Zebra", avatarURL: nil, isLive: false),
        SubscriptionItem(id: "channel-b", name: "Alpha", avatarURL: nil, isLive: false)
    ]

    func testGroupsPreserveManualOrderAndIgnoreUnavailableChannels() throws {
        var group = SubscriptionGroup(name: "Tech", channelIDs: ["channel-a", "channel-b", "missing"])
        XCTAssertEqual(group.channels(in: channels).map(\.name), ["Alpha", "Zebra"])
        group.sortOrder = .manual
        XCTAssertEqual(group.channels(in: channels).map(\.name), ["Zebra", "Alpha"])
        group.moveChannel("channel-b", by: -1)
        XCTAssertEqual(group.channels(in: channels).map(\.name), ["Alpha", "Zebra"])
        group.isExpanded = false
        let restored = try JSONDecoder().decode(SubscriptionGroup.self, from: JSONEncoder().encode(group))
        XCTAssertEqual(restored, group)
        XCTAssertEqual(restored.channelIDs.last, "missing", "Temporarily unavailable channels are not deleted")
    }

    func testGroupNormalizationBoundsAndDeduplicatesMembership() {
        let group = SubscriptionGroup(name: "  Tech  ", channelIDs: ["", "a", "a"] + (0..<100).map(String.init))
        XCTAssertEqual(group.normalized.name, "Tech")
        XCTAssertEqual(group.normalized.channelIDs.count, SubscriptionGroup.maximumChannels)
        XCTAssertEqual(Set(group.normalized.channelIDs).count, SubscriptionGroup.maximumChannels)
    }

    func testMembershipUsesStableChannelIdentityNotDisplayName() {
        let channel = SubscriptionItem(id: "https://www.youtube.com/channel/UCabcdefghijklmnopqrstuv",
                                       name: "Renamed", avatarURL: nil, isLive: false)
        let group = SubscriptionGroup(name: "Tech", channelIDs: ["UCabcdefghijklmnopqrstuv"])
        XCTAssertEqual(group.channels(in: [channel]).first?.name, "Renamed")
        XCTAssertTrue(group.channels(in: channels).isEmpty)
    }
}
