// Touch Feature: keeps the page's own buttons and the on-screen keyboard out of the game's way on
// phones and tablets.

const CHROME_ID = 'game-chrome';
const TUCK_AFTER_MS = 4000;

// On touch screens the share and music buttons share one pill on the right edge. It tucks away to
// a small grip tab a few seconds after the last touch, so it never sits on top of game controls,
// and a tap on the tab brings it back. Desktop layouts are left alone.
function initTouchChrome() {
    const chrome = document.getElementById(CHROME_ID);
    if (!chrome || !window.matchMedia('(pointer: coarse)').matches) return;

    let timer = null;
    const tuck = () => chrome.classList.add('tucked');
    const wake = () => {
        chrome.classList.remove('tucked');
        clearTimeout(timer);
        timer = setTimeout(tuck, TUCK_AFTER_MS);
    };

    // Capture phase, so the tap that opens a tucked pill doesn't also press the button under it.
    chrome.addEventListener('click', (event) => {
        if (chrome.classList.contains('tucked')) {
            event.preventDefault();
            event.stopPropagation();
        }
        wake();
    }, true);
    wake();
    console.log('Touch chrome initialized');
}

// Mobile keyboards scroll the page and shrink the viewport while they're open, and some browsers
// (Safari on iOS especially) don't put things back when they close. Scroll home and tell Godot to
// re-measure its canvas whenever the visible area changes.
function initKeyboardSettle() {
    const settle = () => {
        window.scrollTo(0, 0);
        window.dispatchEvent(new Event('resize'));
    };
    if (window.visualViewport) {
        let pending = null;
        window.visualViewport.addEventListener('resize', () => {
            clearTimeout(pending);
            pending = setTimeout(settle, 100);
        });
    }
    window.addEventListener('focusout', () => setTimeout(settle, 150));
    window.addEventListener('orientationchange', () => setTimeout(settle, 300));
}

// Full screen hides the browser's address bar. Android browsers and iPadOS allow it from a tap;
// iPhone Safari doesn't let pages do it at all, so there the button explains the home screen route.
// Already running from a home screen, there's nothing to do and the button goes away.
function initFullscreen() {
    const button = document.getElementById('fullscreen-button');
    const tip = document.getElementById('fullscreen-tip');
    if (!button) return;
    const installed = navigator.standalone ||
        window.matchMedia('(display-mode: fullscreen), (display-mode: standalone)').matches;
    if (installed) {
        button.remove();
        return;
    }
    const supported = document.fullscreenEnabled || document.webkitFullscreenEnabled;
    const current = () => document.fullscreenElement || document.webkitFullscreenElement;
    const showIcon = () => {
        document.getElementById('icon-fullscreen').style.display = current() ? 'none' : 'block';
        document.getElementById('icon-fullscreen-exit').style.display = current() ? 'block' : 'none';
    };
    document.addEventListener('fullscreenchange', showIcon);
    document.addEventListener('webkitfullscreenchange', showIcon);

    button.addEventListener('click', () => {
        if (!supported) {
            tip.classList.add('shown');
            setTimeout(() => tip.classList.remove('shown'), 6000);
            return;
        }
        const root = document.documentElement;
        if (current()) {
            (document.exitFullscreen || document.webkitExitFullscreen).call(document);
        } else if (root.requestFullscreen) {
            root.requestFullscreen({ navigationUI: 'hide' }).catch(() => {});
        } else {
            root.webkitRequestFullscreen();
        }
    });
}

document.addEventListener('DOMContentLoaded', () => {
    initTouchChrome();
    initKeyboardSettle();
    initFullscreen();
});
