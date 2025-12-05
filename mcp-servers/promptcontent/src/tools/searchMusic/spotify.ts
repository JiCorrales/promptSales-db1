import axios from "axios"

let spotifyTokenCache: { token: string; expiresAt: number } | null = null

async function getSpotifyToken() {
    const clientId = process.env.SPOTIFY_CLIENT_ID
    const clientSecret = process.env.SPOTIFY_CLIENT_SECRET
    if (!clientId || !clientSecret) throw new Error("SPOTIFY_ENV_MISSING")

    const now = Date.now()
    if (spotifyTokenCache && spotifyTokenCache.expiresAt > now + 60_000) {
        return spotifyTokenCache.token
    }

    const authHeader = Buffer.from(`${clientId}:${clientSecret}`).toString("base64")
    const response = await axios.post(
        "https://accounts.spotify.com/api/token",
        "grant_type=client_credentials",
        { headers: { Authorization: `Basic ${authHeader}`, "Content-Type": "application/x-www-form-urlencoded" } }
    )

    const { access_token, expires_in } = response.data
    spotifyTokenCache = { token: access_token, expiresAt: now + expires_in * 1000 }
    return access_token
}

export async function searchTrack(query: string, limit = 5) {
    const token = await getSpotifyToken()
    const response = await axios.get("https://api.spotify.com/v1/search", {
        headers: { Authorization: `Bearer ${token}` },
        params: { q: query, type: "track", limit }
    })

    const tracks = response.data?.tracks?.items || []
    return tracks.map((track: any) => ({
        id: track.id,
        name: track.name,
        artist: track.artists?.[0]?.name || "Unknown",
        album: track.album?.name || "Unknown",
        preview: track.preview_url,
        popularity: track.popularity,
        url: track.external_urls.spotify
    }))
}
