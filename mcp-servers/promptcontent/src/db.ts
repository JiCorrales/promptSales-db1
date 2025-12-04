import { MongoClient, Db } from "mongodb"

let mongoClient: MongoClient | null = null
let mongoDb: Db | null = null

export async function getDb() {
    if (mongoDb) return mongoDb
    const uri = process.env.MONGODB_URI
    const dbName = process.env.MONGODB_DB
    if (!uri || !dbName) throw new Error("MONGODB_ENV_MISSING")

    mongoClient = await new MongoClient(uri).connect()
    mongoDb = mongoClient.db(dbName)
    try {
        const imagesCol = mongoDb.collection("images")
        await imagesCol.createIndex({ alt: "text" }, { name: "images_text_alt" })
    } catch {}
    return mongoDb
}
