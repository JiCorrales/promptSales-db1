export function normalizeHashtag(tag: string) {
    const cleaned = tag.trim().replace(/\s+/g, "_").replace(/[^a-zA-Z0-9_]/g, "")
    return cleaned.startsWith("#") ? cleaned : `#${cleaned.toLowerCase()}`
}

export function extractHashtags(text: string) {
    const lower = text.toLowerCase()
    const tokens = lower.split(/[^a-z0-9áéíóúñ]+/i).filter(Boolean)
    const words = tokens.filter(token => token.length > 2)
    const unique = Array.from(new Set(words))
    return unique.slice(0, 15).map(word => normalizeHashtag(word))
}
