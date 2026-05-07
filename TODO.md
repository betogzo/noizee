# TODO

## Sparkle (auto-update)

- [ ] **Fix or remove** built-in auto-update for non–Apple Developer ID distributions: either point `SUFeedURL` / signing at your own release pipeline and EdDSA keys, or strip Sparkle from shipping builds so users are not offered updates that cannot be verified. See `docs/adr/0007-sparkle-auto-updates.md`.

## Last.fm

- [ ] Create a [Last.fm API application](https://www.last.fm/api/account) (your own API key + shared secret), deploy or configure the Cloudflare Worker in `worker/`, and set `LASTFM_API_KEY` / `LASTFM_SHARED_SECRET` via Wrangler — do not ship or rely on another creator’s credentials.
