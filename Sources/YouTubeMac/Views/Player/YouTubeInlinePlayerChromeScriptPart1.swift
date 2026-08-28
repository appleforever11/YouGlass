import SwiftUI

extension YouTubeInlinePlayerView {
    static let playerChromeScriptPart1 = """
    (() => {
      const styleID = 'youglass-player-style';
      const styleText = `
        html, body {
          background: #000 !important;
          margin: 0 !important;
          width: 100% !important;
          height: 100% !important;
          overflow: hidden !important;
        }
        ytd-masthead,
        #masthead-container,
        #guide,
        ytd-mini-guide-renderer,
        #secondary,
        #below,
        #comments,
        #chat,
        #related,
        ytd-watch-next-secondary-results-renderer,
        ytd-watch-metadata,
        #owner,
        #actions,
        #description,
        .ytp-chrome-top,
        .ytp-chrome-bottom,
        .ytp-gradient-top,
        .ytp-gradient-bottom,
        .ytp-title,
        .ytp-watermark,
        .ytp-paid-content-overlay,
        .ytp-pause-overlay,
        .ytp-cards-teaser,
        .ytp-ce-element,
        .ytp-endscreen-content,
        .ytp-show-cards-title,
        .ytp-tooltip,
        .ytp-popup,
        .ytp-contextmenu,
        .ytp-cued-thumbnail-overlay,
        .ytp-spinner,
        .ytp-bezel,
        .ytp-bezel-text-wrapper,
        .ytp-doubletap-ui,
        .ytp-doubletap-ui-legacy,
        .ytp-suggested-action,
        .ytp-featured-product {
          display: none !important;
        }
        /* Keep YouTube's caption DOM available to the bridge. The native
           layer is visually suppressed below because YouGlass renders the
           selected track in the native player surface instead of inheriting
           the page chrome's shifting caption placement. */
        .ytp-caption-window-container,
        .caption-window.ytp-caption-window-bottom,
        .ytp-caption-window-bottom {
          display: block !important;
          position: absolute !important;
          top: auto !important;
          bottom: clamp(88px, 20%, 150px) !important;
          left: 50% !important;
          right: auto !important;
          width: min(88%, 980px) !important;
          max-width: 88% !important;
          min-width: 0 !important;
          transform: translateX(-50%) !important;
          text-align: center !important;
          opacity: 0 !important;
          visibility: visible !important;
          transition: none !important;
          z-index: 40 !important;
          pointer-events: none !important;
          overflow: visible !important;
        }
        .ytp-caption-window-container .caption-window,
        .ytp-caption-window-container .caption-window.ytp-caption-window-bottom {
          display: block !important;
          position: static !important;
          top: auto !important;
          right: auto !important;
          bottom: auto !important;
          left: auto !important;
          width: 100% !important;
          max-width: 100% !important;
          margin: 0 auto !important;
          transform: none !important;
          text-align: center !important;
          font-family: -apple-system, BlinkMacSystemFont, "SF Pro Rounded", sans-serif !important;
          font-size: clamp(18px, 3.2vw, 32px) !important;
          font-weight: 700 !important;
          line-height: 1.3 !important;
        }
        .ytp-caption-window-container .caption-window,
        .ytp-caption-window-container .ytp-caption-segment {
          color: #fff !important;
          text-shadow: 0 1px 3px rgba(0, 0, 0, .95) !important;
        }
        .ytp-caption-window-container .ytp-caption-segment {
          display: inline !important;
          background: rgba(0, 0, 0, .72) !important;
          line-height: 1.25 !important;
          box-decoration-break: clone !important;
          -webkit-box-decoration-break: clone !important;
        }
        ytd-app,
        #page-manager,
        ytd-watch-flexy,
        #content,
        #columns,
        #primary,
        #primary-inner,
        ytd-player,
        #full-bleed-container,
        #player-container-outer,
        #player-container,
        #player-container-inner,
        #player,
        #movie_player,
        #player-full-bleed-container {
          width: 100% !important;
          height: 100% !important;
          max-width: none !important;
          max-height: none !important;
          min-width: 0 !important;
          min-height: 0 !important;
          aspect-ratio: auto !important;
          margin: 0 !important;
        }
        #columns,
        #primary,
        #primary-inner,
        ytd-player,
        #full-bleed-container,
        #player-container-outer,
        #player-container,
        #player-container-inner,
        #player,
        #movie_player,
        #player-full-bleed-container {
          display: block !important;
          padding: 0 !important;
        }
        #player-container-outer,
        #full-bleed-container,
        #player-container,
        #player-container-inner,
        #player,
        #movie_player,
        #player-full-bleed-container,
        .html5-video-container,
        .html5-main-video {
          height: 100% !important;
          min-height: 0 !important;
          max-height: none !important;
          aspect-ratio: auto !important;
          background: #000 !important;
        }
        #full-bleed-container,
        #player-container-outer,
        #player-container,
        #player-container-inner,
        #player,
        #movie_player,
        #player-full-bleed-container {
          position: relative !important;
          inset: auto !important;
        }
        #movie_player,
        .html5-video-player {
          position: relative !important;
          overflow: hidden !important;
        }
        #movie_player .html5-video-container,
        .html5-video-player .html5-video-container {
          position: absolute !important;
          inset: 0 !important;
          top: 0 !important;
          left: 0 !important;
          width: 100% !important;
          height: 100% !important;
          min-height: 0 !important;
          max-height: none !important;
          aspect-ratio: auto !important;
          display: flex !important;
          align-items: center !important;
          justify-content: center !important;
          overflow: hidden !important;
        }
        #movie_player video,
        .html5-main-video,
        video.video-stream.html5-main-video {
          position: absolute !important;
          inset: 0 !important;
          top: 0 !important;
          left: 0 !important;
          right: 0 !important;
          bottom: 0 !important;
          margin: auto !important;
          width: 100% !important;
          height: 100% !important;
          min-height: 0 !important;
          max-height: none !important;
          display: block !important;
          object-fit: contain !important;
          object-position: center center !important;
          transform: none !important;
        }
      `;

      const installStyle = () => {
        if (!document.head) return;
        let style = document.getElementById(styleID);
        if (!style) {
          style = document.createElement('style');
          style.id = styleID;
          document.head.appendChild(style);
        }
        if (style.textContent !== styleText) style.textContent = styleText;
      };

      // A watch page can reinject this script during client-side navigation.
      // Invalidate and tear down the previous bootstrap loop first so two
      // page generations cannot race to start or pause the same media element.
      window.__youglassPlaybackScriptGeneration =
        (window.__youglassPlaybackScriptGeneration || 0) + 1;
      const playbackScriptGeneration = window.__youglassPlaybackScriptGeneration;
      if (window.__youglassPlaybackTimer) {
        window.clearInterval(window.__youglassPlaybackTimer);
        window.__youglassPlaybackTimer = null;
      }
      if (window.__youglassPlaybackObserver) {
        window.__youglassPlaybackObserver.disconnect();
        window.__youglassPlaybackObserver = null;
      }
      if (window.__youglassCaptionTimer) {
        window.clearInterval(window.__youglassCaptionTimer);
        window.__youglassCaptionTimer = null;
      }
      window.__youglassAutoplayBootstrap = false;
      window.__youglassPlayRequestInFlight = false;
      window.__youglassUserAudioChoice = null;
      window.__youglassFrameReady = false;
      window.__youglassBoundMedia = null;
      window.__youglassBoundMediaSource = null;
      window.__youglassWaitingForVideoFrame = false;

      window.__youglassAutoMute = __YOUGLASS_AUTO_MUTE__;
      window.__youglassExpectedVideoID = '__YOUGLASS_VIDEO_ID__';
      window.__youglassPlaybackStopped = false;
      window.__youglassCaptionsEnabled = false;
      window.__youglassLastCaptionState = null;
      // This is intentionally reset when a new native player is installed.
      // Once the user presses Play or Pause, the bootstrap observer must not
      // override that explicit choice while YouTube mutates its page DOM.
      window.__youglassUserPlaybackChoice = null;

      // YouTube can move the media element while the watch page hydrates. In
      // addition to the top-level document, look through same-origin frames so
      // native controls keep working across those page transitions.
      const findMediaElement = (root = document, seen = new Set()) => {
        if (!root || seen.has(root)) return null;
        const cached = window.__youglassBoundMedia;
        if (root === document && cached && cached.isConnected) return cached;
        seen.add(root);
    """
}
