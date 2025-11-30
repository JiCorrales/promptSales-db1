import OpenAI from "openai"

let openaiClient: OpenAI | null = null

function getOpenAI() {
    if (!openaiClient) {
        const key = process.env.OPENAI_API_KEY
        if (!key) throw new Error("OPENAI_API_KEY_MISSING")
        openaiClient = new OpenAI({ apiKey: key })
    }
    return openaiClient
}

export async function generateEmbedding(text: string) {
    const model = process.env.EMBED_MODEL
    if (!model) throw new Error("EMBED_MODEL_MISSING")

    const client = getOpenAI()
    console.log("[embeddings] create", { model, inputLen: text?.length })
    const resp = await client.embeddings.create({ model, input: text })
    return resp.data[0].embedding
}
