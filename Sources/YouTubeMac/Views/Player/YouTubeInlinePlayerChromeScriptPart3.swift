import SwiftUI

extension YouTubeInlinePlayerView {
    static let playerChromeScriptPart3 = """
          media.webkitSetPresentationMode &&
          media.webkitSupportsPresentationMode('picture-in-picture')
        );
        window.webkit.messageHandlers.youglassPlayback.postMessage({
          videoID: currentVideoID(),
          muted: Boolean(media.muted || media.volume === 0),
          captionsEnabled: readCaptionsState(media),
          playing: !media.paused && !media.ended,
          ended: Boolean(media.ended),
          currentTime: Number.isFinite(media.currentTime) ? media.currentTime : 0,
          duration: Number.isFinite(media.duration) ? media.duration : 0,
          playbackRate: Number.isFinite(media.playbackRate) ? media.playbackRate : 1,
          frameReady,
          pipAvailable: supportsWebKitPiP || Boolean(document.pictureInPictureEnabled && media.requestPictureInPicture),
          pipActive: media.webkitPresentationMode === 'picture-in-picture' || document.pictureInPictureElement === media,
          status: resolvedStatus
        });
      };

      const waitFor = milliseconds => new Promise(resolve => window.setTimeout(resolve, milliseconds));

      const settleCaptionsToggle = (media, previousState, attempt = 0, fallbackAttempted = false) => {
        const enabled = readCaptionsState(media);
        if (enabled !== previousState || attempt >= 8) {
          if (enabled) emitCaptionState();
          emitState(
            enabled ? 'Captions on' :
              (previousState ? 'Captions off' : 'Captions did not change')
          );
          return;
        }
        if (attempt >= 4 && !fallbackAttempted) {
          const fallbackUsed = invokeCaptionFallback(media);
          if (fallbackUsed) {
            window.setTimeout(
              () => settleCaptionsToggle(media, previousState, attempt + 1, true),
              100
            );
            return;
          }
          fallbackAttempted = true;
        }
        window.setTimeout(
          () => settleCaptionsToggle(media, previousState, attempt + 1, fallbackAttempted),
          100
        );
      };

      const installMediaEvents = () => {
        if (window.__youglassPlaybackStopped) return;
        const media = findMediaElement();
        if (!media) return;
        resetFrameStateIfNeeded(media);
        // YouGlass owns queue navigation. Never let the YouTube page restart
        // the current media when the native queue has no next item yet.
        media.loop = false;
        if (media.dataset.youglassEvents !== '1') {
          media.dataset.youglassEvents = '1';
          const statusForEvent = name => {
            if (name === 'error') return playbackFailureStatus(media);
            if (name === 'waiting' || name === 'stalled') return 'Buffering video...';
            if (name === 'canplay' || name === 'playing') return 'Player ready';
            return undefined;
          };
          [
            'play', 'playing', 'pause', 'volumechange', 'loadedmetadata',
            'durationchange', 'timeupdate', 'progress', 'seeking', 'seeked',
            'canplay', 'waiting', 'stalled', 'error', 'abort', 'ended',
            'enterpictureinpicture', 'leavepictureinpicture',
            'webkitpresentationmodechanged'
          ].forEach(name => media.addEventListener(name, () => emitState(statusForEvent(name))));
        }
        watchForFirstFrame(media);
        emitState();
        emitCaptionState();
      };

      window.__youglassControls = {
        stopPlayback() {
          window.__youglassPlaybackStopped = true;
          window.__youglassPlaybackScriptGeneration =
            (window.__youglassPlaybackScriptGeneration || 0) + 1;
          window.__youglassPlayRequestInFlight = false;
          window.__youglassWaitingForVideoFrame = false;
          window.__youglassFrameReady = false;
          window.__youglassBoundMedia = null;
          window.__youglassBoundMediaSource = null;
          if (window.__youglassPlaybackTimer) {
            window.clearInterval(window.__youglassPlaybackTimer);
            window.__youglassPlaybackTimer = null;
          }
          if (window.__youglassPlaybackObserver) {
            window.__youglassPlaybackObserver.disconnect();
            window.__youglassPlaybackObserver = null;
          }

          const media = findMediaElement();
          if (media) {
            try {
              if (media.webkitPresentationMode === 'picture-in-picture' && media.webkitSetPresentationMode) {
                media.webkitSetPresentationMode('inline');
              }
            } catch (_) {}
            media.pause();
            media.muted = true;
            media.volume = 0;
            delete media.dataset.youglassFrameWatch;
          }

          if (document.pictureInPictureElement && document.exitPictureInPicture) {
            document.exitPictureInPicture().catch(() => {});
          }
          window.__youglassControls = null;
        },
        togglePlayback() {
          const media = findMediaElement();
          if (!media) return emitState('Video is not ready');
          if (media.paused) {
            window.__youglassUserPlaybackChoice = 'playing';
            window.__youglassPlayRequestInFlight = false;
            const playResult = media.play();
            if (playResult && playResult.catch) {
              playResult.catch(error => {
                window.__youglassUserPlaybackChoice = null;
                window.__youglassPlayRequestInFlight = false;
                emitState(error?.message || playbackFailureStatus(media));
              });
            }
          } else {
            window.__youglassUserPlaybackChoice = 'paused';
            media.pause();
          }
          emitState();
        },
        startPlayback() {
          if (window.__youglassPlaybackStopped) return;
          if (!findMediaElement()) return emitState('Video is not ready');
          installMediaEvents();
          primePlayback();
        },
        toggleMute() {
          const media = findMediaElement();
          if (!media) return emitState('Video is not ready');
          window.__youglassAutoplayBootstrap = false;
          const shouldUnmute = media.muted || media.volume === 0;
          if (shouldUnmute && !window.__youglassFrameReady) {
            window.__youglassWaitingForVideoFrame = true;
            window.__youglassUserAudioChoice = 'unmuted';
            media.muted = true;
            media.volume = 0;
            emitState('Buffering video...');
            return;
          }
          media.muted = !shouldUnmute;
          media.volume = shouldUnmute ? 1 : media.volume;
          window.__youglassUserAudioChoice = shouldUnmute ? 'unmuted' : 'muted';
          window.__youglassWaitingForVideoFrame = false;
          emitState(shouldUnmute ? 'Audio on' : 'Muted');
        },
        toggleCaptions() {
          const media = findMediaElement();
          if (!media) return emitState('Video is not ready');

          // The native button drives YouTube's own caption track selection,
          // while remaining hidden with the rest of YouTube's chrome. The
          // caption track text is mirrored into YouGlass's stable media overlay
          // so it remains visible when YouTube's page chrome is suppressed.
          const button = findCaptionButton(media);
          if (captionsButtonIsDisabled(button)) {
            window.__youglassCaptionsEnabled = false;
            return emitState('No captions available for this video');
          }

          const previousState = readCaptionsState(media);
          try {
            button.click();
          } catch (_) {
            try {
              button.dispatchEvent(new MouseEvent('click', {
                bubbles: true,
                cancelable: true,
                composed: true,
                view: window
              }));
            } catch (_) {}
          }
          window.setTimeout(() => settleCaptionsToggle(media, previousState), 100);
        },
        applyAudioPolicy(autoMuteOnStart) {
          window.__youglassAutoplayBootstrap = false;
          window.__youglassAutoMute = autoMuteOnStart === true;
          applyAudioPolicy(true);
          emitState(window.__youglassAutoMute ? 'Muted by setting' : 'Audio on by setting');
        },
        seekBy(seconds) {
          const media = findMediaElement();
          if (!media || !Number.isFinite(media.duration)) return;
          media.currentTime = Math.max(0, Math.min(media.duration, media.currentTime + Number(seconds || 0)));
          emitState();
        },
        seekTo(seconds) {
          const media = findMediaElement();
          if (!media || !Number.isFinite(media.duration)) return;
          const target = Number(seconds);
          if (!Number.isFinite(target)) return;
          media.currentTime = Math.max(0, Math.min(media.duration, target));
          emitState('Seeking');
        },
        setPlaybackRate(rate) {
          const media = findMediaElement();
          if (!media) return emitState('Video is not ready');
          const boundedRate = Math.max(0.25, Math.min(2, Number(rate) || 1));
          media.playbackRate = boundedRate;
          emitState(formatPlaybackRate(boundedRate));
        },
        async togglePictureInPicture() {
          const media = findMediaElement();
          if (!media) {
            return emitState('Picture in Picture is unavailable for this video');
          }

          // Close whichever PiP mode is currently active before attempting
          // another mode. WebKit exposes these as two different APIs.
          try {
            if (
              media.webkitPresentationMode === 'picture-in-picture' &&
              media.webkitSetPresentationMode
            ) {
              media.webkitSetPresentationMode('inline');
              await waitFor(160);
              return emitState('Player ready');
            }
            if (document.pictureInPictureElement === media && document.exitPictureInPicture) {
              await document.exitPictureInPicture();
              await waitFor(80);
              return emitState('Player ready');
            }

            // Prefer the standard API. On macOS, the WebKit presentation-mode
            // API can report support without creating a visible PiP window.
            if (document.pictureInPictureEnabled && media.requestPictureInPicture) {
              try {
                await media.requestPictureInPicture();
                await waitFor(120);
                if (document.pictureInPictureElement === media) {
                  return emitState('Picture in Picture');
                }
              } catch (_) {}
            }

            if (
              media.webkitSupportsPresentationMode &&
              media.webkitSetPresentationMode &&
              media.webkitSupportsPresentationMode('picture-in-picture')
            ) {
              media.webkitSetPresentationMode('picture-in-picture');
              await waitFor(180);
              if (media.webkitPresentationMode === 'picture-in-picture') {
                return emitState('Picture in Picture');
              }
            }
            emitState('Picture in Picture is unavailable for this video');
          } catch (error) {
            emitState(error?.message || 'Picture in Picture could not start');
          }
        }
      };

      // Keep click-to-play/pause inside the native surface without making the
      // WKWebView override AppKit's hit-test chain. Programmatic YouTube clicks
      // are ignored so the autoplay bootstrap cannot toggle playback twice.
      if (!window.__youglassSurfaceTapInstalled) {
        document.addEventListener('click', event => {
          if (!event.isTrusted || window.__youglassPlaybackStopped) return;
          event.preventDefault();
          event.stopImmediatePropagation();
          window.__youglassControls?.togglePlayback();
        }, true);
        window.__youglassSurfaceTapInstalled = true;
      }

      installStyle();
      installMediaEvents();
      primePlayback();
      emitCaptionState();
      const captionTimer = window.setInterval(() => {
        if (window.__youglassPlaybackScriptGeneration !== playbackScriptGeneration) {
          window.clearInterval(captionTimer);
          return;
        }
        emitCaptionState();
      }, 120);
      window.__youglassCaptionTimer = captionTimer;
      let attempts = 0;
      const playbackTimer = window.setInterval(() => {
        if (window.__youglassPlaybackScriptGeneration !== playbackScriptGeneration) {
          window.clearInterval(playbackTimer);
          return;
        }
        attempts += 1;
        installMediaEvents();
        if (primePlayback() && window.__youglassFrameReady) {
          window.clearInterval(playbackTimer);
        } else if (attempts > 64) {
          window.clearInterval(playbackTimer);
          emitState('Video frame did not load');
        }
      }, 220);
      window.__youglassPlaybackTimer = playbackTimer;
      window.__youglassPlaybackObserver = new MutationObserver(() => {
        if (window.__youglassPlaybackStopped ||
            window.__youglassPlaybackScriptGeneration !== playbackScriptGeneration) return;
        installStyle();
        installMediaEvents();
        primePlayback();
      });
      window.__youglassPlaybackObserver.observe(document.documentElement, { childList: true, subtree: true });
    })();
    """
}
