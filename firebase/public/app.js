// Firebase Configuration (Uses Realtime Database)
const firebaseConfig = {
  databaseURL: "https://linuxvm-d10a3-default-rtdb.firebaseio.com"
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

// Resilient Invidious Instances
const INVIDIOUS_ENDPOINTS = [
  "https://yt.chocolatemoo53.com"
];

// Curated Live Full Songs Feed (Guaranteed Full YouTube Songs with Zero Ads)
const FEATURED_TRACKS = [
  { id: "4NRXx6U8ABQ", title: "Blinding Lights", artist: "The Weeknd", album: "After Hours", durationText: "3:20", thumbnailUrl: "https://i.ytimg.com/vi/4NRXx6U8ABQ/hqdefault.jpg" },
  { id: "2Vv-BfVoq4g", title: "Perfect", artist: "Ed Sheeran", album: "÷ (Divide)", durationText: "4:23", thumbnailUrl: "https://i.ytimg.com/vi/2Vv-BfVoq4g/hqdefault.jpg" },
  { id: "60ItHLz5WEA", title: "Faded", artist: "Alan Walker", album: "Different World", durationText: "3:32", thumbnailUrl: "https://i.ytimg.com/vi/60ItHLz5WEA/hqdefault.jpg" },
  { id: "YykjpeuMNEk", title: "Hymn For The Weekend", artist: "Coldplay", album: "A Head Full of Dreams", durationText: "4:18", thumbnailUrl: "https://i.ytimg.com/vi/YykjpeuMNEk/hqdefault.jpg" },
  { id: "k4V3Mo61fJM", title: "Fix You", artist: "Coldplay", album: "X&Y", durationText: "4:55", thumbnailUrl: "https://i.ytimg.com/vi/k4V3Mo61fJM/hqdefault.jpg" },
  { id: "JGwWNGJdvx8", title: "Shape of You", artist: "Ed Sheeran", album: "÷ (Divide)", durationText: "3:53", thumbnailUrl: "https://i.ytimg.com/vi/JGwWNGJdvx8/hqdefault.jpg" },
  { id: "09R8_2nJtjg", title: "Sugar", artist: "Maroon 5", album: "V", durationText: "3:55", thumbnailUrl: "https://i.ytimg.com/vi/09R8_2nJtjg/hqdefault.jpg" },
  { id: "RgKAFK5djSk", title: "See You Again", artist: "Wiz Khalifa ft. Charlie Puth", album: "Furious 7", durationText: "3:49", thumbnailUrl: "https://i.ytimg.com/vi/RgKAFK5djSk/hqdefault.jpg" },
  { id: "hT_nvWreIhg", title: "Counting Stars", artist: "OneRepublic", album: "Native", durationText: "4:17", thumbnailUrl: "https://i.ytimg.com/vi/hT_nvWreIhg/hqdefault.jpg" },
  { id: "OPf0YbXqDm0", title: "Uptown Funk", artist: "Mark Ronson ft. Bruno Mars", album: "Uptown Special", durationText: "4:30", thumbnailUrl: "https://i.ytimg.com/vi/OPf0YbXqDm0/hqdefault.jpg" },
  { id: "3AtDnEC4zak", title: "We Don't Talk Anymore", artist: "Charlie Puth ft. Selena Gomez", album: "Nine Track Mind", durationText: "3:37", thumbnailUrl: "https://i.ytimg.com/vi/3AtDnEC4zak/hqdefault.jpg" },
  { id: "DkeiKbqa02g", title: "Summer", artist: "Calvin Harris", album: "Motion", durationText: "3:42", thumbnailUrl: "https://i.ytimg.com/vi/DkeiKbqa02g/hqdefault.jpg" },
  { id: "RBumgq5yVrA", title: "Let Her Go", artist: "Passenger", album: "All the Little Lights", durationText: "4:12", thumbnailUrl: "https://i.ytimg.com/vi/RBumgq5yVrA/hqdefault.jpg" },
  { id: "SmM0653kqRs", title: "Adventure Of A Lifetime", artist: "Coldplay", album: "A Head Full of Dreams", durationText: "4:24", thumbnailUrl: "https://i.ytimg.com/vi/SmM0653kqRs/hqdefault.jpg" },
  { id: "uelHwf8o7_U", title: "Love The Way You Lie", artist: "Eminem ft. Rihanna", album: "Recovery", durationText: "4:26", thumbnailUrl: "https://i.ytimg.com/vi/uelHwf8o7_U/hqdefault.jpg" }
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
  // Multi-Device Playback Sync & Room Chat
  deviceId: 'dev_' + Math.random().toString(36).substring(2, 10),
  roomSyncEnabled: true,
  currentProfile: null,
  currentRoom: { id: 'room_global', name: 'Global Music Lounge' },
  messages: []
};

// Background YouTube Player
let ytPlayer = null;
let ytReady = false;

window.onYouTubeIframeAPIReady = function() {
  ytPlayer = new YT.Player('ytPlayerContainer', {
    height: '1',
    width: '1',
    playerVars: {
      autoplay: 1,
      controls: 0,
      disablekb: 1,
      fs: 0,
      modestbranding: 1,
      playsinline: 1,
      rel: 0
    },
    events: {
      onReady: () => {
        ytReady = true;
        console.log("🎵 Full Song Background Player Engine Ready!");
      },
      onStateChange: (event) => {
        // YT.PlayerState: 1 = PLAYING, 2 = PAUSED, 0 = ENDED
        if (event.data === 1) {
          state.isPlaying = true;
          updatePlayButton(true);
          playerVisualizer.classList.add('playing');
        } else if (event.data === 2) {
          state.isPlaying = false;
          updatePlayButton(false);
          playerVisualizer.classList.remove('playing');
        } else if (event.data === 0) {
          skipNext();
        }
      }
    }
  });
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
const roomSyncToggleBtn = document.getElementById('roomSyncToggleBtn');
const roomSyncLabel = document.getElementById('roomSyncLabel');

// Init
window.addEventListener('DOMContentLoaded', () => {
  setupNavigation();
  setupAudioListeners();
  setupSearch();
  setupRoomChat();
  setupRoomSyncToggle();
  loadLiveTrending();
  startRoomSyncListener(state.currentRoom.id);
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

// Room Sync Toggle (Multi-Device Synchronized Playback)
function setupRoomSyncToggle() {
  if (roomSyncToggleBtn) {
    roomSyncToggleBtn.addEventListener('click', () => {
      state.roomSyncEnabled = !state.roomSyncEnabled;
      if (state.roomSyncEnabled) {
        roomSyncToggleBtn.classList.remove('off');
        if (roomSyncLabel) roomSyncLabel.innerText = 'Sync: ON';
        showToast('📻 Multi-Device Party Sync Enabled');
      } else {
        roomSyncToggleBtn.classList.add('off');
        if (roomSyncLabel) roomSyncLabel.innerText = 'Sync: OFF';
        showToast('Local Playback Mode');
      }
    });
  }
}

// Helper: Network Fetch with Timeout
function fetchWithTimeout(url, opts = {}, timeoutMs = 2800) {
  const controller = new AbortController();
  const id = setTimeout(() => controller.abort(), timeoutMs);
  return fetch(url, { ...opts, signal: controller.signal })
    .finally(() => clearTimeout(id));
}

// Live Music Fetcher (FULL SONGS from YouTube)
async function fetchTrendingTracks() {
  for (const base of INVIDIOUS_ENDPOINTS) {
    try {
      const res = await fetchWithTimeout(`${base}/api/v1/trending?type=music`, {}, 2500);
      if (res.ok) {
        const items = await res.json();
        if (Array.isArray(items) && items.length > 0) {
          const songs = parseInvidiousItems(items);
          if (songs.length > 0) return songs;
        }
      }
    } catch (_) {}
  }
  return FEATURED_TRACKS;
}

async function searchYouTubeMusic(query) {
  if (!query) return FEATURED_TRACKS;

  for (const base of INVIDIOUS_ENDPOINTS) {
    try {
      const res = await fetchWithTimeout(`${base}/api/v1/search?q=${encodeURIComponent(query)}&type=video`, {}, 3000);
      if (res.ok) {
        const items = await res.json();
        if (Array.isArray(items)) {
          const songs = parseInvidiousItems(items);
          if (songs.length > 0) return songs;
        }
      }
    } catch (_) {}
  }

  // Filter curated featured tracks by query as fallback
  const qLower = query.toLowerCase();
  const matched = FEATURED_TRACKS.filter(s => s.title.toLowerCase().includes(qLower) || s.artist.toLowerCase().includes(qLower));
  return matched.length > 0 ? matched : FEATURED_TRACKS;
}

function parseInvidiousItems(items) {
  return items.filter(i => (i.type === 'video' || i.videoId)).slice(0, 25).map(item => {
    const videoId = item.videoId || '';
    const durationSec = item.lengthSeconds || 210;
    const mins = Math.floor(durationSec / 60);
    const secs = String(durationSec % 60).padStart(2, '0');
    const thumb = item.videoThumbnails?.[0]?.url || `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
    return {
      id: videoId,
      title: item.title || 'Unknown Title',
      artist: item.author || 'YouTube Artist',
      album: 'YouTube Music',
      durationText: `${mins}:${secs}`,
      thumbnailUrl: thumb,
      durationSec: durationSec
    };
  }).filter(s => s.id);
}

async function getSearchSuggestions(query) {
  if (!query) return [];
  try {
    const res = await fetchWithTimeout(`https://suggestqueries.google.com/complete/search?client=firefox&ds=yt&q=${encodeURIComponent(query)}`, {}, 1500);
    if (res.ok) {
      const data = await res.json();
      if (data && data[1]) return data[1].slice(0, 8);
    }
  } catch (_) {}
  return [];
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
    const spotlight = songs[0];
    document.getElementById('spotlightTitle').innerText = spotlight.title;
    document.getElementById('spotlightArtist').innerText = spotlight.artist;
    document.getElementById('spotlightCard').style.backgroundImage = `linear-gradient(rgba(10,14,23,0.3), rgba(10,14,23,0.9)), url('${spotlight.thumbnailUrl}')`;
    document.getElementById('spotlightPlayBtn').onclick = () => playSong(spotlight);

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

    renderSongList(songs.slice(1), trendingList);
  }
}

document.getElementById('refreshTrendingBtn').addEventListener('click', loadLiveTrending);

// Render Song List
function renderSongList(songs, container) {
  container.innerHTML = '';
  if (!songs || songs.length === 0) {
    container.innerHTML = '<div style="text-align:center; padding: 40px; color: #94a3b8;">No songs found.</div>';
    return;
  }

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
      showToast(`Added to Play Next: "${song.title}"`);
    };

    row.querySelector('.share-chat-btn').onclick = (e) => {
      e.stopPropagation();
      document.querySelector('[data-view="chat"]').click();
      shareSongToChat(song);
    };

    container.appendChild(row);
  });
}

// FULL SONG PLAYBACK ENGINE
function playSong(song, shouldBroadcast = true) {
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

  // Play the COMPLETE, FULL YouTube Song
  if (ytPlayer && ytReady && ytPlayer.loadVideoById) {
    ytPlayer.loadVideoById(song.id);
    ytPlayer.playVideo();
    state.isPlaying = true;
    updatePlayButton(true);
    playerVisualizer.classList.add('playing');
  } else {
    // If iframe not ready yet, retry in 300ms
    setTimeout(() => playSong(song, false), 300);
  }

  // Multi-Device Room Sync Broadcast
  if (shouldBroadcast && state.roomSyncEnabled) {
    broadcastPlaybackSync({
      action: 'PLAY',
      song: song,
      positionSec: 0,
      isPlaying: true
    });
  }
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
  if (ytPlayer && ytReady && ytPlayer.getPlayerState) {
    const s = ytPlayer.getPlayerState();
    if (s === 1) { // Currently Playing -> Pause
      ytPlayer.pauseVideo();
      state.isPlaying = false;
      updatePlayButton(false);
      playerVisualizer.classList.remove('playing');
      if (state.roomSyncEnabled && state.currentSong) {
        broadcastPlaybackSync({
          action: 'PAUSE',
          song: state.currentSong,
          positionSec: ytPlayer.getCurrentTime(),
          isPlaying: false
        });
      }
    } else { // Paused -> Resume
      ytPlayer.playVideo();
      state.isPlaying = true;
      updatePlayButton(true);
      playerVisualizer.classList.add('playing');
      if (state.roomSyncEnabled && state.currentSong) {
        broadcastPlaybackSync({
          action: 'PLAY',
          song: state.currentSong,
          positionSec: ytPlayer.getCurrentTime(),
          isPlaying: true
        });
      }
    }
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

// Scrubbing & Position Update Listener
function setupAudioListeners() {
  // Update progress bar every 250ms with exact YouTube current time
  setInterval(() => {
    if (ytPlayer && ytReady && ytPlayer.getCurrentTime && state.isPlaying) {
      const cur = ytPlayer.getCurrentTime();
      const dur = ytPlayer.getDuration();
      if (dur > 0) {
        const pct = (cur / dur) * 100;
        scrubProgress.style.width = `${pct}%`;
      }
    }
  }, 250);

  // Exact Seeking / Scrubbing Sync across Multiple Devices
  document.querySelector('.scrub-container').addEventListener('click', (e) => {
    const rect = e.currentTarget.getBoundingClientRect();
    const pos = (e.clientX - rect.left) / rect.width;
    if (ytPlayer && ytReady && ytPlayer.getDuration) {
      const dur = ytPlayer.getDuration();
      if (dur > 0) {
        const targetSec = pos * dur;
        ytPlayer.seekTo(targetSec, true);
        if (state.roomSyncEnabled && state.currentSong) {
          broadcastPlaybackSync({
            action: 'SEEK',
            song: state.currentSong,
            positionSec: targetSec,
            isPlaying: state.isPlaying
          });
        }
      }
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

    clearTimeout(searchTimeout);
    searchTimeout = setTimeout(() => {
      doSearch(val || 'Top Hits');
    }, 350);
  });

  clearBtn.addEventListener('click', () => {
    input.value = '';
    clearBtn.style.display = 'none';
    suggestionsRow.style.display = 'none';
    doSearch('Top Hits');
  });

  async function doSearch(query) {
    if (!query) return;
    resultsList.innerHTML = '<div class="loader-spinner"></div>';
    const results = await searchYouTubeMusic(query);
    renderSongList(results, resultsList);
  }

  // Pre-load Search tab with curated full hits
  doSearch('Top Hits');

  document.querySelectorAll('#view-search .filter-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      document.querySelectorAll('#view-search .filter-chip').forEach(c => c.classList.remove('active'));
      chip.classList.add('active');
      const filter = chip.dataset.filter;
      input.value = filter;
      doSearch(filter);
    });
  });
}

// MULTI-DEVICE SYNCHRONIZED PLAYBACK ENGINE
// "sync both or multiple devices same time, Like if i'm on 1 min it'll be at 1 min in other phone too"
let sseSyncSource = null;

function broadcastPlaybackSync(payload) {
  if (!state.roomSyncEnabled || !state.currentRoom) return;

  const syncPacket = {
    type: 'SYNC_PLAYBACK',
    roomId: state.currentRoom.id,
    senderId: state.deviceId,
    senderName: state.currentProfile ? state.currentProfile.name : 'Aura User',
    action: payload.action, // 'PLAY', 'PAUSE', 'SEEK'
    song: payload.song,
    positionSec: payload.positionSec,
    isPlaying: payload.isPlaying,
    timestamp: Date.now()
  };

  // 1. Firebase Realtime Database
  if (db) {
    db.ref(`rooms/${state.currentRoom.id}/playback_sync`).set(syncPacket);
  }

  // 2. Real-Time PubSub SSE Relay
  try {
    fetch(`https://ntfy.sh/aura_music_sync_${state.currentRoom.id}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(syncPacket)
    }).catch(() => {});
  } catch (_) {}
}

function startRoomSyncListener(roomId) {
  if (sseSyncSource) sseSyncSource.close();

  // 1. Firebase RTDB
  if (db) {
    db.ref(`rooms/${roomId}/playback_sync`).on('value', snap => {
      const packet = snap.val();
      if (packet) applyIncomingSync(packet);
    });
  }

  // 2. SSE Relay
  try {
    sseSyncSource = new EventSource(`https://ntfy.sh/aura_music_sync_${roomId}/sse`);
    sseSyncSource.onmessage = (event) => {
      try {
        const raw = JSON.parse(event.data);
        const packet = typeof raw.message === 'string' ? JSON.parse(raw.message) : raw.message || raw;
        if (packet && packet.type === 'SYNC_PLAYBACK') {
          applyIncomingSync(packet);
        }
      } catch (_) {}
    };
  } catch (err) {
    console.log("SSE sync listener init:", err);
  }
}

function applyIncomingSync(packet) {
  if (!packet || !state.roomSyncEnabled || packet.senderId === state.deviceId) return;

  console.log("📻 Received multi-device sync packet:", packet);

  const now = Date.now();
  const latencySec = Math.max(0, (now - (packet.timestamp || now)) / 1000);
  const targetPos = packet.isPlaying ? (packet.positionSec + latencySec) : packet.positionSec;

  // If a different song is playing on the other device
  if (packet.song && (!state.currentSong || state.currentSong.id !== packet.song.id)) {
    playSong(packet.song, false);
    setTimeout(() => {
      if (ytPlayer && ytReady && ytPlayer.seekTo) {
        ytPlayer.seekTo(targetPos, true);
        if (packet.isPlaying) ytPlayer.playVideo();
        else ytPlayer.pauseVideo();
      }
    }, 500);
    return;
  }

  // If same song, seek if drift > 1.2s ("Like if i'm on 1 min it'll be at 1 min in other phone too")
  if (ytPlayer && ytReady && ytPlayer.getCurrentTime) {
    const cur = ytPlayer.getCurrentTime();
    if (Math.abs(cur - targetPos) > 1.2) {
      ytPlayer.seekTo(targetPos, true);
    }
    if (packet.isPlaying) {
      ytPlayer.playVideo();
      state.isPlaying = true;
      updatePlayButton(true);
      playerVisualizer.classList.add('playing');
    } else {
      ytPlayer.pauseVideo();
      state.isPlaying = false;
      updatePlayButton(false);
      playerVisualizer.classList.remove('playing');
    }
  }
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

  gateJoinBtn.addEventListener('click', () => {
    const name = gateNameInput.value.trim();
    const dob = gateDobInput.value;
    if (!name || !dob) {
      alert('Please enter both your Name and Date of Birth to enter the room.');
      return;
    }

    state.currentProfile = {
      userId: `user_${Date.now()}`,
      name: name,
      dob: dob
    };

    state.currentRoom = selectedRoomChoice;
    document.getElementById('currentRoomTitle').innerText = `#${state.currentRoom.name}`;
    document.getElementById('roomGateOverlay').style.display = 'none';

    listenToFirebaseRoom(state.currentRoom.id);
    startRoomSyncListener(state.currentRoom.id);
  });

  switchRoomBtn.addEventListener('click', () => {
    roomSwitcherTray.style.display = roomSwitcherTray.style.display === 'none' ? 'block' : 'none';
  });

  document.querySelectorAll('.room-switch-item').forEach(item => {
    item.addEventListener('click', () => {
      state.currentRoom = {
        id: item.dataset.room,
        name: item.innerText.replace('#', '').trim()
      };
      document.getElementById('currentRoomTitle').innerText = `#${state.currentRoom.name}`;
      roomSwitcherTray.style.display = 'none';
      listenToFirebaseRoom(state.currentRoom.id);
      startRoomSyncListener(state.currentRoom.id);
    });
  });

  toggleEmojiBtn.addEventListener('click', () => {
    emojiTray.style.display = emojiTray.style.display === 'none' ? 'flex' : 'none';
  });

  document.querySelectorAll('.emoji-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      chatMessageInput.value += btn.innerText;
      chatMessageInput.focus();
    });
  });

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

    if (db) {
      db.ref(`rooms/${state.currentRoom.id}/messages/${message.id}`).set(message);
    } else {
      appendChatMessage(message);
    }

    try {
      fetch(`https://ntfy.sh/aura_music_chat_${state.currentRoom.id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(message)
      }).catch(() => {});
    } catch (_) {}

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
    const msg = {
      id: `msg_${Date.now()}`,
      senderId: state.currentProfile.userId,
      senderName: state.currentProfile.name,
      text: `🎧 Check out this track: ${song.title}`,
      timestamp: Date.now(),
      sharedSong: song,
      reactions: { '🔥': 1 }
    };
    if (db) {
      db.ref(`rooms/${state.currentRoom.id}/messages/${msg.id}`).set(msg);
    }
    try {
      fetch(`https://ntfy.sh/aura_music_chat_${state.currentRoom.id}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(msg)
      }).catch(() => {});
    } catch (_) {}
  }
}

