import Foundation
import MediaPlayer

// MARK: - Get Now Playing
struct GetNowPlayingTool: ClaudeTool {
    let name = "get_now_playing"
    let description = "Get information about the currently playing music track"
    let category = ToolCategory.media

    let parameters: [ToolParameter] = []
    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let player = MPMusicPlayerController.systemMusicPlayer

        guard let nowPlaying = player.nowPlayingItem else {
            return "No music is currently playing."
        }

        var result = "Now Playing:\n"
        result += "- Title: \(nowPlaying.title ?? "Unknown")\n"
        result += "- Artist: \(nowPlaying.artist ?? "Unknown")\n"
        result += "- Album: \(nowPlaying.albumTitle ?? "Unknown")\n"

        let duration = Int(nowPlaying.playbackDuration)
        result += "- Duration: \(duration / 60):\(String(format: "%02d", duration % 60))\n"

        let currentTime = Int(player.currentPlaybackTime)
        result += "- Position: \(currentTime / 60):\(String(format: "%02d", currentTime % 60))\n"

        let state: String
        switch player.playbackState {
        case .playing: state = "Playing"
        case .paused: state = "Paused"
        case .stopped: state = "Stopped"
        default: state = "Unknown"
        }
        result += "- State: \(state)\n"

        if nowPlaying.rating > 0 {
            result += "- Rating: \(nowPlaying.rating)/5\n"
        }

        if nowPlaying.genre != nil {
            result += "- Genre: \(nowPlaying.genre!)\n"
        }

        return result
    }
}

// MARK: - Play/Pause Music
struct PlayPauseMusicTool: ClaudeTool {
    let name = "play_pause_music"
    let description = "Toggle play/pause for the current music playback"
    let category = ToolCategory.media

    let parameters = [
        ToolParameter(name: "action", type: .string, description: "Action to perform", enumValues: ["play", "pause", "toggle"])
    ]

    let requiredParams: [String] = []

    func execute(with arguments: [String: Any]) async throws -> String {
        let player = MPMusicPlayerController.systemMusicPlayer
        let action = arguments["action"] as? String ?? "toggle"

        switch action {
        case "play":
            player.play()
            return "Music playback started."
        case "pause":
            player.pause()
            return "Music playback paused."
        default:
            if player.playbackState == .playing {
                player.pause()
                return "Music paused."
            } else {
                player.play()
                return "Music resumed."
            }
        }
    }
}

// MARK: - Skip Track
struct SkipTrackTool: ClaudeTool {
    let name = "skip_track"
    let description = "Skip to the next or previous track"
    let category = ToolCategory.media

    let parameters = [
        ToolParameter(name: "direction", type: .string, description: "Skip direction", enumValues: ["next", "previous"], isRequired: true)
    ]

    let requiredParams = ["direction"]

    func execute(with arguments: [String: Any]) async throws -> String {
        let player = MPMusicPlayerController.systemMusicPlayer
        let direction = arguments["direction"] as? String ?? "next"

        if direction == "previous" {
            player.skipToPreviousItem()
        } else {
            player.skipToNextItem()
        }

        // Brief pause to let the player update
        try await Task.sleep(nanoseconds: 500_000_000)

        if let nowPlaying = player.nowPlayingItem {
            return "Skipped \(direction). Now playing: \(nowPlaying.title ?? "Unknown") by \(nowPlaying.artist ?? "Unknown")"
        }
        return "Skipped \(direction)."
    }
}
