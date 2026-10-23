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

document.addEventListener('DOMContentLoaded', () => {
    initTouchChrome();
    initKeyboardSettle();
});
