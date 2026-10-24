import SwiftUI

public struct ChatView: View {
    @ObservedObject var chatService = ChatService.shared
    @ObservedObject var player = AudioPlayerService.shared

    @State private var inputName: String = ""
    @State private var inputDob: String = ""
    @State private var selectedRoom: ChatRoom = ChatService.shared.defaultRooms[0]

    @State private var textInput: String = ""
    @State private var showEmojiBar: Bool = false
    @State private var showRoomSwitchBar: Bool = false
    @State private var selectedMessageForReaction: String? = nil

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
                            Text("\(profile.name) • \(chatService.currentRoom.description)")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "64748B"))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button(action: { showRoomSwitchBar.toggle() }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(hex: "06B6D4"))
                                .frame(width: 34, height: 34)
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "icloud.and.arrow.up.fill")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "06B6D4"))
                            Text("Firebase")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Color(hex: "06B6D4"))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(hex: "6366F1").opacity(0.2))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)

                    // Room Switcher Pill list
                    if showRoomSwitchBar {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(chatService.defaultRooms) { room in
                                    let isCurrent = chatService.currentRoom.id == room.id
                                    Text(room.name)
                                        .font(.system(size: 12, weight: isCurrent ? .bold : .regular))
                                        .foregroundColor(isCurrent ? .white : Color(hex: "94A3B8"))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(isCurrent ? Color(hex: "6366F1") : Color(hex: "131824"))
                                        .clipShape(Capsule())
                                        .onTapGesture {
                                            chatService.switchRoom(room)
                                            showRoomSwitchBar = false
                                        }
                                }
                            }
                            .padding(.horizontal, 20)
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
            // Join Room Gateway (Name and DOB)
            VStack {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "person.2.badge.gearshape.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(hex: "06B6D4"))
                        .frame(width: 70, height: 70)
                        .background(Color(hex: "6366F1").opacity(0.2))
                        .clipShape(Circle())

                    Text("Join Music Chat Room")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Text("Enter your Name and DOB to chat in real time with other listeners.")
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "64748B"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

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

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Select Room:")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "94A3B8"))

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(chatService.defaultRooms) { r in
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

                    Button(action: {
                        if !inputName.isEmpty && !inputDob.isEmpty {
                            chatService.joinRoom(name: inputName, dob: inputDob, room: selectedRoom)
                        }
                    }) {
                        Text("Enter Room 🚀")
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
                .padding(24)
                .background(Color(hex: "131824"))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)

                Spacer()
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
            .onTapGesture {
                selectedMessageForReaction = (selectedMessageForReaction == msg.id) ? nil : msg.id
            }

            // Reactions Row
            if !msg.reactions.isEmpty {
                HStack(spacing: 4) {
                    ForEach(Array(msg.reactions.keys.sorted()), id: \.self) { emoji in
                        if let count = msg.reactions[emoji] {
                            HStack(spacing: 2) {
                                Text(emoji)
                                    .font(.system(size: 11))
                                Text("\(count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(hex: "1E2536"))
                            .clipShape(Capsule())
                            .onTapGesture {
                                chatService.addReaction(to: msg.id, emoji: emoji)
                            }
                        }
                    }
                }
            }

            // Quick Reaction Menu when tapped
            if selectedMessageForReaction == msg.id {
                HStack(spacing: 6) {
                    ForEach(["❤️", "🔥", "🎧", "👏", "😂", "🚀"], id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 18))
                            .onTapGesture {
                                chatService.addReaction(to: msg.id, emoji: emoji)
                                selectedMessageForReaction = nil
                            }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "1E2536"))
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: isMe ? .trailing : .leading)
    }
}
