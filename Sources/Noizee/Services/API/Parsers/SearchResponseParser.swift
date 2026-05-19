import Foundation

/// Parser for search responses from YouTube Music API.
enum SearchResponseParser {
    private static let logger = DiagnosticsLogger.api

    /// Parses a search response.
    /// - Parameter excludeVideosCategoryShelves: When true, skips search shelves titled like YouTube Music's Videos category so **All** results favor catalog songs.
    static func parse(_ data: [String: Any], excludeVideosCategoryShelves: Bool = false) -> SearchResponse {
        var songs: [Song] = []
        var albums: [Album] = []
        var artists: [Artist] = []
        var playlists: [Playlist] = []

        guard let sectionContents = Self.preferredUnifiedSearchShelfSections(from: data), !sectionContents.isEmpty else {
            Self.logger.debug("SearchResponseParser: Failed to parse response structure. Top keys: \(data.keys.sorted())")
            if let contents = data["contents"] as? [String: Any] {
                Self.logger.debug("SearchResponseParser: contents keys: \(contents.keys.sorted())")
            }
            return SearchResponse.empty
        }

        for sectionData in sectionContents {
            // Parse musicCardShelfRenderer (Top Result section)
            if let cardShelfRenderer = sectionData["musicCardShelfRenderer"] as? [String: Any] {
                if let item = parseCardShelfRenderer(cardShelfRenderer) {
                    Self.appendItem(item, songs: &songs, albums: &albums, artists: &artists, playlists: &playlists)
                }
            }

            // Parse musicShelfRenderer (regular results)
            if let shelfRenderer = sectionData["musicShelfRenderer"] as? [String: Any],
               let shelfContents = shelfRenderer["contents"] as? [[String: Any]]
            {
                if excludeVideosCategoryShelves,
                   let shelfTitle = ParsingHelpers.browseShelfTitle(forRenderer: shelfRenderer),
                   ParsingHelpers.isVideosCategoryShelfTitle(shelfTitle)
                {
                    continue
                }

                for itemData in shelfContents {
                    if let item = parseSearchResultItem(itemData) {
                        Self.appendItem(item, songs: &songs, albums: &albums, artists: &artists, playlists: &playlists)
                    }
                }
            }
        }

        return SearchResponse(songs: songs, albums: albums, artists: artists, playlists: playlists)
    }

    /// Shelves (`sectionListRenderer.contents`) used for unified (unfiltered) **All** search.
    ///
    /// YouTube Music has returned multiple envelopes:
    /// - `contents.sectionListRenderer` directly (matching filtered endpoints)
    /// - classic `contents.tabbedSearchResultsRenderer.tabs[...]` with one tab flagged `selected`
    /// - newer `contents.singleColumnBrowseResultsRenderer.tabs[...]` (same tab shape as Home)
    ///
    /// We prefer the explicitly selected tab when it carries rows; otherwise the first tab with non-empty rows.
    private static func preferredUnifiedSearchShelfSections(from data: [String: Any]) -> [[String: Any]]? {
        guard let contents = data["contents"] as? [String: Any] else {
            return nil
        }

        if let rows = Self.directSectionListRows(from: contents) {
            return rows
        }

        for rendererKey in ["tabbedSearchResultsRenderer", "singleColumnBrowseResultsRenderer"] {
            guard let nested = contents[rendererKey] as? [String: Any],
                  let tabs = nested["tabs"] as? [[String: Any]]
            else {
                continue
            }
            if let rows = Self.preferredTabbedSectionListRows(tabs: tabs) {
                return rows
            }
        }

        return nil
    }

    private static func directSectionListRows(from contents: [String: Any]) -> [[String: Any]]? {
        guard let renderer = contents["sectionListRenderer"] as? [String: Any],
              let rows = renderer["contents"] as? [[String: Any]],
              !rows.isEmpty
        else {
            return nil
        }
        return rows
    }

    /// Picks either the selected tab's `sectionListRenderer` or the first tab with usable rows (skips empty previews).
    private static func preferredTabSectionListRenderer(tabs: [[String: Any]]) -> [String: Any]? {
        var selectedRenderer: [String: Any]?
        var firstRenderer: [String: Any]?

        for tab in tabs {
            guard let tabRenderer = tab["tabRenderer"] as? [String: Any],
                  let tabContent = tabRenderer["content"] as? [String: Any],
                  let sectionListRenderer = tabContent["sectionListRenderer"] as? [String: Any],
                  let rows = sectionListRenderer["contents"] as? [[String: Any]],
                  !rows.isEmpty
            else {
                continue
            }

            if firstRenderer == nil {
                firstRenderer = sectionListRenderer
            }

            if Self.tabRendererIndicatesSelected(tabRenderer), selectedRenderer == nil {
                selectedRenderer = sectionListRenderer
            }
        }

        return selectedRenderer ?? firstRenderer
    }

