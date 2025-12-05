export function parseSegmentsPayload(raw: string) {
    const fenced = (raw || "").trim().replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim()
    const start = fenced.indexOf("{")
    const end = fenced.lastIndexOf("}")
    const candidates = [fenced]
    if (start !== -1 && end !== -1 && end > start) {
        candidates.push(fenced.slice(start, end + 1))
    }
    for (const candidate of candidates) {
        try {
            return JSON.parse(candidate)
        } catch {
            continue
        }
    }
    return null
}
