"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getDb = getDb;
const mongodb_1 = require("mongodb");
let mongoClient = null;
let mongoDb = null;
async function getDb() {
    if (mongoDb)
        return mongoDb;
    const uri = process.env.MONGODB_URI;
    const dbName = process.env.MONGODB_DB;
    if (!uri || !dbName)
        throw new Error("MONGODB_ENV_MISSING");
    mongoClient = await new mongodb_1.MongoClient(uri).connect();
    mongoDb = mongoClient.db(dbName);
    try {
        const imagesCol = mongoDb.collection("images");
        await imagesCol.createIndex({ alt: "text" }, { name: "images_text_alt" });
    }
    catch { }
    return mongoDb;
}