    private static func preferredTabbedSectionListRows(tabs: [[String: Any]]) -> [[String: Any]]? {
        guard let renderer = preferredTabSectionListRenderer(tabs: tabs) else {
            return nil
        }
        return renderer["contents"] as? [[String: Any]]
    }

    private static func tabRendererIndicatesSelected(_ tabRenderer: [String: Any]) -> Bool {
        if let explicit = tabRenderer["selected"] as? Bool ?? tabRenderer["isSelected"] as? Bool {
            return explicit
        }
        if tabRenderer["checked"] as? Bool == true {
            return true
        }
        if let checkStatus = tabRenderer["checkStatus"] as? String {
            let normalized = checkStatus.uppercased()

            if normalized.contains("UNCHECK")
                || normalized.contains("UNSELECTED")
                || normalized.contains("NOT_SELECTED")
            {
                return false
            }

            if normalized.contains("CHECKBOX_STATE_CHECKED")
                || normalized.contains("CHECKED")
                || normalized.contains("SELECTED")
            {
                return true
            }
        }

        return tabRenderer["toggled"] as? Bool ?? false
    }

    /// Helper to append a search result item to the appropriate array.
    private static func appendItem(
        _ item: SearchResultItem,
        songs: inout [Song],
        albums: inout [Album],
        artists: inout [Artist],
        playlists: inout [Playlist]
    ) {
        switch item {
        case let .song(song):
            songs.append(song)
        case let .album(album):
            albums.append(album)
        case let .artist(artist):
            artists.append(artist)
        case let .playlist(playlist):
            playlists.append(playlist)
        case .podcastShow:
            // Podcast shows not parsed in general search
            break
        }
    }

    /// Parses a filtered songs-only search response.
    /// Filtered searches have a simpler structure without tabs.
    static func parseSongsOnly(_ data: [String: Any]) -> [Song] {
        var songs: [Song] = []

        // Filtered search has a simpler structure - no tabs
        guard let contents = data["contents"] as? [String: Any],
              let sectionListRenderer = contents["sectionListRenderer"] as? [String: Any],
              let sectionContents = sectionListRenderer["contents"] as? [[String: Any]]
        else {
            // Try tabbed structure as fallback
            let response = self.parse(data)
            return response.songs
        }

        for sectionData in sectionContents {
            if let shelfRenderer = sectionData["musicShelfRenderer"] as? [String: Any],
               let shelfContents = shelfRenderer["contents"] as? [[String: Any]]
            {
                for itemData in shelfContents {
                    if let item = parseSearchResultItem(itemData),
                       case let .song(song) = item
                    {
                        songs.append(song)
                    }
                }
            }
        }

        return songs
    }

    // MARK: - Item Parsing

    /// Parses a musicCardShelfRenderer (Top Result section).
    /// This renderer contains a single prominent result with title, subtitle, and browse endpoint.
    private static func parseCardShelfRenderer(_ data: [String: Any]) -> SearchResultItem? {
        // Extract title and navigation from the title runs
        guard let titleData = data["title"] as? [String: Any],
              let runs = titleData["runs"] as? [[String: Any]],
              let firstRun = runs.first,
              let title = firstRun["text"] as? String,
              let navigationEndpoint = firstRun["navigationEndpoint"] as? [String: Any],
              let browseEndpoint = navigationEndpoint["browseEndpoint"] as? [String: Any],
              let browseId = browseEndpoint["browseId"] as? String
        else {
            return nil
        }

        // Extract thumbnail
        let thumbnails = ParsingHelpers.extractThumbnails(from: data)
        let thumbnailURL = thumbnails.last.flatMap { URL(string: $0) }

        // Extract subtitle
        var subtitle: String?
        if let subtitleData = data["subtitle"] as? [String: Any],
           let subtitleRuns = subtitleData["runs"] as? [[String: Any]]
        {
            subtitle = subtitleRuns.compactMap { $0["text"] as? String }.joined()
        }

        let pageType = ParsingHelpers.extractPageType(from: browseEndpoint)
        return self.createItemFromBrowseEndpoint(
            browseId: browseId,
            pageType: pageType,
            title: title,
            thumbnailURL: thumbnailURL,
            subtitle: subtitle
        )
    }

