"use strict";
/**
 * @file Utilidades para autenticación y búsqueda de pistas en Spotify.
 * @description
 * - Obtiene y cachea el token de Spotify usando Client Credentials.
 * - Expone una función `searchTrack` con caché en memoria y reintentos.
 */
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.getSpotifyToken = getSpotifyToken;
exports.searchTrack = searchTrack;
const axios_1 = __importDefault(require("axios"));
/**
 * Token de acceso actual de Spotify (Client Credentials).
 * Se mantiene en memoria y se renueva automáticamente al expirar.
 * @type {string | null}
 */
let token = null;
/**
 * Marca de tiempo (en ms desde epoch) en la que el token actual expira.
 * @type {number}
 */
let expiresAt = 0;
/**
 * Caché en memoria para resultados de búsqueda de pistas.
 * La clave es `${query}:${limit}`.
 *
 * @type {Map<string, { ts: number; data: any }>}
 */
const cache = new Map();
/**
 * Tiempo de vida (TTL) de los elementos del caché, en milisegundos.
 * Actualmente: 5 minutos.
 *
 * @type {number}
 */
const TTL = 5 * 60 * 1000;
/**
 * Lee las credenciales de Spotify del entorno.
 *
 * Variables de entorno requeridas:
 * - `SPOTIFY_CLIENT_ID`
 * - `SPOTIFY_CLIENT_SECRET`
 *
 * @returns {{ id: string; secret: string } | null}
 *          Objeto con `id` y `secret`, o `null` si no están configuradas.
 */
function getCreds() {
    const id = process.env.SPOTIFY_CLIENT_ID;
    const secret = process.env.SPOTIFY_CLIENT_SECRET;
    if (!id || !secret)
        return null;
    return { id, secret };
}
/**
 * Realiza la obtención/renovación del token de Spotify usando
 * el flujo de Client Credentials.
 *
 * Implementa reintentos con backoff fijo:
 * - 0 ms
 * - 300 ms
 * - 1000 ms
 *
 * @async
 * @returns {Promise<string | null>}
 *          El token de acceso si fue posible obtenerlo, o `null` en caso de fallo.
 */
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
            // Restamos 30 segundos para evitar usar token justo al expirar
            expiresAt = Date.now() + (res.data.expires_in - 30) * 1000;
            return token;
        }
        catch { }
        await new Promise(r => setTimeout(r, delayMs));
    }
    return null;
}
/**
 * Obtiene un token de Spotify válido.
 *
 * - Si no hay token o está expirado, llama internamente a `refreshToken`.
 * - Si ya existe un token y no ha expirado, lo reutiliza.
 *
 * @async
 * @returns {Promise<string | null>}
 *          Token de acceso actual o `null` si no se pudo obtener.
 */
async function getSpotifyToken() {
    if (!token || Date.now() >= expiresAt) {
        return await refreshToken();
    }
    return token;
}
/**
 * @typedef {Object} TrackResult
 * @property {string} id       ID de la pista en Spotify.
 * @property {string} name     Nombre de la pista.
 * @property {string} artist   Nombre(s) del/los artista(s).
 * @property {string} album    Nombre del álbum.
 * @property {string | null} preview  URL del preview de audio (puede ser `null`).
 * @property {number} popularity      Popularidad de la pista (0–100).
 * @property {string} url     URL pública de la pista en Spotify.
 */
/**
 * Busca pistas en Spotify usando la API de búsqueda.
 *
 * Características:
 * - Usa `getSpotifyToken` para obtener el token.
 * - Cachea los resultados por `(query, limit)` durante `TTL` ms.
 * - Implementa reintentos con backoff fijo (0, 300, 1000 ms).
 * - En caso de fallar repetidamente o no tener token, retorna pistas mock.
 *
 * @async
 * @param {string} query Texto de búsqueda (título, artista, etc.).
 * @param {number} [limit=5] Número máximo de pistas a retornar (1–50 recomendado).
 * @returns {Promise<TrackResult[]>}
 *          Arreglo de pistas que coinciden con la búsqueda (o mock en caso de fallo).
 */
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
/**
 * Genera resultados de pistas ficticias (mock) cuando no es posible
 * consultar la API de Spotify.
 *
 * Cada pista se construye a partir del `query` y un índice incremental.
 *
 * @param {string} query Texto de búsqueda original (se usa para el nombre/ID mock).
 * @param {number} limit Cantidad de pistas mock a generar.
 * @returns {TrackResult[]} Arreglo de pistas mock.
 */
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
