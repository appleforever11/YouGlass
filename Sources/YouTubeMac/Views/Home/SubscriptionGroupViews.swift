import SwiftUI

struct SubscriptionGroupSidebar: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        ForEach(store.sidebarSubscriptionGroupsSnapshot) { group in
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    if !compact {
                        Button { store.toggleSubscriptionGroup(group) } label: {
                            Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .frame(width: 20, height: 30)
                        }
                        .help(group.isExpanded ? "Collapse \(group.name)" : "Expand \(group.name)")
                    }
                    Button { store.showSubscriptionGroup(group) } label: {
                        Group {
                            if compact { Image(systemName: "folder") }
                            else { Label(group.name, systemImage: "folder").lineLimit(1) }
                        }
                        .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
                        .frame(height: 32)
                    }
                    .help("Latest uploads in \(group.name)")
                    .accessibilityLabel("Subscription group: \(group.name)")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(palette.text)
                .padding(.horizontal, 12)
                .background(store.selectedSubscriptionGroupID == group.id ? palette.selected.opacity(0.3) : .clear)
                .contextMenu {
                    Button("Edit group") { store.editSubscriptionGroup(group) }
                    Button("Delete group", role: .destructive) { store.deleteSubscriptionGroup(group) }
                }
                .dropDestination(for: String.self) { ids, _ in
                    for id in ids { store.addChannel(id, to: group.id) }
                    return !ids.isEmpty
                }
                if group.isExpanded && !compact {
                    ForEach(group.channels(in: store.sidebarSubscriptionsSnapshot)) { item in
                        SidebarSubscriptionRow(item: item, palette: palette, compact: false) {
                            Task { @MainActor in store.openChannel(item) }
                        }
                    }
                }
            }
        }
        if !store.sidebarSubscriptionGroupsSnapshot.isEmpty && !compact {
            Text("All channels")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 8)
        }
    }
}

struct SubscriptionGroupDetailView: View {
    @EnvironmentObject private var store: YouTubeStore
    let palette: Palette
    let compact: Bool

    var body: some View {
        if let group = store.selectedSubscriptionGroup {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(group.name, systemImage: "folder")
                            .font(.title2.bold())
                        Text("Latest uploads from \(group.channels(in: store.subscriptions).count) channels")
                            .font(.subheadline).foregroundStyle(palette.secondaryText)
                    }
                    Spacer()
                    Button("Edit group") { store.editSubscriptionGroup(group) }
                }
                if store.isLoading { ProgressView("Loading latest uploads…") }
                if let message = store.subscriptionGroupMessage {
                    Text(message).foregroundStyle(palette.secondaryText)
                }
                if !store.subscriptionGroupVideos.isEmpty {
                    VideoRow(title: "Latest uploads", videos: store.subscriptionGroupVideos,
                             palette: palette, compact: compact, showsSeeAll: false)
                }
            }
            .foregroundStyle(palette.text)
        }
    }
}

struct SubscriptionGroupEditor: View {
    @EnvironmentObject private var store: YouTubeStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: SubscriptionGroup
    @State private var search = ""

    init(group: SubscriptionGroup?) {
        _draft = State(initialValue: group ?? SubscriptionGroup())
    }

    private var available: [SubscriptionItem] {
        store.subscriptions.filter {
            search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Subscription group").font(.title2.bold())
            TextField("Group name", text: $draft.name)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Group name")
            Picker("Channel order", selection: $draft.sortOrder) {
                ForEach(SubscriptionGroup.SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading) {
                    TextField("Find a subscription", text: $search)
                        .textFieldStyle(.roundedBorder)
                    List(available) { item in
                        let id = item.canonicalChannelID ?? item.id
                        Toggle(item.name, isOn: Binding(
                            get: { draft.channelIDs.contains(id) },
                            set: { included in
                                if included { draft.channelIDs.append(id) }
                                else { draft.channelIDs.removeAll { $0 == id } }
                            }
                        ))
                        .disabled(!draft.channelIDs.contains(id)
                                  && draft.channelIDs.count >= SubscriptionGroup.maximumChannels)
                    }
                }
                VStack(alignment: .leading) {
                    Text("In this group (\(draft.channelIDs.count)/\(SubscriptionGroup.maximumChannels))")
                        .font(.headline)
                    List(draft.channels(in: store.subscriptions)) { item in
                        let id = item.canonicalChannelID ?? item.id
                        HStack {
                            Text(item.name).lineLimit(1)
                            Spacer()
                            if draft.sortOrder == .manual {
                                Button { draft.moveChannel(id, by: -1) } label: { Image(systemName: "arrow.up") }
                                    .help("Move \(item.name) up")
                                    .disabled(draft.channelIDs.first == id)
                                Button { draft.moveChannel(id, by: 1) } label: { Image(systemName: "arrow.down") }
                                    .help("Move \(item.name) down")
                                    .disabled(draft.channelIDs.last == id)
                            }
                            Button { draft.channelIDs.removeAll { $0 == id } } label: { Image(systemName: "minus.circle") }
                                .help("Remove \(item.name) from group")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
            Text("Groups organize channels in YouGlass. Your YouTube subscriptions stay subscribed.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save group") {
                    store.saveSubscriptionGroup(draft)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.normalized.name.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 680, height: 520)
    }
}