    private static func parseSearchResultItem(_ data: [String: Any]) -> SearchResultItem? {
        guard let responsiveRenderer = data["musicResponsiveListItemRenderer"] as? [String: Any] else {
            return nil
        }

        // Try to get videoId for songs
        if let playlistItemData = responsiveRenderer["playlistItemData"] as? [String: Any],
           let videoId = playlistItemData["videoId"] as? String
        {
            return self.parseSongFromResponsiveRenderer(responsiveRenderer, videoId: videoId)
        }

        // Check navigation endpoint for other types
        if let navigationEndpoint = responsiveRenderer["navigationEndpoint"] as? [String: Any],
           let browseEndpoint = navigationEndpoint["browseEndpoint"] as? [String: Any],
           let browseId = browseEndpoint["browseId"] as? String
        {
            let thumbnails = ParsingHelpers.extractThumbnails(from: responsiveRenderer)
            let thumbnailURL = thumbnails.last.flatMap { URL(string: $0) }
            let title = ParsingHelpers.extractTitleFromFlexColumns(responsiveRenderer) ?? "Unknown"
            let subtitle = ParsingHelpers.extractSubtitleFromFlexColumns(responsiveRenderer)

            let pageType = ParsingHelpers.extractPageType(from: browseEndpoint)
            return self.createItemFromBrowseEndpoint(
                browseId: browseId,
                pageType: pageType,
                title: title,
                thumbnailURL: thumbnailURL,
                subtitle: subtitle
            )
        }

        return nil
    }

    // MARK: - Helpers

    private static func createItemFromBrowseEndpoint(
        browseId: String,
        pageType: String?,
        title: String,
        thumbnailURL: URL?,
        subtitle: String?
    ) -> SearchResultItem? {
        if pageType == "MUSIC_PAGE_TYPE_ALBUM" || browseId.hasPrefix("MPRE") || browseId.hasPrefix("OLAK") {
            let album = Album(
                id: browseId,
                title: title,
                artists: nil,
                thumbnailURL: thumbnailURL,
                year: nil,
                trackCount: nil
            )
            return .album(album)
        }

        if ParsingHelpers.isArtistPageType(pageType) || Artist.isNavigableId(browseId) {
            let artist = Artist(
                id: browseId,
                name: title,
                thumbnailURL: thumbnailURL,
                profileKind: Artist.profileKind(forPageType: pageType)
            )
            return .artist(artist)
        }

        if pageType == "MUSIC_PAGE_TYPE_PLAYLIST" || browseId.hasPrefix("VL") || browseId.hasPrefix("PL") {
            let playlist = Playlist(
                id: browseId,
                title: title,
                description: nil,
                thumbnailURL: thumbnailURL,
                trackCount: nil,
                author: subtitle.map { Artist.inline(name: $0, namespace: "playlist-author") }
            )
            return .playlist(playlist)
        }

        return nil
    }

    private static func parseSongFromResponsiveRenderer(
        _ data: [String: Any],
        videoId: String
    ) -> SearchResultItem? {
        let thumbnails = ParsingHelpers.extractThumbnails(from: data)
        let thumbnailURL = thumbnails.last.flatMap { URL(string: $0) }
        let title = ParsingHelpers.extractTitleFromFlexColumns(data) ?? "Unknown"
        let artists = ParsingHelpers.extractArtistsFromFlexColumns(data)
        let album = ParsingHelpers.extractAlbumFromFlexColumns(data)

        let isExplicit = ParsingHelpers.extractIsExplicit(from: data)
        let song = Song(
            id: videoId,
            title: title,
            artists: artists,
            album: album,
            duration: nil,
            thumbnailURL: thumbnailURL,
            videoId: videoId,
            isExplicit: isExplicit
        )
        return .song(song)
    }

    // MARK: - Filtered Search Parsing

    /// Extracts the continuation token from a filtered search response.
    private static func extractContinuationToken(from sectionListRenderer: [String: Any]) -> String? {
        // Check for continuations array
        if let continuations = sectionListRenderer["continuations"] as? [[String: Any]],
           let firstContinuation = continuations.first,
           let nextContinuationData = firstContinuation["nextContinuationData"] as? [String: Any],
           let token = nextContinuationData["continuation"] as? String
        {
            return token
        }
        return nil
    }

