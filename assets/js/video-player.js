/**
 * AI KINGS Video Player
 * Custom video player wrapper with playlist and fullscreen support
 */

class AIKingsVideoPlayer {
  constructor(options = {}) {
    this.player = null;
    this.currentVideo = null;
    this.playlist = [];
    this.currentIndex = 0;
    this.isFullscreen = false;
    this.relatedVideos = [];
    this.options = {
      autoplay: false,
      controls: true,
      preload: 'metadata',
      ...options
    };

    this.init();
  }

  init() {
    this.setupPlayerContainer();
    this.bindEvents();
  }

  setupPlayerContainer() {
    // Create player container if it doesn't exist
    if (!document.getElementById('ai-kings-player-container')) {
      const container = document.createElement('div');
      container.id = 'ai-kings-player-container';
      container.className = 'ai-kings-player-container';
      container.innerHTML = `
        <div class="player-wrapper">
          <div id="ai-kings-video-player" class="ai-kings-video-player"></div>
          <div class="player-overlay">
            <div class="play-button-overlay">
              <button class="big-play-button" aria-label="Play Video">
                <svg viewBox="0 0 24 24" width="48" height="48">
                  <path d="M8 5v14l11-7z" fill="currentColor"/>
                </svg>
              </button>
            </div>
          </div>
        </div>
        <div class="player-controls">
          <div class="progress-bar">
            <div class="progress-fill"></div>
            <div class="progress-handle"></div>
          </div>
          <div class="controls-row">
            <div class="left-controls">
              <button class="control-btn play-pause-btn" aria-label="Play/Pause">
                <svg class="play-icon" viewBox="0 0 24 24" width="24" height="24">
                  <path d="M8 5v14l11-7z" fill="currentColor"/>
                </svg>
                <svg class="pause-icon" viewBox="0 0 24 24" width="24" height="24" style="display: none;">
                  <path d="M6 19h4V5H6v14zm8-14v14h4V5h-4z" fill="currentColor"/>
                </svg>
              </button>
              <button class="control-btn prev-btn" aria-label="Previous Video">
                <svg viewBox="0 0 24 24" width="20" height="20">
                  <path d="M6 6h2v12H6zm3.5 6l8.5 6V6z" fill="currentColor"/>
                </svg>
              </button>
              <button class="control-btn next-btn" aria-label="Next Video">
                <svg viewBox="0 0 24 24" width="20" height="20">
                  <path d="M6 18l8.5-6L6 6v12zM16 5v14h2V5h-2z" fill="currentColor"/>
                </svg>
              </button>
              <div class="volume-control">
                <button class="control-btn volume-btn" aria-label="Volume">
                  <svg class="volume-high-icon" viewBox="0 0 24 24" width="20" height="20">
                    <path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z" fill="currentColor"/>
                  </svg>
                  <svg class="volume-muted-icon" viewBox="0 0 24 24" width="20" height="20" style="display: none;">
                    <path d="M16.5 12c0-1.77-1.02-3.29-2.5-4.03v2.21l2.45 2.45c.03-.2.05-.41.05-.63zm2.5 0c0 .94-.2 1.82-.54 2.64l1.51 1.51C20.63 14.91 21 13.5 21 12c0-4.28-2.99-7.86-7-8.77v2.06c2.89.86 5 3.54 5 6.71zM4.27 3L3 4.27 7.73 9H3v6h4l5 5v-6.73l4.25 4.25c-.67.52-1.42.93-2.25 1.18v2.06c1.38-.31 2.63-.95 3.69-1.81L19.73 21 21 19.73l-9-9L4.27 3zM12 4L9.91 6.09 12 8.18V4z" fill="currentColor"/>
                  </svg>
                </button>
                <div class="volume-slider">
                  <div class="volume-fill"></div>
                  <div class="volume-handle"></div>
                </div>
              </div>
              <div class="time-display">
                <span class="current-time">0:00</span>
                <span class="time-separator">/</span>
                <span class="duration">0:00</span>
              </div>
            </div>
            <div class="right-controls">
              <div class="quality-selector">
                <button class="control-btn quality-btn" aria-label="Quality">HD</button>
              </div>
              <button class="control-btn fullscreen-btn" aria-label="Fullscreen">
                <svg viewBox="0 0 24 24" width="20" height="20">
                  <path d="M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z" fill="currentColor"/>
                </svg>
              </button>
            </div>
          </div>
        </div>
        <div class="playlist-panel">
          <div class="playlist-header">
            <h3>Playlist</h3>
            <button class="playlist-toggle" aria-label="Toggle Playlist">
              <svg viewBox="0 0 24 24" width="20" height="20">
                <path d="M7 14l5-5 5 5z" fill="currentColor"/>
              </svg>
            </button>
          </div>
          <div class="playlist-content">
            <div class="playlist-items"></div>
          </div>
        </div>
        <div class="related-videos-panel">
          <div class="related-header">
            <h3>Related Videos</h3>
          </div>
          <div class="related-content">
            <div class="related-items"></div>
          </div>
        </div>
      `;
      document.body.appendChild(container);
    }
  }

