// Aura Music - Real-Time YouTube Music & Firebase Chat Engine

// Firebase Configuration (Uses Realtime Database)
const firebaseConfig = {
  databaseURL: "https://aura-music-app-default-rtdb.firebaseio.com"
};

let db = null;
try {
  if (typeof firebase !== 'undefined') {
    firebase.initializeApp(firebaseConfig);
    db = firebase.database();
  }
} catch (e) {
  console.log("Firebase initialized in local-first sync mode", e);
}

// Resilient ad-free Piped/Invidious endpoints
const API_ENDPOINTS = [
  "https://pipedapi.kavin.rocks",
  "https://api.piped.privacydev.net",
  "https://pipedapi.leptons.xyz",
  "https://piped-api.lunar.icu"
];

// App State
const state = {
  activeView: 'home',
  queue: [],
  currentIndex: 0,
  currentSong: null,
  isPlaying: false,
  favorites: new Set(),
  playlists: [],
  trendingSongs: [],
  // Room Chat
  currentProfile: null,
  currentRoom: { id: 'room_global', name: 'Global Music Lounge' },
  messages: []
};

// DOM Elements
const audio = document.getElementById('audioElement');
const playerBar = document.getElementById('playerBar');
const playerThumb = document.getElementById('playerThumb');
const playerTitle = document.getElementById('playerTitle');
const playerArtist = document.getElementById('playerArtist');
const playPauseBtn = document.getElementById('playPauseBtn');
const playIcon = document.getElementById('playIcon');
const pauseIcon = document.getElementById('pauseIcon');
const prevBtn = document.getElementById('prevBtn');
const nextBtn = document.getElementById('nextBtn');
const scrubProgress = document.getElementById('scrubProgress');
const playerVisualizer = document.getElementById('playerVisualizer');

// Init
window.addEventListener('DOMContentLoaded', () => {
  setupNavigation();
  setupAudioListeners();
  setupSearch();
  setupRoomChat();
  loadLiveTrending();
});

// Navigation
function setupNavigation() {
  document.querySelectorAll('.nav-item').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.nav-item').forEach(b => b.classList.remove('active'));
      document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));

      btn.classList.add('active');
      const viewId = btn.dataset.view;
      state.activeView = viewId;
      document.getElementById(`view-${viewId}`).classList.add('active');
    });
  });
}

// Live YouTube Music Fetcher
async function fetchTrendingTracks() {
  for (const base of API_ENDPOINTS) {
    try {
      const res = await fetch(`${base}/trending?region=US`);
      if (res.ok) {
        const items = await res.json();
        const songs = parsePipedItems(items);
        if (songs.length > 0) return songs;
      }
    } catch (_) {}
  }
  return searchYouTubeMusic("Top Music Hits");
}

async function searchYouTubeMusic(query) {
  if (!query) return [];
  for (const base of API_ENDPOINTS) {
    try {
      const res = await fetch(`${base}/search?q=${encodeURIComponent(query)}&filter=music_songs`);
      if (res.ok) {
        const json = await res.json();
        const songs = parsePipedItems(json.items || []);
        if (songs.length > 0) return songs;
      }
    } catch (_) {}
  }
  return [];
}

async function getSearchSuggestions(query) {
  if (!query) return [];
  try {
    const res = await fetch(`https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${encodeURIComponent(query)}`);
    if (res.ok) {
      const data = await res.json();
      if (data && data[1]) return data[1].slice(0, 8);
    }
  } catch (_) {}
  return [];
}

async function resolveAudioStream(videoId) {
  for (const base of API_ENDPOINTS) {
    try {
      const res = await fetch(`${base}/streams/${videoId}`);
      if (res.ok) {
        const json = await res.json();
        const streams = json.audioStreams || [];
        if (streams.length > 0) {
          // Find stream with highest bitrate
          streams.sort((a, b) => (b.bitrate || 0) - (a.bitrate || 0));
          return streams[0].url;
        }
      }
    } catch (_) {}
  }
  return `https://rr1---sn-uxa3-naxe.googlevideo.com/videoplayback?id=${videoId}`;
}