    /// Helper to get sectionListRenderer from filtered search response.
    private static func getSectionListRenderer(from data: [String: Any]) -> [String: Any]? {
        guard let contents = data["contents"] as? [String: Any] else {
            return nil
        }

        // Filtered/top-level payloads — keep legacy behavior (continuation tokens may accompany empty shelves).
        if let sectionListRenderer = contents["sectionListRenderer"] as? [String: Any] {
            return sectionListRenderer
        }

        for rendererKey in ["tabbedSearchResultsRenderer", "singleColumnBrowseResultsRenderer"] {
            guard let nested = contents[rendererKey] as? [String: Any],
                  let tabs = nested["tabs"] as? [[String: Any]],
                  !tabs.isEmpty else { continue }

            // Prefer usable rows (fixes empty introductory tabs during unified-style envelopes).
            if let preferredRenderer = Self.preferredTabSectionListRenderer(tabs: tabs) {
                return preferredRenderer
            }

            if let permissiveRenderer = Self.permissiveFirstTabSectionListRenderer(tabs: tabs) {
                return permissiveRenderer
            }
        }

        return nil
    }

    /// First tab exposing a section list renderer, ignoring whether shelf rows exist (continuation fallback).
    private static func permissiveFirstTabSectionListRenderer(tabs: [[String: Any]]) -> [String: Any]? {
        for tab in tabs {
            guard let tabRenderer = tab["tabRenderer"] as? [String: Any],
                  let tabContent = tabRenderer["content"] as? [String: Any],
                  let sectionListRenderer = tabContent["sectionListRenderer"] as? [String: Any]
            else {
                continue
            }
            return sectionListRenderer
        }
        return nil
    }

    /// Parses albums from a filtered search response with continuation token.
    static func parseAlbumsOnly(_ data: [String: Any]) -> ([Album], String?) {
        var albums: [Album] = []

        guard let sectionListRenderer = getSectionListRenderer(from: data),
              let sectionContents = sectionListRenderer["contents"] as? [[String: Any]]
        else {
            return ([], nil)
        }

        for sectionData in sectionContents {
            if let shelfRenderer = sectionData["musicShelfRenderer"] as? [String: Any],
               let shelfContents = shelfRenderer["contents"] as? [[String: Any]]
            {
                for itemData in shelfContents {
                    if let item = parseSearchResultItem(itemData),
                       case let .album(album) = item
                    {
                        albums.append(album)
                    }
                }
            }
        }

        let token = Self.extractContinuationToken(from: sectionListRenderer)
        return (albums, token)
    }

    /// Parses artists from a filtered search response with continuation token.
    static func parseArtistsOnly(_ data: [String: Any]) -> ([Artist], String?) {
        var artists: [Artist] = []

        guard let sectionListRenderer = getSectionListRenderer(from: data),
              let sectionContents = sectionListRenderer["contents"] as? [[String: Any]]
        else {
            return ([], nil)
        }

        for sectionData in sectionContents {
            if let shelfRenderer = sectionData["musicShelfRenderer"] as? [String: Any],
               let shelfContents = shelfRenderer["contents"] as? [[String: Any]]
            {
                for itemData in shelfContents {
                    if let item = parseSearchResultItem(itemData),
                       case let .artist(artist) = item
                    {
                        artists.append(artist)
                    }
                }
            }
        }

        let token = Self.extractContinuationToken(from: sectionListRenderer)
        return (artists, token)
    }

    /// Parses playlists from a filtered search response with continuation token.
    static func parsePlaylistsOnly(_ data: [String: Any]) -> ([Playlist], String?) {
        var playlists: [Playlist] = []

        guard let sectionListRenderer = getSectionListRenderer(from: data),
              let sectionContents = sectionListRenderer["contents"] as? [[String: Any]]
        else {
            return ([], nil)
        }

        for sectionData in sectionContents {
            if let shelfRenderer = sectionData["musicShelfRenderer"] as? [String: Any],
               let shelfContents = shelfRenderer["contents"] as? [[String: Any]]
            {
                for itemData in shelfContents {
                    if let item = parseSearchResultItem(itemData),
                       case let .playlist(playlist) = item
                    {
                        playlists.append(playlist)
                    }
                }
            }
        }

        let token = Self.extractContinuationToken(from: sectionListRenderer)
        return (playlists, token)
    }