  loadVideo(videoData, playlist = []) {
    this.currentVideo = videoData;
    this.playlist = playlist;
    this.currentIndex = playlist.findIndex(v => v.id === videoData.id);

    this.updatePlayerUI();
    this.updatePlaylist();
    this.loadRelatedVideos();

    // Initialize JW Player or HTML5 video
    this.initializePlayer();
  }

  initializePlayer() {
    const playerContainer = document.getElementById('ai-kings-video-player');

    // Check if JW Player is available
    if (typeof jwplayer !== 'undefined') {
      this.initializeJWPlayer(playerContainer);
    } else {
      this.initializeHTML5Player(playerContainer);
    }
  }

  initializeJWPlayer(container) {
    this.player = jwplayer(container).setup({
      file: this.currentVideo.videoUrl,
      image: this.currentVideo.thumbnail,
      title: this.currentVideo.title,
      description: this.currentVideo.description,
      width: '100%',
      height: '100%',
      aspectratio: '16:9',
      controls: false, // We'll use custom controls
      preload: this.options.preload,
      autostart: this.options.autoplay,
      primary: 'html5',
      hlshtml: true,
      playbackRateControls: true,
      playbackRates: [0.5, 1, 1.25, 1.5, 2]
    });

    this.bindJWPlayerEvents();
  }

  initializeHTML5Player(container) {
    container.innerHTML = `
      <video id="ai-kings-html5-player" controls preload="${this.options.preload}">
        <source src="${this.currentVideo.videoUrl}" type="video/mp4">
        Your browser does not support the video tag.
      </video>
    `;

    this.player = document.getElementById('ai-kings-html5-player');
    this.bindHTML5PlayerEvents();
  }

  bindJWPlayerEvents() {
    if (!this.player) return;

    this.player.on('ready', () => {
      this.onPlayerReady();
    });

    this.player.on('play', () => {
      this.onPlay();
    });

    this.player.on('pause', () => {
      this.onPause();
    });

    this.player.on('time', (e) => {
      this.onTimeUpdate(e.position, e.duration);
    });

    this.player.on('complete', () => {
      this.onComplete();
    });

    this.player.on('error', (e) => {
      this.onError(e);
    });
  }

  bindHTML5PlayerEvents() {
    if (!this.player) return;

    this.player.addEventListener('loadedmetadata', () => {
      this.onPlayerReady();
    });

    this.player.addEventListener('play', () => {
      this.onPlay();
    });

    this.player.addEventListener('pause', () => {
      this.onPause();
    });

    this.player.addEventListener('timeupdate', () => {
      this.onTimeUpdate(this.player.currentTime, this.player.duration);
    });

    this.player.addEventListener('ended', () => {
      this.onComplete();
    });

    this.player.addEventListener('error', (e) => {
      this.onError(e);
    });
  }

  bindEvents() {
    // Custom control events
    this.bindControlEvents();

    // Keyboard shortcuts
    document.addEventListener('keydown', (e) => this.handleKeyboard(e));
  }

