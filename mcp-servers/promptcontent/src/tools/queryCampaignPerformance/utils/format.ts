export function formatLargeNumber(n: number | null | undefined) {
    if (n === null || n === undefined || Number.isNaN(n)) return "N/D"
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
    return String(n)
}

export function formatPercent(n: number | null | undefined) {
    if (n === null || n === undefined || Number.isNaN(n)) return "N/D"
    return `${(n * 100).toFixed(1)}%`
}