function parsePipedItems(items) {
  return items.slice(0, 25).map(item => {
    const videoId = (item.url || '').replace('/watch?v=', '').replace('/', '');
    const durationSec = item.duration || 210;
    const mins = Math.floor(durationSec / 60);
    const secs = String(durationSec % 60).padStart(2, '0');
    return {
      id: videoId,
      title: item.title || 'Unknown Title',
      artist: item.uploaderName || 'Unknown Artist',
      album: 'YouTube Music',
      durationText: `${mins}:${secs}`,
      thumbnailUrl: item.thumbnail || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`
    };
  }).filter(s => s.id);
}

// Load Live Trending Tracks
async function loadLiveTrending() {
  const trendingList = document.getElementById('trendingList');
  const topPicksRow = document.getElementById('topPicksRow');
  trendingList.innerHTML = '<div class="loader-spinner"></div>';
  topPicksRow.innerHTML = '<div class="loader-spinner"></div>';

  const songs = await fetchTrendingTracks();
  state.trendingSongs = songs;

  if (songs.length > 0) {
    // Set spotlight
    const spotlight = songs[0];
    document.getElementById('spotlightTitle').innerText = spotlight.title;
    document.getElementById('spotlightArtist').innerText = spotlight.artist;
    document.getElementById('spotlightCard').style.backgroundImage = `url('${spotlight.thumbnailUrl}')`;
    document.getElementById('spotlightPlayBtn').onclick = () => playSong(spotlight);

    // Top picks row
    topPicksRow.innerHTML = '';
    songs.slice(0, 10).forEach(song => {
      const card = document.createElement('div');
      card.className = 'pick-card';
      card.innerHTML = `
        <img src="${song.thumbnailUrl}" alt="${song.title}" loading="lazy">
        <h4>${song.title}</h4>
        <p>${song.artist}</p>
      `;
      card.onclick = () => playSong(song);
      topPicksRow.appendChild(card);
    });

    // Trending list
    renderSongList(songs.slice(1), trendingList);
  }
}

document.getElementById('refreshTrendingBtn').addEventListener('click', loadLiveTrending);

// Render Song Row
function renderSongList(songs, container) {
  container.innerHTML = '';
  songs.forEach(song => {
    const isPlayingThis = state.currentSong && state.currentSong.id === song.id;
    const isFav = state.favorites.has(song.id);

    const row = document.createElement('div');
    row.className = `song-row ${isPlayingThis ? 'playing' : ''}`;
    row.innerHTML = `
      <img src="${song.thumbnailUrl}" class="song-thumb" alt="${song.title}" loading="lazy">
      <div class="song-details">
        <div class="song-title">${song.title}</div>
        <div class="song-artist">${song.artist} • ${song.durationText}</div>
      </div>
      <div class="song-actions">
        <button class="btn-icon fav-btn" title="Favorite">${isFav ? '♥' : '♡'}</button>
        <button class="btn-icon play-next-btn" title="Play Next">⏭</button>
        <button class="btn-icon share-chat-btn" title="Share to Chat">💬</button>
      </div>
    `;

    row.querySelector('.song-details').onclick = () => playSong(song);
    row.querySelector('.song-thumb').onclick = () => playSong(song);

    row.querySelector('.fav-btn').onclick = (e) => {
      e.stopPropagation();
      toggleFavorite(song);
      renderSongList(songs, container);
    };

    row.querySelector('.play-next-btn').onclick = (e) => {
      e.stopPropagation();
      playNext(song);
      alert(`Queued next: "${song.title}"`);
    };

    row.querySelector('.share-chat-btn').onclick = (e) => {
      e.stopPropagation();
      document.querySelector('[data-view="chat"]').click();
      shareSongToChat(song);
    };

    container.appendChild(row);
  });
}

// Playback Engine
async function playSong(song) {
  state.currentSong = song;
  const existingIdx = state.queue.findIndex(s => s.id === song.id);
  if (existingIdx !== -1) {
    state.currentIndex = existingIdx;
  } else {
    state.queue.unshift(song);
    state.currentIndex = 0;
  }

  // Update UI
  playerBar.style.display = 'block';
  playerThumb.src = song.thumbnailUrl;
  playerTitle.innerText = song.title;
  playerArtist.innerText = song.artist;
  document.getElementById('shareSongTitle').innerText = song.title;
  document.getElementById('shareSongChip').style.display = 'block';

  // Resolve direct audio bitstream URL
  const streamUrl = await resolveAudioStream(song.id);
  audio.src = streamUrl;
  audio.play();
  state.isPlaying = true;
  updatePlayButton(true);
  playerVisualizer.classList.add('playing');
}

// User Requirement: Play Next
function playNext(song) {
  const existingIdx = state.queue.findIndex(s => s.id === song.id);
  if (existingIdx !== -1) state.queue.splice(existingIdx, 1);
  const insertIndex = Math.min(state.currentIndex + 1, state.queue.length);
  state.queue.splice(insertIndex, 0, song);
}

// User Requirement: Play Last
function playLast(song) {
  const existingIdx = state.queue.findIndex(s => s.id === song.id);
  if (existingIdx !== -1) state.queue.splice(existingIdx, 1);
  state.queue.push(song);
}

function togglePlayPause() {
  if (audio.paused) {
    audio.play();
    state.isPlaying = true;
    updatePlayButton(true);
    playerVisualizer.classList.add('playing');
  } else {
    audio.pause();
    state.isPlaying = false;
    updatePlayButton(false);
    playerVisualizer.classList.remove('playing');
  }
}

function updatePlayButton(isPlaying) {
  playIcon.style.display = isPlaying ? 'none' : 'block';
  pauseIcon.style.display = isPlaying ? 'block' : 'none';
}

function skipNext() {
  if (state.queue.length === 0) return;
  state.currentIndex = (state.currentIndex + 1) % state.queue.length;
  playSong(state.queue[state.currentIndex]);
}

function skipPrev() {
  if (state.queue.length === 0) return;
  state.currentIndex = (state.currentIndex - 1 + state.queue.length) % state.queue.length;
  playSong(state.queue[state.currentIndex]);
}

playPauseBtn.addEventListener('click', togglePlayPause);
nextBtn.addEventListener('click', skipNext);
prevBtn.addEventListener('click', skipPrev);

function setupAudioListeners() {
  audio.addEventListener('timeupdate', () => {
    if (audio.duration) {
      const pct = (audio.currentTime / audio.duration) * 100;
      scrubProgress.style.width = `${pct}%`;
    }
  });

  audio.addEventListener('ended', skipNext);

  document.querySelector('.scrub-container').addEventListener('click', (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const pos = (e.clientX - rect.left) / rect.width;
    if (audio.duration) {
      audio.currentTime = pos * audio.duration;
    }
  });
}

function toggleFavorite(song) {
  if (state.favorites.has(song.id)) {
    state.favorites.delete(song.id);
  } else {
    state.favorites.add(song.id);
  }
  document.getElementById('likedCountText').innerText = `${state.favorites.size} songs saved ad-free`;
}

// Live Search & Autocomplete
function setupSearch() {
  const input = document.getElementById('searchInput');
  const clearBtn = document.getElementById('clearSearchBtn');
  const suggestionsRow = document.getElementById('suggestionsRow');
  const resultsList = document.getElementById('searchResultsList');

  let searchTimeout = null;
  let suggestTimeout = null;

  input.addEventListener('input', () => {
    const val = input.value.trim();
    clearBtn.style.display = val ? 'block' : 'none';

    // Autocomplete Suggestions
    clearTimeout(suggestTimeout);
    if (val) {
      suggestTimeout = setTimeout(async () => {
        const suggestions = await getSearchSuggestions(val);
        if (suggestions.length > 0) {
          suggestionsRow.style.display = 'flex';
          suggestionsRow.innerHTML = '';
          suggestions.forEach(item => {
            const chip = document.createElement('button');
            chip.className = 'filter-chip';
            chip.innerText = `↗ ${item}`;
            chip.onclick = () => {
              input.value = item;
              suggestionsRow.style.display = 'none';
              doSearch(item);
            };
            suggestionsRow.appendChild(chip);
          });
        } else {
          suggestionsRow.style.display = 'none';
        }
      }, 150);
    } else {
      suggestionsRow.style.display = 'none';
    }

    // Live search
    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      doSearch(val);
    }, 350);
  });

  clearBtn.addEventListener('click', () => {
    input.value = '';
    clearBtn.style.display = 'none';
    suggestionsRow.style.display = 'none';
    resultsList.innerHTML = '';
  });

  async function doSearch(query) {
    if (!query) {
      resultsList.innerHTML = '';
      return;
    }
    resultsList.innerHTML = '<div class="loader-spinner"></div>';
    const results = await searchYouTubeMusic(query);
    renderSongList(results, resultsList);
  }

  // Filter chips
  document.querySelectorAll('#view-search .filter-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('#view-search .filter-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      const filter = chip.dataset.filter;
      if (filter !== 'All') {
        input.value = filter;
        doSearch(filter);
      }
    });
  });
}

// Real-Time Firebase Room Chat
function setupRoomChat() {
  const gateJoinBtn = document.getElementById('gateJoinBtn');
  const gateNameInput = document.getElementById('gateNameInput');
  const gateDobInput = document.getElementById('gateDobInput');
  const switchRoomBtn = document.getElementById('switchRoomBtn');
  const roomSwitcherTray = document.getElementById('roomSwitcherTray');
  const toggleEmojiBtn = document.getElementById('toggleEmojiBtn');
  const emojiTray = document.getElementById('emojiTray');
  const sendChatBtn = document.getElementById('sendChatBtn');
  const chatMessageInput = document.getElementById('chatMessageInput');
  const shareSongChip = document.getElementById('shareSongChip');

  // Room gate selection
  let selectedRoomChoice = { id: 'room_global', name: 'Global Music Lounge' };
  document.querySelectorAll('.gate-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('.gate-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      selectedRoomChoice = {
        id: chip.dataset.room,
        name: chip.innerText.replace('#', '')
      };
    });
  });

  // User requirement: Just enter Name and DOB to enter room
  gateJoinBtn.addEventListener('click', () => {
    const name = gateNameInput.value.trim();
    const dob = gateDobInput.value.trim();
    if (!name || !dob) {
      alert("Please enter both Name and Date of Birth (DOB) to join!");
      return;
    }

    state.currentProfile = {
      name,
      dob,
      userId: `user_${name.toLowerCase().replace(/\s+/g, '_')}_${dob.replace(/[\/\-]/g, '')}`
    };
    state.currentRoom = selectedRoomChoice;

    document.getElementById('roomGate').style.display = 'none';
    document.getElementById('roomHeaderBar').style.display = 'flex';
    document.getElementById('chatMessagesContainer').style.display = 'flex';
    document.getElementById('chatInputBar').style.display = 'block';

    document.getElementById('activeRoomName').innerText = state.currentRoom.name;
    document.getElementById('activeProfileText').innerText = `Joined as ${name} • Firebase Realtime DB`;

    listenToFirebaseRoom(state.currentRoom.id);
  });

  // Room switcher tray
  switchRoomBtn.addEventListener('click', () => {
    roomSwitcherTray.style.display = roomSwitcherTray.style.display === 'none' ? 'flex' : 'none';
  });

  document.querySelectorAll('.room-pill').forEach(pill => {
    pill.addEventListener('click', () => {
      document.querySelectorAll('.room-pill').forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
      state.currentRoom = {
        id: pill.dataset.room,
        name: pill.innerText
      };
      document.getElementById('activeRoomName').innerText = state.currentRoom.name;
      roomSwitcherTray.style.display = 'none';
      listenToFirebaseRoom(state.currentRoom.id);
    });
  });

  // Emojis
  toggleEmojiBtn.addEventListener('click', () => {
    emojiTray.style.display = emojiTray.style.display === 'none' ? 'flex' : 'none';
  });

  document.querySelectorAll('.emoji-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      chatMessageInput.value += btn.innerText;
      chatMessageInput.focus();
    });
  });

  // Send message
  function sendMsg(sharedSong = null) {
    const text = chatMessageInput.value.trim();
    if (!text && !sharedSong) return;

    const message = {
      id: `msg_${Date.now()}`,
      senderId: state.currentProfile.userId,
      senderName: state.currentProfile.name,
      text: text,
      timestamp: Date.now(),
      sharedSong: sharedSong,
      reactions: {}
    };

    // Save to Firebase
    if (db) {
      db.ref(`rooms/${state.currentRoom.id}/messages/${message.id}`).set(message);
    } else {
      appendChatMessage(message);
    }

    chatMessageInput.value = '';
  }

  sendChatBtn.addEventListener('click', () => sendMsg());
  chatMessageInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') sendMsg();
  });

  shareSongChip.addEventListener('click', () => {
    if (state.currentSong) {
      sendMsg(state.currentSong);
    }
  });
}

function shareSongToChat(song) {
  if (state.currentProfile) {
    if (db) {
      const msg = {
        id: `msg_${Date.now()}`,
        senderId: state.currentProfile.userId,
        senderName: state.currentProfile.name,
        text: `🎧 Check out this live song: ${song.title}`,
        timestamp: Date.now(),
        sharedSong: song,
        reactions: { '🔥': 1 }
      };
      db.ref(`rooms/${state.currentRoom.id}/messages/${msg.id}`).set(msg);
    }
  }
}

function listenToFirebaseRoom(roomId) {
  const container = document.getElementById('chatMessagesContainer');
  container.innerHTML = '';

  if (db) {
    const roomRef = db.ref(`rooms/${roomId}/messages`).limitToLast(50);
    roomRef.off();
    roomRef.on('child_added', snapshot => {
      const msg = snapshot.val();
      appendChatMessage(msg);
    });
  } else {
    // Local demo message
    appendChatMessage({
      id: 'm_welcome',
      senderId: 'system',
      senderName: 'Aura Bot',
      text: `🎉 Welcome to #${state.currentRoom.name}! Share any YouTube Music song live or react with emojis.`,
      timestamp: Date.now(),
      reactions: { '✨': 1 }
    });
  }
}

