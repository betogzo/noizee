import JavaScriptCore
import Testing
@testable import Noizee

// MARK: - PlayerStateHelpersJSTests

/// Covers the DOM-independent helpers the observer scripts use so playback state keeps
/// flowing when YouTube Music renders `ytmusic-miniplayer` instead of `ytmusic-player-bar`.
@Suite(.tags(.service))
struct PlayerStateHelpersJSTests {
    private func makeContext() -> JSContext {
        let ctx = JSContext()!
        ctx.evaluateScript(SingletonPlayerWebView.playerStateHelpersJS)
        return ctx
    }

    @Test("Finds the legacy player bar first")
    func findsLegacyPlayerBar() {
        let ctx = self.makeContext()
        ctx.evaluateScript(
            """
            var doc = { querySelector: function(s) {
                return s === 'ytmusic-player-bar' ? 'legacy' : (s === 'ytmusic-miniplayer' ? 'mini' : null);
            } };
            globalThis.result = __noizeeFindPlayerBar(doc);
            """
        )
        #expect(ctx.evaluateScript("result").toString() == "legacy")
    }

    @Test("Falls back to the new miniplayer when the legacy bar is absent")
    func fallsBackToMiniplayer() {
        let ctx = self.makeContext()
        ctx.evaluateScript(
            """
            var doc = { querySelector: function(s) { return s === 'ytmusic-miniplayer' ? 'mini' : null; } };
            globalThis.result = __noizeeFindPlayerBar(doc);
            """
        )
        #expect(ctx.evaluateScript("result").toString() == "mini")
    }

    @Test("Reads progress from the video element when duration is known")
    func readsProgressFromVideo() {
        let ctx = self.makeContext()
        ctx.evaluateScript(
            """
            globalThis.result = __noizeeReadProgress({ currentTime: 42.7, duration: 244.4 }, null);
            """
        )
        #expect(ctx.evaluateScript("result.progress").toInt32() == 42)
        #expect(ctx.evaluateScript("result.duration").toInt32() == 244)
    }

    @Test("Falls back to the slider when the video has no duration yet")
    func fallsBackToSlider() {
        let ctx = self.makeContext()
        ctx.evaluateScript(
            """
            var attrs = { 'value': '12', 'aria-valuemax': '200' };
            var slider = { getAttribute: function(name) { return attrs[name] || null; } };
            globalThis.result = __noizeeReadProgress({ currentTime: 0, duration: NaN }, slider);
            """
        )
        #expect(ctx.evaluateScript("result.progress").toInt32() == 12)
        #expect(ctx.evaluateScript("result.duration").toInt32() == 200)
    }

    @Test("Reports zero progress with neither video nor slider")
    func reportsZeroWithoutSources() {
        let ctx = self.makeContext()
        ctx.evaluateScript("globalThis.result = __noizeeReadProgress(null, null);")
        #expect(ctx.evaluateScript("result.progress").toInt32() == 0)
        #expect(ctx.evaluateScript("result.duration").toInt32() == 0)
    }

    @Test("Picks the largest Media Session artwork for the current title")
    func picksLargestArtwork() {
        let ctx = self.makeContext()
        ctx.evaluateScript(
            """
            var session = { metadata: { title: 'Song', artwork: [
                { src: 'small', sizes: '60x60' },
                { src: 'large', sizes: '544x544' },
                { src: 'medium', sizes: '226x226' }
            ] } };
            globalThis.result = __noizeeMediaSessionArtwork(session, 'Song');
            """
        )
        #expect(ctx.evaluateScript("result").toString() == "large")
    }

    @Test("Ignores Media Session artwork that belongs to a different title")
    func ignoresStaleArtwork() {
        let ctx = self.makeContext()
        ctx.evaluateScript(
            """
            var session = { metadata: { title: 'Old Song', artwork: [{ src: 'old', sizes: '544x544' }] } };
            globalThis.result = __noizeeMediaSessionArtwork(session, 'New Song');
            """
        )
        #expect(ctx.evaluateScript("result").toString().isEmpty)
    }

    @Test("Returns empty artwork without Media Session metadata")
    func emptyArtworkWithoutMetadata() {
        let ctx = self.makeContext()
        ctx.evaluateScript("globalThis.result = __noizeeMediaSessionArtwork({ metadata: null }, 'Song');")
        #expect(ctx.evaluateScript("result").toString().isEmpty)
    }

    @Test("Observer script does not gate video listeners on the legacy player bar")
    func observerScriptStartsWithoutPlayerBar() {
        let script = SingletonPlayerWebView.observerScript
        #expect(script.contains("function __noizeeFindPlayerBar"))
        #expect(script.contains("document.addEventListener('DOMContentLoaded', start);"))
        #expect(!script.contains("document.querySelector('ytmusic-player-bar');\n"))
    }

    @Test("Control selectors cover both the legacy bar and the new miniplayer")
    func controlSelectorsCoverBothPlayers() {
        #expect(SingletonPlayerWebView.playPauseButtonSelector.contains(".ytmusic-player-bar"))
        #expect(SingletonPlayerWebView.playPauseButtonSelector.contains(".ytmusicPlayerControlsPlayPauseButton"))
        #expect(SingletonPlayerWebView.nextButtonSelector.contains(".ytmusicPlayerControlsNextButton"))
        #expect(SingletonPlayerWebView.previousButtonSelector.contains(".ytmusicPlayerControlsPreviousButton"))
    }
}
