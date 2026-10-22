// Music Feature Configuration
const MUSIC_WIDGET_ID = 'soundcloud-widget';
const MUSIC_TOGGLE_ID = 'music-toggle';
const ICON_MUTED_ID = 'icon-muted';
const ICON_UNMUTED_ID = 'icon-unmuted';

// Music Feature Variables
let widget = null;
let isMuted = true;

// Music Feature Functions

// Initialize music feature
function initMusicFeature() {
    const musicToggle = document.getElementById(MUSIC_TOGGLE_ID);
    
    if (musicToggle) {
        musicToggle.addEventListener('click', toggleMusic);
        console.log('Music feature initialized');
    } else {
        console.warn('Music toggle button not found');
    }
    
    // Initialize SoundCloud widget
    initSoundCloudWidget();
}

// Initialize SoundCloud widget
function initSoundCloudWidget() {
    const widgetIframe = document.getElementById(MUSIC_WIDGET_ID);
    
    if (widgetIframe) {
        widget = SC.Widget(widgetIframe);
        
        // Set up widget event listeners
        widget.bind(SC.Widget.Events.READY, function() {
            console.log('SoundCloud widget ready');
            
            // Start muted and paused
            widget.pause();
            widget.setVolume(0);
            
            // Preload the audio
            widget.load(widgetIframe.src.split('url=')[1].split('&')[0], {
                auto_play: false,
                hide_related: true,
                show_comments: false,
                show_user: false,
                show_reposts: false,
                show_teaser: false,
                visual: false
            });
        });
        
        widget.bind(SC.Widget.Events.PLAY, function() {
            console.log('Music started playing');
        });
        
        widget.bind(SC.Widget.Events.PAUSE, function() {
            console.log('Music paused');
        });
        
        widget.bind(SC.Widget.Events.FINISH, function() {
            console.log('Music finished, restarting');
            widget.play();
        });
        
    } else {
        console.warn('SoundCloud widget iframe not found');
    }
}

// Toggle music play/pause and mute/unmute
function toggleMusic() {
    if (!widget) {
        console.warn('SoundCloud widget not initialized');
        return;
    }
    
    const iconMuted = document.getElementById(ICON_MUTED_ID);
    const iconUnmuted = document.getElementById(ICON_UNMUTED_ID);
    const toggleButton = document.getElementById(MUSIC_TOGGLE_ID);
    const canvas = document.getElementById('canvas');
    
    if (isMuted) {
        // Unmute and play
        widget.setVolume(50); // Set volume to 50%
        widget.play();
        if (iconMuted) iconMuted.style.display = 'none';
        if (iconUnmuted) iconUnmuted.style.display = 'block';
        if (toggleButton) toggleButton.title = 'Mute Music';
        isMuted = false;
        console.log('Music unmuted and playing');
    } else {
        // Mute
        widget.pause();
        widget.setVolume(0);
        if (iconMuted) iconMuted.style.display = 'block';
        if (iconUnmuted) iconUnmuted.style.display = 'none';
        if (toggleButton) toggleButton.title = 'Unmute Music';
        isMuted = true;
        console.log('Music muted and paused');
    }
    
    // Return focus to the game canvas immediately
    if (canvas) {
        canvas.focus();
    }
}

// Initialize music feature when DOM is loaded
document.addEventListener('DOMContentLoaded', initMusicFeature);
