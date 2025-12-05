import { Client } from "pg"

let pgClient: Client | null = null

/**
 * The function `getPostgresClient` returns a PostgreSQL client after connecting to the database using
 * the provided URL.
 * @returns The `getPostgresClient` function returns a Postgres client object after connecting to the
 * database. If the client object already exists, it will return the existing client without creating a
 * new one.
 */
export async function getPostgresClient() {
    if (pgClient) return pgClient
    const url = process.env.PG_URL
    if (!url) throw new Error("PG_URL_MISSING")
    pgClient = new Client({ connectionString: url })
    await pgClient.connect()
    return pgClient
}
