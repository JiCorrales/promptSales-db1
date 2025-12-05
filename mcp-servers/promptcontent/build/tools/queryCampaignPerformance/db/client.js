"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getPostgresClient = getPostgresClient;
const pg_1 = require("pg");
let pgClient = null;
async function getPostgresClient() {
    if (pgClient)
        return pgClient;
    const url = process.env.PG_URL;
    if (!url)
        throw new Error("PG_URL_MISSING");
    pgClient = new pg_1.Client({ connectionString: url });
    await pgClient.connect();
    return pgClient;
}