  bindControlEvents() {
    const controls = document.querySelector('.player-controls');

    // Play/Pause
    controls.querySelector('.play-pause-btn').addEventListener('click', () => {
      this.togglePlayPause();
    });

    // Previous/Next
    controls.querySelector('.prev-btn').addEventListener('click', () => {
      this.playPrevious();
    });

    controls.querySelector('.next-btn').addEventListener('click', () => {
      this.playNext();
    });

    // Progress bar
    const progressBar = controls.querySelector('.progress-bar');
    progressBar.addEventListener('click', (e) => {
      this.seekToPosition(e);
    });

    // Volume
    controls.querySelector('.volume-btn').addEventListener('click', () => {
      this.toggleMute();
    });

    const volumeSlider = controls.querySelector('.volume-slider');
    volumeSlider.addEventListener('click', (e) => {
      this.setVolume(e);
    });

    // Fullscreen
    controls.querySelector('.fullscreen-btn').addEventListener('click', () => {
      this.toggleFullscreen();
    });

    // Quality selector
    controls.querySelector('.quality-btn').addEventListener('click', () => {
      this.showQualityMenu();
    });

    // Playlist toggle
    document.querySelector('.playlist-toggle').addEventListener('click', () => {
      this.togglePlaylist();
    });
  }

  handleKeyboard(e) {
    if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA') return;

    switch (e.key.toLowerCase()) {
      case ' ':
      case 'k':
        e.preventDefault();
        this.togglePlayPause();
        break;
      case 'arrowleft':
        e.preventDefault();
        this.seekBackward(10);
        break;
      case 'arrowright':
        e.preventDefault();
        this.seekForward(10);
        break;
      case 'arrowup':
        e.preventDefault();
        this.increaseVolume();
        break;
      case 'arrowdown':
        e.preventDefault();
        this.decreaseVolume();
        break;
      case 'm':
        e.preventDefault();
        this.toggleMute();
        break;
      case 'f':
        e.preventDefault();
        this.toggleFullscreen();
        break;
      case 'c':
        e.preventDefault();
        this.toggleCaptions();
        break;
    }
  }

  // Player control methods
  togglePlayPause() {
    if (this.player) {
      if (this.isJWPlayer()) {
        const state = this.player.getState();
        if (state === 'playing') {
          this.player.pause();
        } else {
          this.player.play();
        }
      } else {
        if (this.player.paused) {
          this.player.play();
        } else {
          this.player.pause();
        }
      }
    }
  }

  playPrevious() {
    if (this.currentIndex > 0) {
      this.loadVideo(this.playlist[this.currentIndex - 1], this.playlist);
    }
  }

  playNext() {
    if (this.currentIndex < this.playlist.length - 1) {
      this.loadVideo(this.playlist[this.currentIndex + 1], this.playlist);
    } else {
      // Auto-play related video or loop
      if (this.relatedVideos.length > 0) {
        this.loadVideo(this.relatedVideos[0]);
      }
    }
  }

  seekToPosition(e) {
    const progressBar = e.currentTarget;
    const rect = progressBar.getBoundingClientRect();
    const percent = (e.clientX - rect.left) / rect.width;

    if (this.isJWPlayer()) {
      const duration = this.player.getDuration();
      this.player.seek(duration * percent);
    } else {
      const duration = this.player.duration;
      this.player.currentTime = duration * percent;
    }
  }

  toggleMute() {
    if (this.isJWPlayer()) {
      const muted = this.player.getMute();
      this.player.setMute(!muted);
    } else {
      this.player.muted = !this.player.muted;
    }
    this.updateVolumeUI();
  }

  setVolume(e) {
    const volumeSlider = e.currentTarget;
    const rect = volumeSlider.getBoundingClientRect();
    const percent = (e.clientX - rect.left) / rect.width;
    const volume = Math.max(0, Math.min(1, percent));

    if (this.isJWPlayer()) {
      this.player.setVolume(volume * 100);
    } else {
      this.player.volume = volume;
    }
    this.updateVolumeUI();
  }

  increaseVolume() {
    const currentVolume = this.isJWPlayer() ? this.player.getVolume() / 100 : this.player.volume;
    const newVolume = Math.min(1, currentVolume + 0.1);
    this.setVolumeValue(newVolume);
  }

  decreaseVolume() {
    const currentVolume = this.isJWPlayer() ? this.player.getVolume() / 100 : this.player.volume;
    const newVolume = Math.max(0, currentVolume - 0.1);
    this.setVolumeValue(newVolume);
  }

