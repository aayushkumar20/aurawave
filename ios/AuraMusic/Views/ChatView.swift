import SwiftUI

public struct ChatView: View {
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var player = AudioPlayerService.shared

    public let bottomInset: CGFloat

    @State private var textInput: String = ""
    @State private var showEmojiBar: Bool = false
    @State private var showGroupDrawer: Bool = false
    @State private var showPlaylistDrawer: Bool = false
    @State private var groupSearchText: String = ""
    @State private var copiedNotice: Bool = false
    @State private var showEditNameDialog: Bool = false
    @State private var newNameInput: String = ""
    @State private var showCreateGroupDialog: Bool = false
    @State private var newGroupName: String = ""
    @State private var newGroupDesc: String = ""

    @State private var showAddSongSheet: Bool = false
    @State private var songSearchQuery: String = ""
    @State private var songSearchResults: [Song] = []
    @State private var isSearchingSongs: Bool = false
    @State private var songSearchTask: Task<Void, Never>?

    public init(bottomInset: CGFloat = 85) {
        self.bottomInset = bottomInset
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            Color(hex: "090D16").ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Header Bar
                chatHeader

                // Group Playlist Drawer (Collapsible)
                if showPlaylistDrawer {
                    groupPlaylistSection
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Search & Groups Drawer (Collapsible)
                if showGroupDrawer {
                    groupSearchDrawer
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Messages Thread
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            // Welcome / Announcement Banner
                            roomIntroBanner

                            ForEach(chatService.messages) { msg in
                                messageBubbleView(msg: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        // Generous bottom padding so message list is never hidden behind typing bar or bottom bar
                        .padding(.bottom, bottomInset + 80)
                    }
                    .onChange(of: chatService.messages.count) { _ in
                        if let last = chatService.messages.last {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Bottom Floating Input Bar anchored above bottom navigation / player bar
            bottomInputBar
                .padding(.bottom, bottomInset)
        }
        .sheet(isPresented: $showCreateGroupDialog) {
            createGroupSheet
        }
        .sheet(isPresented: $showAddSongSheet) {
            addSongSheet
        }
        .alert("Change Display Handle", isPresented: $showEditNameDialog) {
            TextField("Enter your name", text: $newNameInput)
            Button("Save") {
                if !newNameInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    chatService.updateProfileName(newNameInput)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Set how other listeners see you in live music rooms.")
        }
    }

    // -------------------------------------------------------------
    // Top Chat Header Bar
    // -------------------------------------------------------------
    private var chatHeader: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                // Room info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("#\(chatService.currentRoom.name)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Circle()
                            .fill(Color(hex: "10B981"))
                            .frame(width: 8, height: 8)
                    }

                    HStack(spacing: 6) {
                        // 1-Tap Copyable Code Pill
                        Button(action: {
                            UIPasteboard.general.string = chatService.currentRoom.id
                            withAnimation { copiedNotice = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { copiedNotice = false }
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: copiedNotice ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 9, weight: .bold))
                                Text(copiedNotice ? "Copied!" : chatService.currentRoom.id)
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(copiedNotice ? Color(hex: "10B981") : Color(hex: "06B6D4"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(hex: "06B6D4").opacity(0.15))
                            .clipShape(Capsule())
                        }

                        // User handle pill (tap to edit)
                        Button(action: {
                            newNameInput = chatService.currentProfile?.name ?? ""
                            showEditNameDialog = true
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 10))
                                Text(chatService.currentProfile?.name ?? "Listener")
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundColor(Color(hex: "94A3B8"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "1E2536"))
                            .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                // Group Playlist Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showPlaylistDrawer.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 11, weight: .bold))
                        Text("\(chatService.groupPlaylist.count)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(showPlaylistDrawer ? .white : Color(hex: "06B6D4"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(showPlaylistDrawer ? Color(hex: "6366F1") : Color(hex: "1E2536"))
                    .clipShape(Capsule())
                }

                // Search & Groups Toggle Button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showGroupDrawer.toggle()
                    }
                }) {
                    Image(systemName: showGroupDrawer ? "chevron.up" : "magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(showGroupDrawer ? .white : Color(hex: "06B6D4"))
                        .frame(width: 30, height: 30)
                        .background(showGroupDrawer ? Color(hex: "6366F1") : Color(hex: "1E2536"))
                        .clipShape(Circle())
                }

                // Create Group Button
                Button(action: { showCreateGroupDialog = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 30, height: 30)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "06B6D4")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(Color(hex: "131824"))
    }

    // -------------------------------------------------------------
    // Collaborative Group Playlist Drawer
    // -------------------------------------------------------------
    private var groupPlaylistSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "06B6D4"))
                    Text("Group Playlist • \(chatService.groupPlaylist.count) tracks")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                HStack(spacing: 6) {
                    if let current = player.currentSong {
                        Button(action: {
                            chatService.addSongToGroupPlaylist(current)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "music.note")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Add Playing")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(hex: "6366F1").opacity(0.8))
                            .clipShape(Capsule())
                        }
                    }

                    // Unconditional + Add Song button for any group member
                    Button(action: {
                        songSearchQuery = ""
                        songSearchResults = []
                        showAddSongSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 10, weight: .bold))
                            Text("Add Song")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "6366F1"), Color(hex: "06B6D4")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)

