import https from 'node:https';

// Simple OAuth2 Client Credentials for Spotify
// Requires env: SPOTIFY_CLIENT_ID, SPOTIFY_CLIENT_SECRET
// Obtains token via POST and caches with expiry; renews on expiration.

let cachedToken = null;
let tokenExpiresAt = 0;

function formEncode(params) {
  return Object.entries(params)
    .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
    .join('&');
}

export async function getSpotifyToken() {
  const now = Date.now();
  if (cachedToken && now < tokenExpiresAt - 5000) return cachedToken;
  const clientId = process.env.SPOTIFY_CLIENT_ID;
  const clientSecret = process.env.SPOTIFY_CLIENT_SECRET;
  if (!clientId || !clientSecret) throw new Error('SPOTIFY_CLIENT_ID/SECRET no configurados');
  const auth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  const body = formEncode({ grant_type: 'client_credentials' });
  const resp = await httpPost('https://accounts.spotify.com/api/token', body, {
    'Authorization': `Basic ${auth}`,
    'Content-Type': 'application/x-www-form-urlencoded'
  });
  const data = JSON.parse(resp);
  if (!data.access_token) throw new Error(`Error token Spotify: ${resp}`);
  cachedToken = data.access_token;
  tokenExpiresAt = now + (data.expires_in ?? 3600) * 1000;
  return cachedToken;
}

export async function spotifySearchAlbums(query, limit = 50, offset = 0) {
  const token = await getSpotifyToken();
  const url = `https://api.spotify.com/v1/search?q=${encodeURIComponent(query)}&type=album&limit=${limit}&offset=${offset}`;
  const resp = await httpGet(url, { Authorization: `Bearer ${token}` });
  const data = JSON.parse(resp);
  const items = data.albums?.items ?? [];
  // Map to image metadata entries
  return items.map((al) => ({
    id: al.id,
    title: al.name,
    url: al.images?.[0]?.url ?? null,
    artists: (al.artists ?? []).map((a) => a.name),
    releaseDate: al.release_date ?? null
  })).filter((i) => i.url);
}

function httpGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, { method: 'GET', headers }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) resolve(data);
        else reject(new Error(`GET ${url} -> ${res.statusCode}: ${data}`));
      });
    });
    req.on('error', reject);
    req.end();
  });
}

function httpPost(url, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.request(url, { method: 'POST', headers }, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        if (res.statusCode && res.statusCode >= 200 && res.statusCode < 300) resolve(data);
        else reject(new Error(`POST ${url} -> ${res.statusCode}: ${data}`));
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

export default {
  getSpotifyToken,
  spotifySearchAlbums
};