  setVolumeValue(volume) {
    if (this.isJWPlayer()) {
      this.player.setVolume(volume * 100);
    } else {
      this.player.volume = volume;
    }
    this.updateVolumeUI();
  }

  seekForward(seconds) {
    if (this.isJWPlayer()) {
      const currentTime = this.player.getPosition();
      this.player.seek(currentTime + seconds);
    } else {
      this.player.currentTime += seconds;
    }
  }

  seekBackward(seconds) {
    if (this.isJWPlayer()) {
      const currentTime = this.player.getPosition();
      this.player.seek(Math.max(0, currentTime - seconds));
    } else {
      this.player.currentTime = Math.max(0, this.player.currentTime - seconds);
    }
  }

  toggleFullscreen() {
    const container = document.getElementById('ai-kings-player-container');

    if (!document.fullscreenElement) {
      container.requestFullscreen().then(() => {
        this.isFullscreen = true;
        this.updateFullscreenUI();
      });
    } else {
      document.exitFullscreen().then(() => {
        this.isFullscreen = false;
        this.updateFullscreenUI();
      });
    }
  }

  showQualityMenu() {
    // Implement quality selection menu
    console.log('Quality menu not implemented yet');
  }

  toggleCaptions() {
    // Implement captions toggle
    console.log('Captions toggle not implemented yet');
  }

  togglePlaylist() {
    const playlist = document.querySelector('.playlist-panel');
    playlist.classList.toggle('open');
  }

  // Event handlers
  onPlayerReady() {
    this.updateDuration();
    this.updateVolumeUI();
  }

  onPlay() {
    this.updatePlayPauseUI(true);
    document.querySelector('.play-button-overlay').style.display = 'none';
  }

  onPause() {
    this.updatePlayPauseUI(false);
    document.querySelector('.play-button-overlay').style.display = 'flex';
  }

  onTimeUpdate(currentTime, duration) {
    this.updateProgressBar(currentTime, duration);
    this.updateTimeDisplay(currentTime, duration);
  }

  onComplete() {
    // Auto-play next video or show related videos
    setTimeout(() => {
      this.playNext();
    }, 3000);
  }

  onError(error) {
    console.error('Video player error:', error);
    this.showError('Failed to load video. Please try again.');
  }

  // UI update methods
  updatePlayerUI() {
    document.title = `${this.currentVideo.title} - AI KINGS`;
    // Update video info displays
  }

  updatePlayPauseUI(isPlaying) {
    const playIcon = document.querySelector('.play-icon');
    const pauseIcon = document.querySelector('.pause-icon');

    if (isPlaying) {
      playIcon.style.display = 'none';
      pauseIcon.style.display = 'block';
    } else {
      playIcon.style.display = 'block';
      pauseIcon.style.display = 'none';
    }
  }

  updateProgressBar(currentTime, duration) {
    if (duration > 0) {
      const percent = (currentTime / duration) * 100;
      document.querySelector('.progress-fill').style.width = `${percent}%`;
    }
  }

  updateTimeDisplay(currentTime, duration) {
    document.querySelector('.current-time').textContent = this.formatTime(currentTime);
    document.querySelector('.duration').textContent = this.formatTime(duration);
  }

  updateVolumeUI() {
    const volume = this.isJWPlayer() ? this.player.getVolume() / 100 : this.player.volume;
    const isMuted = this.isJWPlayer() ? this.player.getMute() : this.player.muted;

    document.querySelector('.volume-fill').style.width = `${volume * 100}%`;

    const highIcon = document.querySelector('.volume-high-icon');
    const mutedIcon = document.querySelector('.volume-muted-icon');

    if (isMuted || volume === 0) {
      highIcon.style.display = 'none';
      mutedIcon.style.display = 'block';
    } else {
      highIcon.style.display = 'block';
      mutedIcon.style.display = 'none';
    }
  }

  updateDuration() {
    if (this.isJWPlayer()) {
      const duration = this.player.getDuration();
      document.querySelector('.duration').textContent = this.formatTime(duration);
    } else {
      document.querySelector('.duration').textContent = this.formatTime(this.player.duration);
    }
  }

