"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.searchTrack = searchTrack;
const axios_1 = __importDefault(require("axios"));
let spotifyTokenCache = null;
async function getSpotifyToken() {
    const clientId = process.env.SPOTIFY_CLIENT_ID;
    const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;
    if (!clientId || !clientSecret)
        throw new Error("SPOTIFY_ENV_MISSING");
    const now = Date.now();
    if (spotifyTokenCache && spotifyTokenCache.expiresAt > now + 60_000) {
        return spotifyTokenCache.token;
    }
    const authHeader = Buffer.from(`${clientId}:${clientSecret}`).toString("base64");
    const response = await axios_1.default.post("https://accounts.spotify.com/api/token", "grant_type=client_credentials", { headers: { Authorization: `Basic ${authHeader}`, "Content-Type": "application/x-www-form-urlencoded" } });
    const { access_token, expires_in } = response.data;
    spotifyTokenCache = { token: access_token, expiresAt: now + expires_in * 1000 };
    return access_token;
}
async function searchTrack(query, limit = 5) {
    const token = await getSpotifyToken();
    const response = await axios_1.default.get("https://api.spotify.com/v1/search", {
        headers: { Authorization: `Bearer ${token}` },
        params: { q: query, type: "track", limit }
    });
    const tracks = response.data?.tracks?.items || [];
    return tracks.map((track) => ({
        id: track.id,
        name: track.name,
        artist: track.artists?.[0]?.name || "Unknown",
        album: track.album?.name || "Unknown",
        preview: track.preview_url,
        popularity: track.popularity,
        url: track.external_urls.spotify
    }));
}
