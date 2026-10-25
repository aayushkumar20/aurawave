import SwiftUI

enum RoomJoinMode {
    case browse
    case joinById
    case createRoom
}

public struct ChatView: View {
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var player = AudioPlayerService.shared

    @State private var inputName: String = ""
    @State private var inputDob: String = ""
    @State private var joinMode: RoomJoinMode = .browse
    @State private var customRoomId: String = ""
    @State private var newGroupName: String = ""
    @State private var newGroupDesc: String = ""
    @State private var selectedRoom: ChatRoom = ChatService.shared.defaultRooms[0]

    @State private var textInput: String = ""
    @State private var showEmojiBar: Bool = false
    @State private var showRoomSwitchBar: Bool = false
    @State private var copiedNotice: Bool = false

    public init() {}

    public var body: some View {
        if let profile = chatService.currentProfile {
            // Joined in Room
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("#\(chatService.currentRoom.name)")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Circle()
                                    .fill(Color(hex: "10B981"))
                                    .frame(width: 8, height: 8)
                            }

                            HStack(spacing: 6) {
                                // 1-Tap Copyable Room ID Badge
                                Button(action: {
                                    UIPasteboard.general.string = chatService.currentRoom.id
                                    withAnimation {
                                        copiedNotice = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        withAnimation { copiedNotice = false }
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: copiedNotice ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 9, weight: .bold))
                                        Text(copiedNotice ? "Copied!" : chatService.currentRoom.id)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundColor(copiedNotice ? Color(hex: "10B981") : Color(hex: "06B6D4"))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color(hex: "06B6D4").opacity(0.15))
                                    .clipShape(Capsule())
                                }

                                Text("• \(profile.name)")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "64748B"))
                                    .lineLimit(1)
                            }
                        }

                        Spacer()

                        // Switch Room Button
                        Button(action: { showRoomSwitchBar.toggle() }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(Color(hex: "06B6D4"))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: "1E2536"))
                                .clipShape(Circle())
                        }

                        // Leave Room Button
                        Button(action: { chatService.leaveRoom() }) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "EF4444"))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: "EF4444").opacity(0.15))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Room Switcher Pill list
                    if showRoomSwitchBar {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(chatService.availableRooms) { room in
                                    let isCurrent = chatService.currentRoom.id == room.id
                                    Text(room.name)
                                        .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                                        .foregroundColor(isCurrent ? .white : Color(hex: "94A3B8"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isCurrent ? Color(hex: "6366F1") : Color(hex: "1E2536"))
                                        .clipShape(Capsule())
                                        .onTapGesture {
                                            chatService.switchRoom(room)
                                            showRoomSwitchBar = false
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.bottom, 8)
                .background(Color(hex: "131824"))

                // Message Thread
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatService.messages) { msg in
                                messageBubbleView(msg: msg)
                                    .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                    .onChange(of: chatService.messages.count) { _ in
                        if let last = chatService.messages.last {
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Bottom Input
                VStack(spacing: 8) {
                    if let current = player.currentSong {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "06B6D4"))
                            Text("Share playing: \(current.title)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "06B6D4"))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(hex: "6366F1").opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture {
                            chatService.sendMessage(
                                text: "🎧 Check out this live track: \(current.title)",
                                sharedSong: current
                            )
                        }
                    }

                    if showEmojiBar {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
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
                        }
                    }

                    HStack(spacing: 8) {
                        Button(action: { showEmojiBar.toggle() }) {
                            Image(systemName: "face.smiling.fill")
                                .font(.system(size: 20))
                                .foregroundColor(showEmojiBar ? Color(hex: "06B6D4") : Color(hex: "94A3B8"))
                                .frame(width: 36, height: 36)
                        }

                        TextField("Message #\(chatService.currentRoom.name)...", text: $textInput)
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(hex: "090D16"))
                            .clipShape(Capsule())

                        Button(action: {
                            if !textInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                chatService.sendMessage(text: textInput)
                                textInput = ""
                            }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 34))
                                .foregroundColor(Color(hex: "6366F1"))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "131824"))
            }
            .background(Color(hex: "090D16").ignoresSafeArea())
        } else {
            // Join Room Gateway (Browse, Join by ID, or Create Group)
            ScrollView {
                VStack(spacing: 20) {
                    Spacer().frame(height: 20)

                    VStack(spacing: 16) {
                        Image(systemName: "person.2.badge.gearshape.fill")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "06B6D4"))
                            .frame(width: 64, height: 64)
                            .background(Color(hex: "6366F1").opacity(0.2))
                            .clipShape(Circle())

                        Text("Aura Live Chat & Groups")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)

                        Text("Listen together, share music & chat in real time across iOS & Android.")
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "64748B"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)

                        // Name & DOB Inputs
                        TextField("Your Name", text: $inputName)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(hex: "090D16"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        TextField("Date of Birth (e.g. 14/05/2002)", text: $inputDob)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color(hex: "090D16"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Join Mode Switcher Tabs
                        HStack(spacing: 4) {
                            Button(action: { joinMode = .browse }) {
                                Text("Rooms")
                                    .font(.system(size: 12, weight: joinMode == .browse ? .bold : .regular))
                                    .foregroundColor(joinMode == .browse ? .white : Color(hex: "94A3B8"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(joinMode == .browse ? Color(hex: "6366F1") : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            Button(action: { joinMode = .joinById }) {
                                Text("Join with ID")
                                    .font(.system(size: 12, weight: joinMode == .joinById ? .bold : .regular))
                                    .foregroundColor(joinMode == .joinById ? .white : Color(hex: "94A3B8"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(joinMode == .joinById ? Color(hex: "6366F1") : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            Button(action: { joinMode = .createRoom }) {
                                Text("+ Create")
                                    .font(.system(size: 12, weight: joinMode == .createRoom ? .bold : .regular))
                                    .foregroundColor(joinMode == .createRoom ? .white : Color(hex: "94A3B8"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(joinMode == .createRoom ? Color(hex: "6366F1") : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(3)
                        .background(Color(hex: "090D16"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        // Mode-Specific Fields
                        switch joinMode {
                        case .browse:
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Room:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "94A3B8"))

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(chatService.availableRooms) { r in
                                            let isSel = selectedRoom.id == r.id
                                            Text(r.name)
                                                .font(.system(size: 12, weight: isSel ? .bold : .regular))
                                                .foregroundColor(isSel ? .white : Color(hex: "94A3B8"))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(isSel ? Color(hex: "6366F1") : Color(hex: "090D16"))
                                                .clipShape(Capsule())
                                                .onTapGesture {
                                                    selectedRoom = r
                                                }
                                        }
                                    }
                                }
                            }

                        case .joinById:
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Enter Room ID or Code:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "94A3B8"))

                                TextField("e.g. AURA-4821 or room_global", text: $customRoomId)
                                    .autocapitalization(.allCharacters)
                                    .disableAutocorrection(true)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color(hex: "090D16"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                        case .createRoom:
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Group Name:")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "94A3B8"))

                                TextField("e.g. Late Night Squad", text: $newGroupName)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color(hex: "090D16"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text("Description (Optional):")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color(hex: "94A3B8"))

                                TextField("e.g. Vibes & Hip-Hop", text: $newGroupDesc)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color(hex: "090D16"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }

                        // Action Button
                        Button(action: {
                            guard !inputName.isEmpty && !inputDob.isEmpty else { return }

                            switch joinMode {
                            case .browse:
                                chatService.joinRoom(name: inputName, dob: inputDob, room: selectedRoom)
                            case .joinById:
                                _ = chatService.joinRoomById(name: inputName, dob: inputDob, roomId: customRoomId)
                            case .createRoom:
                                _ = chatService.createAndJoinRoom(
                                    userName: inputName,
                                    userDob: inputDob,
                                    roomName: newGroupName.isEmpty ? "Aura Lounge" : newGroupName,
                                    description: newGroupDesc
                                )
                            }
                        }) {
                            Text(joinMode == .createRoom ? "Create & Join Group 🚀" : "Enter Room 🚀")
                                .font(.system(size: 16, weight: .bold))
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
                        .disabled(inputName.isEmpty || inputDob.isEmpty)
                    }
                    .padding(20)
                    .background(Color(hex: "131824"))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 20)

                    Spacer().frame(height: 30)
                }
            }
            .background(Color(hex: "090D16").ignoresSafeArea())
        }
    }

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

                        // Play Now Button
                        Button(action: { player.playSong(song) }) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "090D16"))
                                .frame(width: 32, height: 32)
                                .background(Color(hex: "06B6D4"))
                                .clipShape(Circle())
                        }

                        // Play Next in Queue Button
                        Button(action: { player.playNext(song) }) {
                            Image(systemName: "text.line.first.and.arrowtriangle.forward")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .frame(width: 30, height: 30)
                                .background(Color(hex: "1E2536"))
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
                // Existing reaction badges
                ForEach(Array(msg.reactions.keys.sorted()), id: \.self) { emoji in
                    if let count = msg.reactions[emoji], count > 0 {
                        HStack(spacing: 3) {
                            Text(emoji)
                                .font(.system(size: 11))
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
}
