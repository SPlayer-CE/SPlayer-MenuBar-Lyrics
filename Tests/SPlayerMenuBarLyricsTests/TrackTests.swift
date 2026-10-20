import XCTest
@testable import SPlayerMenuBarLyrics

final class TrackTests: XCTestCase {
    func testDecodesLiveAPIShape() throws {
        let json = """
        {
          "id": "2138811507",
          "source": "netease",
          "title": "2WORLDS",
          "artists": [{"name": "VALORANT"}, {"name": "Madge"}],
          "album": {"id": "189930991", "name": "2WORLDS", "cover": "https://example.com/album.jpg"},
          "duration": 149333,
          "cover": "https://example.com/cover.jpg",
          "coverOriginal": "https://example.com/original.jpg",
          "comment": "theme song"
        }
        """.data(using: .utf8)!

        let track = try JSONDecoder().decode(Track.self, from: json)

        XCTAssertEqual(track.title, "2WORLDS")
        XCTAssertEqual(track.artistsText, "VALORANT / Madge")
        XCTAssertEqual(track.albumText, "2WORLDS")
        XCTAssertEqual(track.durationSeconds ?? 0, 149.333, accuracy: 0.001)
        XCTAssertEqual(track.artworkURL?.absoluteString, "https://example.com/original.jpg")
    }

    func testArtworkFallsBackToAlbumCover() throws {
        let json = """
        {
          "id": "1",
          "title": "Song",
          "artists": [{"name": "Artist"}],
          "album": {"name": "Album", "cover": "https://example.com/album.jpg"},
          "cover": null,
          "coverOriginal": ""
        }
        """.data(using: .utf8)!

        let track = try JSONDecoder().decode(Track.self, from: json)

        XCTAssertEqual(track.artworkURL?.absoluteString, "https://example.com/album.jpg")
    }

    func testMissingArtworkReturnsNil() throws {
        let json = """
        {"id": "1", "title": "Song", "artists": [], "duration": 1000}
        """.data(using: .utf8)!

        let track = try JSONDecoder().decode(Track.self, from: json)

        XCTAssertNil(track.artworkURL)
    }
}