let sseChatSource = null;
function listenToFirebaseRoom(roomId) {
  const container = document.getElementById('chatMessagesContainer');
  container.innerHTML = '';

  if (sseChatSource) sseChatSource.close();

  if (db) {
    const roomRef = db.ref(`rooms/${roomId}/messages`).limitToLast(50);
    roomRef.off();
    roomRef.on('child_added', snapshot => {
      const msg = snapshot.val();
      appendChatMessage(msg);
    });
  } else {
    appendChatMessage({
      id: 'm_welcome',
      senderId: 'system',
      senderName: 'Aura Bot',
      text: `🎉 Welcome to #${state.currentRoom.name}! You are connected with other devices in synchronized party mode.`,
      timestamp: Date.now(),
      reactions: { '✨': 1 }
    });
  }

  try {
    sseChatSource = new EventSource(`https://ntfy.sh/aura_music_chat_${roomId}/sse`);
    sseChatSource.onmessage = (event) => {
      try {
        const raw = JSON.parse(event.data);
        const msg = typeof raw.message === 'string' ? JSON.parse(raw.message) : raw.message || raw;
        if (msg && msg.id) appendChatMessage(msg);
      } catch (_) {}
    };
  } catch (_) {}
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

function showToast(text) {
  const existing = document.getElementById('auraToast');
  if (existing) existing.remove();

  const toast = document.createElement('div');
  toast.id = 'auraToast';
  toast.style.cssText = `
    position: fixed;
    top: 70px;
    left: 50%;
    transform: translateX(-50%);
    background: rgba(15, 23, 42, 0.95);
    border: 1px solid rgba(6, 182, 212, 0.4);
    color: #e2e8f0;
    padding: 8px 16px;
    border-radius: 20px;
    font-size: 12px;
    font-weight: 600;
    z-index: 9999;
    box-shadow: 0 4px 16px rgba(0,0,0,0.4);
    pointer-events: none;
    transition: opacity 0.3s;
  `;
  toast.innerText = text;
  document.body.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    setTimeout(() => toast.remove(), 300);
  }, 2200);
}
