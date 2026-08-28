import SwiftUI

extension YouTubeInlinePlayerView {
    static let playerChromeScriptPart2 = """
        const direct = root.querySelector?.('video');
        if (direct) return direct;
        const frames = root.querySelectorAll?.('iframe') || [];
        for (const frame of Array.from(frames)) {
          try {
            const nested = frame.contentDocument && findMediaElement(frame.contentDocument, seen);
            if (nested) return nested;
          } catch (_) {
            // Cross-origin frames are expected; direct lookup still works.
          }
        }
        return null;
      };

      const applyAudioPolicy = (force = false) => {
        const media = findMediaElement();
        if (!media) return false;
        if (window.__youglassAutoMute === true && (force || window.__youglassUserAudioChoice !== 'unmuted')) {
          media.muted = true;
          media.volume = 0;
          if (force) window.__youglassUserAudioChoice = 'muted';
        } else if (window.__youglassAutoMute !== true && (force || window.__youglassUserAudioChoice !== 'muted')) {
          media.muted = false;
          if (media.volume === 0) media.volume = 1;
          if (force) window.__youglassUserAudioChoice = 'unmuted';
        }
        return true;
      };

      const hasPlayableMetadata = media =>
        media.readyState >= HTMLMediaElement.HAVE_METADATA &&
        (media.duration === Infinity ||
         (Number.isFinite(media.duration) && media.duration > 0));

      const resetFrameStateIfNeeded = media => {
        if (!media) return;
        const source = media.currentSrc || media.src || '';
        if (window.__youglassBoundMedia !== media ||
            window.__youglassBoundMediaSource !== source) {
          window.__youglassBoundMedia = media;
          window.__youglassBoundMediaSource = source;
          window.__youglassFrameReady = false;
          window.__youglassWaitingForVideoFrame = false;
          delete media.dataset.youglassFrameWatch;
        }
      };

      const releaseAudioAfterFirstFrame = () => {
        if (!window.__youglassWaitingForVideoFrame ||
            window.__youglassAutoMute === true ||
            window.__youglassUserAudioChoice === 'muted') return;
        const media = window.__youglassBoundMedia || findMediaElement();
        if (!media) return;
        media.muted = false;
        if (media.volume === 0) media.volume = 1;
        window.__youglassUserAudioChoice = 'unmuted';
        window.__youglassWaitingForVideoFrame = false;
      };

      const markFrameReady = media => {
        if (!media || window.__youglassPlaybackStopped) return false;
        resetFrameStateIfNeeded(media);
        if (window.__youglassBoundMedia !== media) return false;
        if (media.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return false;
        window.__youglassFrameReady = true;
        releaseAudioAfterFirstFrame();
        return true;
      };

      const watchForFirstFrame = media => {
        if (!media || window.__youglassPlaybackStopped) return false;
        resetFrameStateIfNeeded(media);
        if (window.__youglassFrameReady) return true;
        if (media.readyState < HTMLMediaElement.HAVE_CURRENT_DATA) return false;
        // Some WebKit versions expose requestVideoFrameCallback but never
        // deliver its callback for a YouTube-managed media element.
        if (media.videoWidth > 0 && media.videoHeight > 0) {
          return markFrameReady(media);
        }
        const source = window.__youglassBoundMediaSource;
        if (typeof media.requestVideoFrameCallback === 'function') {
          if (media.dataset.youglassFrameWatch !== '1') {
            media.dataset.youglassFrameWatch = '1';
            try {
              media.requestVideoFrameCallback(() => {
                delete media.dataset.youglassFrameWatch;
                if (window.__youglassBoundMedia === media &&
                    window.__youglassBoundMediaSource === source &&
                    media.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA) {
                  markFrameReady(media);
                  emitState('Player ready');
                }
              });
            } catch (_) {
              delete media.dataset.youglassFrameWatch;
              return markFrameReady(media);
            }
          }
          return false;
        }
        return markFrameReady(media);
      };

      const playbackFailureStatus = media => {
        if (media.error) {
          // YouTube can briefly publish an error while replacing the stream
          // or before the media element has metadata. Keep that startup churn
          // recoverable so PIP can try the same video again once its source is
          // ready. An error after a real duration exists is terminal and is
          // surfaced to the native retry state.
          if (!hasPlayableMetadata(media) || !window.__youglassFrameReady) return 'Buffering video...';
          const code = media.error.code ? ` (${media.error.code})` : '';
          return `${media.error.message || 'YouTube playback error'}${code}`;
        }

        // A rejected play() promise is not always a permanent failure. Some
        // watch pages create the media element before metadata and a playable
        // source are ready. Keep those cases in the bootstrap retry path.
        if (!window.__youglassFrameReady) return 'Buffering video...';
        if (!hasPlayableMetadata(media) || media.networkState === HTMLMediaElement.NETWORK_LOADING) {
          return 'Buffering video...';
        }
        return 'Playback blocked; use Play to start';
      };

      const primePlayback = () => {
        if (window.__youglassPlaybackStopped) return false;
        const media = findMediaElement();
        if (!media) return false;
        resetFrameStateIfNeeded(media);
        watchForFirstFrame(media);
        if (window.__youglassUserPlaybackChoice === 'paused') {
          if (!media.paused) media.pause();
          emitState('Paused');
          return true;
        }
        const holdAudioUntilFrame = !window.__youglassFrameReady &&
            window.__youglassAutoMute !== true;
        if (holdAudioUntilFrame) {
            media.muted = true;
            media.volume = 0;
            window.__youglassWaitingForVideoFrame =
                window.__youglassUserAudioChoice !== 'muted';
        } else if (!window.__youglassAutoplayBootstrap &&
                   window.__youglassFrameReady) {
            applyAudioPolicy();
        }
        const needsAudioBootstrap = window.__youglassAutoMute !== true &&
          window.__youglassUserAudioChoice !== 'muted' &&
          media.paused &&
          !media.dataset.youglassAutoplayAttempted;
        if (needsAudioBootstrap) {
          window.__youglassAutoplayBootstrap = true;
          media.muted = true;
          media.volume = 0;
          media.dataset.youglassAutoplayAttempted = '1';
        }
        // Do not click YouTube's hidden play button before calling media.play().
        // That click can toggle the element twice on some watch pages. Also
        // keep only one promise in flight while the browser resolves autoplay.
        if (media.paused && !window.__youglassPlayRequestInFlight) {
          window.__youglassPlayRequestInFlight = true;
          let playResult;
          try {
            playResult = media.play();
          } catch (_) {
            window.__youglassPlayRequestInFlight = false;
            window.__youglassAutoplayBootstrap = false;
            delete media.dataset.youglassAutoplayAttempted;
            emitState(playbackFailureStatus(media));
            return false;
          }

          if (playResult && playResult.then) {
            playResult.then(() => {
              window.__youglassPlayRequestInFlight = false;
              window.__youglassAutoplayBootstrap = false;
              if (needsAudioBootstrap &&
                  window.__youglassAutoMute !== true &&
                  window.__youglassUserAudioChoice !== 'muted') {
                window.__youglassWaitingForVideoFrame = true;
                emitState('Buffering video...');
              } else {
                emitState();
              }
            }).catch(() => {
              window.__youglassPlayRequestInFlight = false;
              window.__youglassAutoplayBootstrap = false;
              window.__youglassWaitingForVideoFrame = false;
              delete media.dataset.youglassAutoplayAttempted;
              emitState(playbackFailureStatus(media));
            });
          } else {
            window.__youglassPlayRequestInFlight = false;
            if (needsAudioBootstrap) {
              window.__youglassWaitingForVideoFrame = true;
            }
          }
        }
        // WebKit can flip paused to false before the play() promise settles.
        // Keep the bootstrap timer alive until that promise has actually
        // resolved, otherwise a transient per-video failure becomes final.
        if (window.__youglassFrameReady && !media.paused && !window.__youglassPlayRequestInFlight) {
          media.dataset.youglassPrimed = '1';
          return true;
        }
        return false;
      };

      const findCaptionButton = (media = findMediaElement()) => {
        const playerRoot = media?.closest?.('.html5-video-player') ||
          document.querySelector('#movie_player') ||
          document;
        const selectors = [
          '.ytp-subtitles-button',
          'button[aria-label*="captions" i]',
          'button[aria-label*="subtitles" i]'
        ];
        for (const selector of selectors) {
          const candidates = playerRoot.querySelectorAll?.(selector) || [];
          const button = Array.from(candidates).find(candidate => candidate.isConnected);
          if (button) return button;
        }
        return null;
      };

      const captionsButtonIsActive = button => {
        if (!button) return false;
        const ariaLabel = (button.getAttribute('aria-label') || '').toLowerCase();
        const dataTitle = (button.getAttribute('data-title-no-tooltip') || '').toLowerCase();
        return button.getAttribute('aria-pressed') === 'true' ||
          button.classList.contains('ytp-button-active') ||
          ariaLabel.includes('turn off') ||
          ariaLabel.includes('hide captions') ||
          dataTitle.includes('turn off');
      };

      const captionsButtonIsDisabled = button => Boolean(
        !button ||
        button.disabled ||
        button.getAttribute('aria-disabled') === 'true' ||
        button.classList.contains('ytp-button-disabled')
      );

      const findCaptionPlayer = media =>
        window.movie_player ||
        document.querySelector('#movie_player') ||
        media?.closest?.('.html5-video-player') ||
        null;

      const invokeCaptionFallback = media => {
        const player = findCaptionPlayer(media);
        if (!player) return false;
        if (typeof player.toggleSubtitles === 'function') {
          try {
            player.toggleSubtitles();
            return true;
          } catch (_) {}
        }
        if (typeof player.setOption === 'function') {
          try {
            const track = readCaptionsState(media)
              ? {}
              : { languageCode: window.ytplayer?.config?.args?.cc_lang_pref || 'en' };
            player.setOption('captions', 'track', track);
            return true;
          } catch (_) {}
        }
        return false;
      };

      const readCaptionsState = (media = findMediaElement()) => {
        const button = findCaptionButton(media);
        if (button) window.__youglassCaptionsEnabled = captionsButtonIsActive(button);
        return Boolean(window.__youglassCaptionsEnabled);
      };

      const ensureCaptionTrack = media => {
        if (!media || media.dataset.youglassCaptionTrackSelected === '1') return true;
        const player = findCaptionPlayer(media);
        if (!player || typeof player.setOption !== 'function') return false;
        try {
          const languageCode = window.ytplayer?.config?.args?.cc_lang_pref || 'en';
          player.setOption('captions', 'track', { languageCode });
          media.dataset.youglassCaptionTrackSelected = '1';
          return true;
        } catch (_) {
          return false;
        }
      };

      const captionTextForElement = element =>
        (element?.textContent || element?.innerText || element?.getAttribute?.('aria-label') || '')
          .replace(/\\u00a0/g, ' ')
          .replace(/\\s+/g, ' ')
          .trim();

      const captionDocumentRoots = (media, seen = new Set()) => {
        const firstRoot = media?.closest?.('.html5-video-player') ||
          document.querySelector('#movie_player') ||
          document;
        const roots = [];
        const visit = root => {
          if (!root || seen.has(root)) return;
          seen.add(root);
          roots.push(root);
          const elements = root.querySelectorAll?.('*') || [];
          for (const element of Array.from(elements)) {
            if (element.shadowRoot) visit(element.shadowRoot);
          }
          const frames = root.querySelectorAll?.('iframe') || [];
          for (const frame of Array.from(frames)) {
            try {
              if (frame.contentDocument) visit(frame.contentDocument);
            } catch (_) {}
          }
        };
        visit(firstRoot);
        if (firstRoot !== document) visit(document);
        return roots;
      };

      const captionElements = (media, selector) => {
        const elements = [];
        for (const root of captionDocumentRoots(media)) {
          elements.push(...Array.from(root.querySelectorAll?.(selector) || []));
        }
        return Array.from(new Set(elements));
      };

      const readRenderedCaptionText = (media = findMediaElement()) => {
        const segments = captionElements(media, '.ytp-caption-segment')
          .map(captionTextForElement)
          .filter(Boolean);
        if (segments.length) return Array.from(new Set(segments)).join(' ').trim();

        return captionElements(
          media,
          '.caption-window, .ytp-caption-window-container'
        )
          .map(captionTextForElement)
          .find(Boolean) || '';
      };

      const emitCaptionState = () => {
        const media = findMediaElement();
        if (!media || !window.webkit?.messageHandlers?.youglassPlayback) return;
        const enabled = readCaptionsState(media);
        if (enabled) ensureCaptionTrack(media);
        const text = enabled ? readRenderedCaptionText(media) : '';
        const key = `${enabled ? '1' : '0'}:${text}`;
        if (window.__youglassLastCaptionState === key) return;
        window.__youglassLastCaptionState = key;
        window.webkit.messageHandlers.youglassPlayback.postMessage({
          videoID: currentVideoID(),
          captionsEnabled: enabled,
          captionText: text
        });
      };

      const formatPlaybackRate = rate => {
        const normalized = Math.round(Number(rate) * 100) / 100;
        return normalized === 1 ? 'Normal speed' : `${normalized}× playback`;
      };

      const currentVideoID = () => {
        try {
          const url = new URL(window.location.href);
          const watchID = url.searchParams.get('v');
          if (watchID) return watchID;
          const match = url.pathname.match(/\\/(?:embed\\/|shorts\\/)?([A-Za-z0-9_-]{11})(?:$|\\/)/);
          if (match) return match[1];
          const configuredID = window.ytplayer?.config?.args?.video_id ||
            window.ytplayer?.config?.video_id ||
            document.querySelector('[data-video-id]')?.getAttribute('data-video-id');
          return configuredID || window.__youglassExpectedVideoID || null;
        } catch (_) {
          return window.__youglassExpectedVideoID || null;
        }
      };

      const emitState = status => {
        const media = findMediaElement();
        if (!media || !window.webkit?.messageHandlers?.youglassPlayback) return;
        resetFrameStateIfNeeded(media);
        const frameReady = watchForFirstFrame(media);
        const requestedStatus = status || 'Player ready';
        const resolvedStatus = !frameReady &&
          (requestedStatus === 'Player ready' || requestedStatus === 'Audio on')
          ? 'Buffering video...'
          : requestedStatus;
        const supportsWebKitPiP = Boolean(
          media.webkitSupportsPresentationMode &&
    """
}
