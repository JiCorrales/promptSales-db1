"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateEmbedding = generateEmbedding;
const openai_1 = __importDefault(require("openai"));
let openaiClient = null;
function getOpenAI() {
    if (!openaiClient) {
        const key = process.env.OPENAI_API_KEY;
        if (!key)
            throw new Error("OPENAI_API_KEY_MISSING");
        openaiClient = new openai_1.default({ apiKey: key });
    }
    return openaiClient;
}
async function generateEmbedding(text) {
    const model = process.env.EMBED_MODEL;
    if (!model)
        throw new Error("EMBED_MODEL_MISSING");
    const client = getOpenAI();
    console.log("[embeddings] create", { model, inputLen: text?.length });
    const resp = await client.embeddings.create({ model, input: text });
    return resp.data[0].embedding;
}
