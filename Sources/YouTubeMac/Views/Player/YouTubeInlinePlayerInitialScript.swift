import SwiftUI

extension YouTubeInlinePlayerView {
        // Keep WebKit's first paint dark while YouTube builds its client-rendered
        // player. The native thumbnail remains visible until a real media frame
        // is reported, so the watch layout never flashes a white page.
        static let initialSurfaceScript = """
        (() => {
          const styleID = 'youglass-initial-surface-style';
          const styleText = `
            html, body {
              background: #000 !important;
              margin: 0 !important;
            }
          `;
          const install = () => {
            const root = document.documentElement;
            if (!root) return;
            root.style.backgroundColor = '#000';
            let style = document.getElementById(styleID);
            if (!style) {
              style = document.createElement('style');
              style.id = styleID;
              (document.head || root).appendChild(style);
            }
            if (style.textContent !== styleText) style.textContent = styleText;
          };
          install();
          document.addEventListener('DOMContentLoaded', install, { once: true });
        })();
        """
}
