"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSpotifyToken = getSpotifyToken;
exports.searchTrack = searchTrack;
const axios_1 = __importDefault(require("axios"));
let token = null;
let expiresAt = 0;
const cache = new Map();
const TTL = 5 * 60 * 1000;


function getCreds() {
    const id = process.env.SPOTIFY_CLIENT_ID;
    const secret = process.env.SPOTIFY_CLIENT_SECRET;
    if (!id || !secret)
        return null;
    return { id, secret };
}


async function refreshToken() {
    const tries = [0, 300, 1000];
    for (const delayMs of tries) {
        try {
            const creds = getCreds();
            if (!creds)
                return null;
            const res = await axios_1.default.post("https://accounts.spotify.com/api/token", new URLSearchParams({
                grant_type: "client_credentials"
            }), {
                headers: {
                    Authorization: "Basic " + Buffer.from(`${creds.id}:${creds.secret}`).toString("base64"),
                    "Content-Type": "application/x-www-form-urlencoded"
                }
            });
            token = res.data.access_token;
            expiresAt = Date.now() + (res.data.expires_in - 30) * 1000;
            return token;
        }
        catch { }
        await new Promise(r => setTimeout(r, delayMs));
    }
    return null;
}


async function getSpotifyToken() {
    if (!token || Date.now() >= expiresAt) {
        return await refreshToken();
    }
    return token;
}


async function searchTrack(query, limit = 5) {
    const key = `${query}:${limit}`;
    const now = Date.now();
    const cached = cache.get(key);
    if (cached && now - cached.ts < TTL)
        return cached.data;
    const tok = await getSpotifyToken();
    if (!tok)
        return mockTracks(query, limit);
    const tries = [0, 300, 1000];
    for (const delayMs of tries) {
        try {
            const res = await axios_1.default.get("https://api.spotify.com/v1/search", {
                headers: { Authorization: `Bearer ${tok}` },
                params: { q: query, type: "track", limit }
            });
            const data = res.data.tracks.items.map((t) => ({
                id: t.id,
                name: t.name,
                artist: t.artists.map((a) => a.name).join(", "),
                album: t.album.name,
                preview: t.preview_url,
                popularity: t.popularity,
                url: t.external_urls.spotify
            }));
            cache.set(key, { ts: now, data });
            return data;
        }
        catch { }
        await new Promise(r => setTimeout(r, delayMs));
    }
    return mockTracks(query, limit);
}


function mockTracks(query, limit) {
    const tracks = [];
    for (let i = 0; i < limit; i++) {
        tracks.push({
            id: `mock_${query}_${i}`,
            name: `${query} - Track ${i + 1}`,
            artist: `Artista ${i + 1}`,
            album: `Álbum ${i + 1}`,
            preview: null,
            popularity: Math.floor(Math.random() * 100),
            url: "https://open.spotify.com/track/mock"
        });
    }
    return tracks;
}