function appendChatMessage(msg) {
  const container = document.getElementById('chatMessagesContainer');
  if (document.getElementById(msg.id)) return;

  const isMe = state.currentProfile && msg.senderId === state.currentProfile.userId;
  const wrapper = document.createElement('div');
  wrapper.id = msg.id;
  wrapper.className = `message-bubble-wrapper ${isMe ? 'me' : 'other'}`;

  let innerHTML = '';
  if (!isMe && msg.senderName) {
    innerHTML += `<div class="message-sender">${msg.senderName}</div>`;
  }

  innerHTML += `<div class="message-bubble">${msg.text || ''}`;

  if (msg.sharedSong) {
    innerHTML += `
      <div class="shared-song-card">
        <img src="${msg.sharedSong.thumbnailUrl}" alt="${msg.sharedSong.title}">
        <div class="song-details">
          <div class="song-title">${msg.sharedSong.title}</div>
          <div class="song-artist">${msg.sharedSong.artist}</div>
        </div>
        <button class="btn-icon play-shared-btn" style="color: var(--accent-color); font-size: 20px;">▶</button>
      </div>
    `;
  }

  innerHTML += `</div>`;

  // Reactions
  innerHTML += `<div class="reactions-row" id="reactions_${msg.id}">`;
  if (msg.reactions) {
    Object.entries(msg.reactions).forEach(([emoji, count]) => {
      innerHTML += `<span class="reaction-pill">${emoji} ${count}</span>`;
    });
  }
  innerHTML += `</div>`;

  wrapper.innerHTML = innerHTML;

  if (msg.sharedSong) {
    wrapper.querySelector('.play-shared-btn').onclick = () => playSong(msg.sharedSong);
  }

  // Tap to add reaction
  wrapper.querySelector('.message-bubble').onclick = () => {
    addReaction(msg.id, '❤️');
  };

  container.appendChild(wrapper);
  container.scrollTop = container.scrollHeight;
}

function addReaction(messageId, emoji) {
  if (db && state.currentRoom) {
    const reactionRef = db.ref(`rooms/${state.currentRoom.id}/messages/${messageId}/reactions/${emoji}`);
    reactionRef.transaction(current => (current || 0) + 1);
  }
}
