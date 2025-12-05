"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.formatLargeNumber = formatLargeNumber;
exports.formatPercent = formatPercent;
function formatLargeNumber(n) {
    if (n === null || n === undefined || Number.isNaN(n))
        return "N/D";
    if (n >= 1_000_000)
        return `${(n / 1_000_000).toFixed(1)}M`;
    if (n >= 1_000)
        return `${(n / 1_000).toFixed(1)}K`;
    return String(n);
}
function formatPercent(n) {
    if (n === null || n === undefined || Number.isNaN(n))
        return "N/D";
    return `${(n * 100).toFixed(1)}%`;
}
