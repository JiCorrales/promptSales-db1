import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { Int32 } from "mongodb"
import { z } from "zod"
import { getDb } from "../../db"
import { generateMessagesWithAI } from "./ai/messages"
import { AudienceTarget, getAudienceWithAI } from "./ai/audience"

export function registerCreateCampaignMessagesTool(server: McpServer) {
    server.registerTool(
        "createCampaignMessages",
        {
            title: "Crear mensajes para campaña de marketing",
            description:
                "Crea tres mensajes para una campaña de mercadeo a partir de una descripción textual. El tool detecta las audiencias con IA y genera una bitácora automática de tres mensajes adaptados al público objetivo, utilizando la información inferida sobre la campaña. Los mensajes deben ser coherentes con el propósito de la campaña, reflejar el tono adecuado para ese público meta y registrar en la bitácora cualquier decisión creativa tomada. El resultado incluye: ID de la campaña creada, la solicitud original, las audiencias detectadas, los mensajes generados y la bitácora de consideraciones creativas.",
            inputSchema: {
                descripcion: z
                    .string()
                    .describe("Descripción detallada de la campaña de mercadeo para la cual se desean generar los mensajes.")
            },
            outputSchema: {
                _id: z.string().optional(),
                logId: z.string(),
                campaignRef: z.string(),
                audience: z.array(
                    z.object({
                        audience: z.string(),
                        ageRange: z.string(),
                        gender: z.string(),
                        interests: z.array(z.string()),
                        location: z.string(),
                        lifestyle: z.string().nullable(),
                        profession: z.string().nullable(),
                        needs: z.array(z.string()),
                        objective: z.string(),
                        tone: z.string(),
                        cta: z.string()
                    })
                ),
                messages: z.array(
                    z.object({
                        role: z.string(),
                        text: z.string(),
                        ts: z.string()
                    })
                ),
                messageCount: z.number().int(),
                lastMessageTs: z.string(),
                createdAt: z.string()
            }
        },
        async ({ descripcion }) => {
            const campaignId = `campaign_${Date.now()}`
            const audienceProfiles: AudienceTarget[] = await getAudienceWithAI(descripcion)
            if (!Array.isArray(audienceProfiles) || audienceProfiles.length === 0) {
                throw new Error("audience_ai_failed")
            }

            const generatedSegments: any[] = []
            // Generate messages for each audience segment
            for (const [audienceIndex, singleAudience] of audienceProfiles.entries()) {
                const aiSegments = await generateMessagesWithAI(descripcion, [singleAudience], {
                    campaignRef: campaignId,
                    segmentKey: `audience_${audienceIndex + 1}`
                })
                if (!Array.isArray(aiSegments) || aiSegments.length === 0) throw new Error("ai_failed")

                const selectedSegment = aiSegments[0]
                const campaignMessages = Array.isArray(selectedSegment.mensajes) ? selectedSegment.mensajes.slice(0, 3) : []
                if (campaignMessages.length !== 3) throw new Error("ai_failed_incomplete_messages")

                generatedSegments.push({
                    ...selectedSegment,
                    nombre: selectedSegment.nombre || `Audiencia ${audienceIndex + 1}`,
                    mensajes: campaignMessages,
                    audienceIndex
                })
            }

            const campaignSegments = generatedSegments
            const campaignCreatedAt = new Date()

            const campaignMessages = campaignSegments.flatMap((segment: any) =>
                segment.mensajes.map((message: any) => ({
                    ts: new Date(),
                    text: `[Audiencia ${segment.audienceIndex + 1} - ${segment.nombre}] ${message.tipo}: ${message.texto}`,
                    role: "assistant"
                }))
            )

            const totalMessageCount = campaignMessages.length
            const messageCountInt32 = new Int32(totalMessageCount)
            const lastMessageTimestamp = totalMessageCount ? campaignMessages[totalMessageCount - 1].ts : campaignCreatedAt

            let insertedMongoId: string | undefined

            const audienceDescription = audienceProfiles
                .map((audience: AudienceTarget, index: number) => {
                    const interestsList = Array.isArray(audience.interests) ? audience.interests.join(",") : ""
                    return `#${index + 1}:${audience.ageRange}|${interestsList}|${audience.location}|${audience.gender}`.trim()
                })
                .join(" || ")

            try {
                const database = await getDb()
                const campaignLogInsert = await database.collection("CampaignLogs").insertOne({
                    logId: campaignId,
                    campaignRef: campaignId,
                    audience: audienceDescription,
                    messages: campaignMessages,
                    messageCount: messageCountInt32,
                    lastMessageTs: lastMessageTimestamp,
                    createdAt: campaignCreatedAt
                })
                insertedMongoId = campaignLogInsert?.insertedId ? String(campaignLogInsert.insertedId) : undefined

                await database.collection("AIRequests").insertOne({
                    aiRequestId: campaignId,
                    createdAt: campaignCreatedAt,
                    completedAt: new Date(),
                    status: "completed",
                    modality: "text",
                    prompt: descripcion,
                    context: {
                        type: "text",
                        language: "es",
                        campaignRef: campaignId
                    },
                    requestBody: { audiencias: audienceProfiles },
                    mcp: { serverKey: "mcp-server-promptcontent", tool: "generateCampaignMessages" }
                })
            } catch (persistError) {
                console.error("CampaignLogs/AIRequests persistence error", persistError)
            }

            const responsePayload = {
                _id: insertedMongoId,
                logId: campaignId,
                campaignRef: campaignId,
                audience: audienceProfiles.map((audience: AudienceTarget) => ({
                    audience: audience.audience,
                    ageRange: audience.ageRange,
                    gender: audience.gender,
                    interests: audience.interests,
                    location: audience.location,
                    lifestyle: audience.lifestyle || null,
                    profession: audience.profession || null,
                    needs: audience.needs,
                    objective: audience.objective,
                    tone: audience.tone,
                    cta: audience.cta
                })),
                messages: campaignMessages.map((message: { role: string; text: string; ts: Date }) => ({
                    role: message.role,
                    text: message.text,
                    ts: (message.ts as Date).toISOString()
                })),
                messageCount: totalMessageCount,
                lastMessageTs: lastMessageTimestamp.toISOString(),
                createdAt: campaignCreatedAt.toISOString()
            }

            return {
                content: [{ type: "text", text: JSON.stringify(responsePayload) }],
                structuredContent: responsePayload
            }
        }
    )
}
