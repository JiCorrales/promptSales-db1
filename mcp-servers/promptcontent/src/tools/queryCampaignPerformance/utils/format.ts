/**
 * This TypeScript function named `formatPercent` takes a number as input and returns a formatted
 * percentage value.
 * @param {number | null | undefined} n - The `n` parameter in the `formatPercent` function is a
 * number, null, or undefined value that represents a percentage value to be formatted.
 */
export function formatLargeNumber(n: number | null | undefined) {
    if (n === null || n === undefined || Number.isNaN(n)) return "N/D"
    if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`
    if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`
    return String(n)
}

/**
 * The `formatPercent` function takes a number as input and returns it formatted as a percentage with
 * one decimal place, or "N/D" if the input is null, undefined, or NaN.
 * @param {number | null | undefined} n - The `n` parameter in the `formatPercent` function is a number
 * that represents a percentage value. It can also be `null` or `undefined` to indicate the absence of
 * a value, or `NaN` (Not a Number) to represent an invalid number.
 * @returns The function `formatPercent` returns a formatted percentage value if the input `n` is a
 * valid number, otherwise it returns the string "N/D".
 */
export function formatPercent(n: number | null | undefined) {
    if (n === null || n === undefined || Number.isNaN(n)) return "N/D"
    return `${(n * 100).toFixed(1)}%`
}
