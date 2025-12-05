import { Client } from "pg"

let pgClient: Client | null = null

export async function getPostgresClient() {
    if (pgClient) return pgClient
    const url = process.env.PG_URL
    if (!url) throw new Error("PG_URL_MISSING")
    pgClient = new Client({ connectionString: url })
    await pgClient.connect()
    return pgClient
}
