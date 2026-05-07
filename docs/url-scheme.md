# URL Scheme

Noizee supports a custom URL scheme for opening content directly from other apps, scripts, or the command line.

## Play a Song

Play a song by its YouTube video ID:

```bash
open "noizee://play?v=dQw4w9WgXcQ"
```

## Usage Examples

### From Terminal

```bash
# Play a specific song
open "noizee://play?v=VIDEO_ID"
```

### From AppleScript

```applescript
do shell script "open 'noizee://play?v=VIDEO_ID'"
```

### From Shortcuts

Use the "Open URLs" action with `noizee://play?v=VIDEO_ID`.

## See Also

- [AppleScript Support](applescript.md) — Automate playback with scripts, Raycast, Alfred, and Shortcuts