            if chatService.groupPlaylist.isEmpty {
                Button(action: {
                    songSearchQuery = ""
                    songSearchResults = []
                    showAddSongSheet = true
                }) {
                    HStack {
                        Text("No tracks yet. Tap to search & add songs to group!")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "06B6D4"))
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(Color(hex: "06B6D4"))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(chatService.groupPlaylist) { item in
                            let isPlayingThis = player.currentSong?.id == item.song.id
                            HStack(spacing: 8) {
                                AsyncImage(url: URL(string: item.song.thumbnailUrl)) { img in
                                    img.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Color(hex: "1E2536")
                                }
                                .frame(width: 36, height: 36)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.song.title)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .frame(maxWidth: 110, alignment: .leading)
                                    Text("By \(item.addedBy)")
                                        .font(.system(size: 10))
                                        .foregroundColor(Color(hex: "06B6D4"))
                                        .lineLimit(1)
                                }

                                Button(action: {
                                    player.playSong(item.song)
                                    chatService.syncPlaybackToGroup(song: item.song, isPlaying: true)
                                }) {
                                    Image(systemName: isPlayingThis ? "speaker.wave.2.fill" : "play.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Color(hex: "090D16"))
                                        .frame(width: 26, height: 26)
                                        .background(Color(hex: "06B6D4"))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(6)
                            .background(isPlayingThis ? Color(hex: "6366F1").opacity(0.35) : Color(hex: "1E2536"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(hex: "161C2C"))
    }

    // -------------------------------------------------------------
    // Search & Groups Drawer
    // -------------------------------------------------------------
    private var groupSearchDrawer: some View {
        VStack(spacing: 10) {
            // Search Input Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(hex: "64748B"))
                    .font(.system(size: 14))

                TextField("Search group name or enter code (e.g. AURA-XXXX)...", text: $groupSearchText)
                    .foregroundColor(.white)
                    .font(.system(size: 13))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)

                if !groupSearchText.isEmpty {
                    Button(action: { groupSearchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "64748B"))
                            .font(.system(size: 14))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "090D16"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)

            // Direct Join card if user types a custom Room ID / Code
            let cleanQuery = groupSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanQuery.isEmpty && !chatService.availableRooms.contains(where: { $0.id.caseInsensitiveCompare(cleanQuery) == .orderedSame }) {
                Button(action: {
                    let name = chatService.currentProfile?.name ?? "Listener"
                    let dob = chatService.currentProfile?.dob ?? "01/01/2000"
                    _ = chatService.joinRoomById(name: name, dob: dob, roomId: cleanQuery)
                    groupSearchText = ""
                    withAnimation { showGroupDrawer = false }
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Color(hex: "06B6D4"))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Join Group Code: \(cleanQuery.uppercased())")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                            Text("Tap to connect directly to this room")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "94A3B8"))
                        }

                        Spacer()

                        Text("Join 🚀")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "6366F1"))
                            .clipShape(Capsule())
                    }
                    .padding(10)
                    .background(Color(hex: "1E2536"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                }
            }

            // Available & Filtered Groups List
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filteredRooms) { room in
                        let isCurrent = chatService.currentRoom.id == room.id
                        Button(action: {
                            chatService.switchRoom(room)
                            withAnimation { showGroupDrawer = false }
                        }) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 4) {
                                    Text(room.name)
                                        .font(.system(size: 12, weight: isCurrent ? .bold : .medium))
                                        .foregroundColor(isCurrent ? .white : Color(hex: "E2E8F0"))
                                        .lineLimit(1)
                                    if isCurrent {
                                        Circle()
                                            .fill(Color(hex: "10B981"))
                                            .frame(width: 6, height: 6)
                                    }
                                }

                                Text("ID: \(room.id)")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(hex: "06B6D4"))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isCurrent ? Color(hex: "6366F1") : Color(hex: "1E2536"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 6)
            }
        }
        .padding(.vertical, 8)
        .background(Color(hex: "161C2C"))
    }

    private var filteredRooms: [ChatRoom] {
        let q = groupSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            return chatService.availableRooms
        }
        return chatService.availableRooms.filter {
            $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q)
        }
    }

    // -------------------------------------------------------------
    // Welcome / Info Banner
    // -------------------------------------------------------------
    private var roomIntroBanner: some View {
        VStack(spacing: 4) {
            Text("🎧 Real-Time Live Music Group")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color(hex: "06B6D4"))

            Text("Collaborative Playlist Active: anyone in this group can add songs and chat in real time.")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "64748B"))
                .multilineTextAlignment(.center)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "131824").opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.bottom, 6)
    }

    // -------------------------------------------------------------
    // Bottom Input Bar
    // -------------------------------------------------------------
    private var bottomInputBar: some View {
        VStack(spacing: 6) {
            // Share & Add to Group Playlist chip
            if let current = player.currentSong {
                Button(action: {
                    chatService.addSongToGroupPlaylist(current)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(Color(hex: "06B6D4"))
                        Text("Add to Group Playlist: \(current.title)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color(hex: "06B6D4"))
                            .lineLimit(1)
                        Spacer()
                        Text("+ Add 🚀")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "6366F1"))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(hex: "6366F1").opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Quick Emoji Drawer
            if showEmojiBar {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chatService.popularEmojis, id: \.self) { emoji in
                            Text(emoji)
                                .font(.system(size: 20))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(hex: "1E2536"))
                                .clipShape(Capsule())
                                .onTapGesture {
                                    textInput.append(emoji)
                                }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            // Main Input Row
            HStack(spacing: 8) {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showEmojiBar.toggle()
                    }
                }) {
                    Image(systemName: "face.smiling.fill")
                        .font(.system(size: 22))
                        .foregroundColor(showEmojiBar ? Color(hex: "06B6D4") : Color(hex: "94A3B8"))
                        .frame(width: 36, height: 36)
                }

                Button(action: {
                    songSearchQuery = ""
                    songSearchResults = []
                    showAddSongSheet = true
                }) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "06B6D4"))
                        .frame(width: 36, height: 36)
                }

                TextField("Message #\(chatService.currentRoom.name)...", text: $textInput)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(hex: "090D16"))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color(hex: "1E2536"), lineWidth: 1)
                    )

                Button(action: {
                    let trimmed = textInput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        chatService.sendMessage(text: trimmed)
                        textInput = ""
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(hex: "475569") : Color(hex: "6366F1"))
                }
                .disabled(textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(hex: "131824").opacity(0.96))
                .shadow(color: Color.black.opacity(0.4), radius: 10, y: -2)
        )
        .padding(.horizontal, 10)
    }

    // -------------------------------------------------------------
    // Message Bubble View
    // -------------------------------------------------------------
    @ViewBuilder
    private func messageBubbleView(msg: ChatMessage) -> some View {
        let isMe = msg.isFromMe
        VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
            if !isMe && !msg.senderName.isEmpty {
                Text(msg.senderName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: "06B6D4"))
                    .padding(.leading, 6)
            }

            VStack(alignment: .leading, spacing: 8) {
                if !msg.text.isEmpty {
                    Text(msg.text)
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }

                // Shared song card
                if let song = msg.sharedSong {
                    HStack(spacing: 8) {
                        AsyncImage(url: URL(string: song.thumbnailUrl)) { img in
                            img.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(hex: "1E2536")
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            Text(song.artist)
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "94A3B8"))
                                .lineLimit(1)
                        }

                        Spacer()

                        // Add to Group Playlist Button
                        Button(action: {
                            chatService.addSongToGroupPlaylist(song)
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 15))
                                .foregroundColor(Color(hex: "06B6D4"))
                                .frame(width: 28, height: 28)
                                .background(Color(hex: "1E2536"))
                                .clipShape(Circle())
                        }

                        // Play Now Button
                        Button(action: {
                            player.playSong(song)
                            chatService.syncPlaybackToGroup(song: song, isPlaying: true)
                        }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "090D16"))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: "06B6D4"))
                                .clipShape(Circle())
                        }
                    }
                    .padding(8)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isMe ? Color(hex: "6366F1") : Color(hex: "131824"))
            )

            // Reactions Row & Reaction Picker Button
            HStack(spacing: 6) {
                ForEach(Array(msg.reactions.keys.sorted()), id: \.self) { emoji in
                    if let count = msg.reactions[emoji], count > 0 {
                        HStack(spacing: 3) {
                            Text(emoji).font(.system(size: 11))
                            Text("\(count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "94A3B8"))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "1E2536"))
                        .clipShape(Capsule())
                        .onTapGesture {
                            chatService.addReaction(to: msg.id, emoji: emoji)
                        }
                    }
                }

                // Quick React "+ emoji" button
                Menu {
                    ForEach(chatService.popularEmojis, id: \.self) { emoji in
                        Button(action: { chatService.addReaction(to: msg.id, emoji: emoji) }) {
                            Text(emoji)
                        }
                    }
                } label: {
                    Image(systemName: "plus.bubble")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "64748B"))
                        .padding(4)
                }
            }
            .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
    }

    // -------------------------------------------------------------
    // Create Group Sheet
    // -------------------------------------------------------------
    private var createGroupSheet: some View {
        NavigationView {
            ZStack {
                Color(hex: "090D16").ignoresSafeArea()

                VStack(spacing: 16) {
                    Text("Create a Music Group")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.top, 12)

                    Text("You will get a unique Room Code (e.g. AURA-XXXX) that your friends can search and join.")
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: "94A3B8"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)

                    TextField("Group Name (e.g. EDM Hype Lounge)", text: $newGroupName)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color(hex: "131824"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)

                    TextField("Description (Optional)", text: $newGroupDesc)
                        .foregroundColor(.white)
                        .padding(12)
                        .background(Color(hex: "131824"))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)

                    Button(action: {
                        let name = chatService.currentProfile?.name ?? "Listener"
                        let dob = chatService.currentProfile?.dob ?? "01/01/2000"
                        _ = chatService.createAndJoinRoom(
                            userName: name,
                            userDob: dob,
                            roomName: newGroupName.isEmpty ? "Aura Lounge" : newGroupName,
                            description: newGroupDesc
                        )
                        newGroupName = ""
                        newGroupDesc = ""
                        showCreateGroupDialog = false
                    }) {
                        Text("Create & Enter Room 🚀")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "6366F1"), Color(hex: "06B6D4")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Spacer()
                }
            }
            .navigationBarItems(trailing: Button("Cancel") { showCreateGroupDialog = false })
        }
    }

    // -------------------------------------------------------------
    // Add Song to Collaborative Group Playlist Sheet
    // -------------------------------------------------------------
    private var addSongSheet: some View {
        NavigationView {
            ZStack {
                Color(hex: "090D16").ignoresSafeArea()
                VStack(spacing: 12) {
                    // Search Input Field
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Color(hex: "06B6D4"))
                        TextField("Search YouTube Music to add to group...", text: $songSearchQuery)
                            .foregroundColor(.white)
                            .onChange(of: songSearchQuery) { newQuery in
                                performSongSearch(query: newQuery)
                            }
                        if !songSearchQuery.isEmpty {
                            Button(action: {
                                songSearchQuery = ""
                                songSearchResults = []
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Color(hex: "94A3B8"))
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(hex: "131824"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(hex: "1E2536"), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    if isSearchingSongs {
                        Spacer()
                        ProgressView()
                            .tint(Color(hex: "06B6D4"))
                        Spacer()
                    } else if songSearchResults.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundColor(Color(hex: "475569"))
                            Text("Search any track, artist or album")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(Color(hex: "94A3B8"))
                            Text("Songs added will sync in real time to everyone in the room")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "64748B"))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(songSearchResults) { song in
                                let isAlreadyInPlaylist = chatService.groupPlaylist.contains(where: { $0.song.id == song.id })
                                HStack(spacing: 12) {
                                    AsyncImage(url: URL(string: song.thumbnailUrl)) { phase in
                                        if let img = phase.image {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color(hex: "1E2536")
                                        }
                                    }
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(song.title)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                        Text(song.artist)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(hex: "94A3B8"))
                                            .lineLimit(1)
                                    }

                                    Spacer()

                                    Button(action: {
                                        chatService.addSongToGroupPlaylist(song)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: isAlreadyInPlaylist ? "checkmark" : "plus")
                                                .font(.system(size: 11, weight: .bold))
                                            Text(isAlreadyInPlaylist ? "Added" : "Add")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(isAlreadyInPlaylist ? Color(hex: "10B981") : Color(hex: "6366F1"))
                                        .clipShape(Capsule())
                                    }
                                    .disabled(isAlreadyInPlaylist)
                                }
                                .listRowBackground(Color(hex: "131824"))
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
                    }
                }
            }
            .navigationTitle("Add to Group Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showAddSongSheet = false
                    }
                    .foregroundColor(Color(hex: "06B6D4"))
                    .font(.system(size: 14, weight: .bold))
                }
            }
        }
    }

    private func performSongSearch(query: String) {
        songSearchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            songSearchResults = []
            isSearchingSongs = false
            return
        }

        isSearchingSongs = true
        songSearchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            let results = await YouTubeMusicEngine.shared.searchSongs(query: trimmed)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.songSearchResults = results
                self.isSearchingSongs = false
            }
        }
    }
}