    /// Parses podcasts from a filtered search response with continuation token.
    static func parsePodcastsOnly(_ data: [String: Any]) -> ([PodcastShow], String?) {
        var podcasts: [PodcastShow] = []

        guard let sectionListRenderer = getSectionListRenderer(from: data),
              let sectionContents = sectionListRenderer["contents"] as? [[String: Any]]
        else {
            return ([], nil)
        }

        for sectionData in sectionContents {
            if let shelfRenderer = sectionData["musicShelfRenderer"] as? [String: Any],
               let shelfContents = shelfRenderer["contents"] as? [[String: Any]]
            {
                for itemData in shelfContents {
                    if let show = Self.parsePodcastShowFromSearchResult(itemData) {
                        podcasts.append(show)
                    }
                }
            }
        }

        let token = Self.extractContinuationToken(from: sectionListRenderer)
        return (podcasts, token)
    }

    /// Parses a podcast show from a search result item.
    private static func parsePodcastShowFromSearchResult(_ data: [String: Any]) -> PodcastShow? {
        guard let responsiveRenderer = data["musicResponsiveListItemRenderer"] as? [String: Any] else {
            return nil
        }

        // Check navigation endpoint for browse ID
        guard let navigationEndpoint = responsiveRenderer["navigationEndpoint"] as? [String: Any],
              let browseEndpoint = navigationEndpoint["browseEndpoint"] as? [String: Any],
              let browseId = browseEndpoint["browseId"] as? String,
              browseId.hasPrefix("MPSPP")
        else {
            return nil
        }

        let thumbnails = ParsingHelpers.extractThumbnails(from: responsiveRenderer)
        let thumbnailURL = thumbnails.last.flatMap { URL(string: $0) }
        let title = ParsingHelpers.extractTitleFromFlexColumns(responsiveRenderer) ?? "Unknown Podcast"
        let author = ParsingHelpers.extractSubtitleFromFlexColumns(responsiveRenderer)

        return PodcastShow(
            id: browseId,
            title: title,
            author: author,
            description: nil,
            thumbnailURL: thumbnailURL,
            episodeCount: nil
        )
    }

    /// Parses songs from a filtered search response with continuation token.
    static func parseSongsWithContinuation(_ data: [String: Any]) -> ([Song], String?) {
        var songs: [Song] = []

        guard let sectionListRenderer = getSectionListRenderer(from: data),
              let sectionContents = sectionListRenderer["contents"] as? [[String: Any]]
        else {
            return ([], nil)
        }

        for sectionData in sectionContents {
            if let shelfRenderer = sectionData["musicShelfRenderer"] as? [String: Any],
               let shelfContents = shelfRenderer["contents"] as? [[String: Any]]
            {
                for itemData in shelfContents {
                    if let item = parseSearchResultItem(itemData),
                       case let .song(song) = item
                    {
                        songs.append(song)
                    }
                }
            }
        }

        let token = Self.extractContinuationToken(from: sectionListRenderer)
        return (songs, token)
    }

    /// Parses a search continuation response.
    /// Returns a SearchResponse with all item types and optional continuation token.
    static func parseContinuation(_ data: [String: Any]) -> SearchResponse {
        var songs: [Song] = []
        var albums: [Album] = []
        var artists: [Artist] = []
        var playlists: [Playlist] = []
        var podcastShows: [PodcastShow] = []
        var continuationToken: String?

        // Continuation responses have a different structure
        if let continuationContents = data["continuationContents"] as? [String: Any],
           let musicShelfContinuation = continuationContents["musicShelfContinuation"] as? [String: Any]
        {
            // Parse items
            if let contents = musicShelfContinuation["contents"] as? [[String: Any]] {
                for itemData in contents {
                    // Try to parse as podcast show first (for podcast search continuation)
                    if let show = Self.parsePodcastShowFromSearchResult(itemData) {
                        podcastShows.append(show)
                    } else if let item = parseSearchResultItem(itemData) {
                        Self.appendItem(item, songs: &songs, albums: &albums, artists: &artists, playlists: &playlists)
                    }
                }
            }

            // Extract next continuation token
            if let continuations = musicShelfContinuation["continuations"] as? [[String: Any]],
               let firstContinuation = continuations.first,
               let nextContinuationData = firstContinuation["nextContinuationData"] as? [String: Any],
               let token = nextContinuationData["continuation"] as? String
            {
                continuationToken = token
            }
        }

        return SearchResponse(
            songs: songs,
            albums: albums,
            artists: artists,
            playlists: playlists,
            podcastShows: podcastShows,
            continuationToken: continuationToken
        )
    }
}
