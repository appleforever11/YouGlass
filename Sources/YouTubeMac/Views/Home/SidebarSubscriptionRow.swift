import SwiftUI

struct SidebarSubscriptionRow: View {
    @EnvironmentObject private var store: YouTubeStore
    let item: SubscriptionItem
    let palette: Palette
    let compact: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AsyncAvatar(url: item.avatarURL)
                    .frame(width: 28, height: 28)
                    .overlay {
                        if item.avatarURL == nil {
                            Text(String(item.name.prefix(2)))
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                        }
                    }

                if !compact {
                    Text(item.name)
                        .font(.system(size: 13, weight: isHovered ? .semibold : .regular))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                }

                if item.isLive {
                    Circle()
                        .fill(palette.accent)
                        .frame(width: 6, height: 6)
                        .shadow(color: palette.accent.opacity(0.62), radius: 4)
                }
            }
            .foregroundStyle(palette.text)
            .frame(maxWidth: .infinity, alignment: compact ? .center : .leading)
            .padding(.horizontal, compact ? 8 : 12)
            .frame(height: 38)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isHovered ? palette.selected.opacity(palette.isDark ? 0.32 : 0.20) : .clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(isHovered ? palette.stroke : .clear, lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, compact ? 4 : 10)
        .onHover { isHovered = $0 }
        .help(item.name)
        .accessibilityLabel(item.isLive ? "\(item.name), live now" : item.name)
        .draggable(item.canonicalChannelID ?? item.id)
        .contextMenu {
            Menu("Add to group") {
                ForEach(store.sidebarSubscriptionGroupsSnapshot) { group in
                    Button(group.name) { store.addChannel(item.canonicalChannelID ?? item.id, to: group.id) }
                        .disabled(group.channelIDs.contains(item.canonicalChannelID ?? item.id)
                                  || group.channelIDs.count >= SubscriptionGroup.maximumChannels)
                }
                Button("New group…") {
                    var group = SubscriptionGroup()
                    group.channelIDs = [item.canonicalChannelID ?? item.id]
                    store.editSubscriptionGroup(group)
                }
                .disabled(store.sidebarSubscriptionGroupsSnapshot.count >= SubscriptionGroup.maximumGroups)
            }
        }
    }
}