  updateFullscreenUI() {
    const btn = document.querySelector('.fullscreen-btn');
    // Update fullscreen button icon based on state
  }

  updatePlaylist() {
    const playlistItems = document.querySelector('.playlist-items');
    playlistItems.innerHTML = this.playlist.map((video, index) => `
      <div class="playlist-item ${index === this.currentIndex ? 'active' : ''}"
           data-video-id="${video.id}">
        <div class="playlist-thumbnail">
          <img src="${video.thumbnail}" alt="${video.title}">
        </div>
        <div class="playlist-info">
          <div class="playlist-title">${video.title}</div>
          <div class="playlist-meta">${video.duration}</div>
        </div>
      </div>
    `).join('');

    // Bind playlist item clicks
    playlistItems.querySelectorAll('.playlist-item').forEach(item => {
      item.addEventListener('click', () => {
        const videoId = item.dataset.videoId;
        const video = this.playlist.find(v => v.id === videoId);
        if (video) {
          this.loadVideo(video, this.playlist);
        }
      });
    });
  }

  loadRelatedVideos() {
    // Load related videos based on current video's category and tags
    // For now, just show some videos from the same category
    this.relatedVideos = window.aiKingsApp?.videoData?.videos
      .filter(video => video.category === this.currentVideo.category && video.id !== this.currentVideo.id)
      .slice(0, 6) || [];

    this.updateRelatedVideos();
  }

  updateRelatedVideos() {
    const relatedItems = document.querySelector('.related-items');
    relatedItems.innerHTML = this.relatedVideos.map(video => `
      <div class="related-item" data-video-id="${video.id}">
        <div class="related-thumbnail">
          <img src="${video.thumbnail}" alt="${video.title}">
          <div class="related-duration">${video.duration}</div>
        </div>
        <div class="related-info">
          <div class="related-title">${video.title}</div>
          <div class="related-meta">${this.formatNumber(video.views)} views</div>
        </div>
      </div>
    `).join('');

    // Bind related video clicks
    relatedItems.querySelectorAll('.related-item').forEach(item => {
      item.addEventListener('click', () => {
        const videoId = item.dataset.videoId;
        const video = window.aiKingsApp?.videoData?.videos.find(v => v.id === videoId);
        if (video) {
          this.loadVideo(video);
        }
      });
    });
  }

  // Utility methods
  isJWPlayer() {
    return this.player && typeof this.player.getState === 'function';
  }

  formatTime(seconds) {
    if (isNaN(seconds)) return '0:00';

    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  }

  formatNumber(num) {
    if (num >= 1000000) {
      return (num / 1000000).toFixed(1) + 'M';
    } else if (num >= 1000) {
      return (num / 1000).toFixed(1) + 'K';
    }
    return num.toString();
  }

  showError(message) {
    const errorDiv = document.createElement('div');
    errorDiv.className = 'player-error';
    errorDiv.textContent = message;
    errorDiv.style.cssText = `
      position: absolute;
      top: 50%;
      left: 50%;
      transform: translate(-50%, -50%);
      background: rgba(0, 0, 0, 0.8);
      color: white;
      padding: 1rem;
      border-radius: var(--ai-kings-radius);
      z-index: 1000;
    `;

    document.querySelector('.player-wrapper').appendChild(errorDiv);

    setTimeout(() => {
      errorDiv.remove();
    }, 5000);
  }

  // Public API
  show(videoData, playlist = []) {
    this.loadVideo(videoData, playlist);
    document.getElementById('ai-kings-player-container').style.display = 'block';
  }

  hide() {
    if (this.player) {
      if (this.isJWPlayer()) {
        this.player.pause();
      } else {
        this.player.pause();
      }
    }
    document.getElementById('ai-kings-player-container').style.display = 'none';
  }

  destroy() {
    if (this.player) {
      if (this.isJWPlayer()) {
        this.player.remove();
      }
    }
    const container = document.getElementById('ai-kings-player-container');
    if (container) {
      container.remove();
    }
  }
}

// Initialize global video player instance
// Initialize video player when DOM is ready
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', () => {
    window.aiKingsVideoPlayer = new AIKingsVideoPlayer();
  });
} else {
  window.aiKingsVideoPlayer = new AIKingsVideoPlayer();
}