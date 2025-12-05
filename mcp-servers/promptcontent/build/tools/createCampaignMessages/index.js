"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerCreateCampaignMessagesTool = registerCreateCampaignMessagesTool;
const mongodb_1 = require("mongodb");
const zod_1 = require("zod");
const db_1 = require("../../db");
const messages_1 = require("./ai/messages");
const audience_1 = require("./ai/audience");
function registerCreateCampaignMessagesTool(server) {
    server.registerTool("createCampaignMessages", {
        title: "Crear mensajes para campaña de marketing",
        description: "Crea tres mensajes para una campaña de mercadeo a partir de una descripción textual. El tool detecta las audiencias con IA y genera una bitácora automática de tres mensajes adaptados al público objetivo, utilizando la información inferida sobre la campaña. Los mensajes deben ser coherentes con el propósito de la campaña, reflejar el tono adecuado para ese público meta y registrar en la bitácora cualquier decisión creativa tomada. El resultado incluye: ID de la campaña creada, la solicitud original, las audiencias detectadas, los mensajes generados y la bitácora de consideraciones creativas.",
        inputSchema: {
            descripcion: zod_1.z
                .string()
                .describe("Descripción detallada de la campaña de mercadeo para la cual se desean generar los mensajes.")
        },
        outputSchema: {
            _id: zod_1.z.string().optional(),
            logId: zod_1.z.string(),
            campaignRef: zod_1.z.string(),
            audience: zod_1.z.array(zod_1.z.object({
                audience: zod_1.z.string(),
                ageRange: zod_1.z.string(),
                gender: zod_1.z.string(),
                interests: zod_1.z.array(zod_1.z.string()),
                location: zod_1.z.string(),
                lifestyle: zod_1.z.string().nullable(),
                profession: zod_1.z.string().nullable(),
                needs: zod_1.z.array(zod_1.z.string()),
                objective: zod_1.z.string(),
                tone: zod_1.z.string(),
                cta: zod_1.z.string()
            })),
            messages: zod_1.z.array(zod_1.z.object({
                role: zod_1.z.string(),
                text: zod_1.z.string(),
                ts: zod_1.z.string()
            })),
            messageCount: zod_1.z.number().int(),
            lastMessageTs: zod_1.z.string(),
            createdAt: zod_1.z.string()
        }
    }, async ({ descripcion }) => {
        const campaignId = `campaign_${Date.now()}`;
        const audienceProfiles = await (0, audience_1.getAudienceWithAI)(descripcion);
        if (!Array.isArray(audienceProfiles) || audienceProfiles.length === 0) {
            throw new Error("audience_ai_failed");
        }
        const generatedSegments = [];
        // Generate messages for each audience segment
        for (const [audienceIndex, singleAudience] of audienceProfiles.entries()) {
            const aiSegments = await (0, messages_1.generateMessagesWithAI)(descripcion, [singleAudience], {
                campaignRef: campaignId,
                segmentKey: `audience_${audienceIndex + 1}`
            });
            if (!Array.isArray(aiSegments) || aiSegments.length === 0)
                throw new Error("ai_failed");
            const selectedSegment = aiSegments[0];
            const campaignMessages = Array.isArray(selectedSegment.mensajes) ? selectedSegment.mensajes.slice(0, 3) : [];
            if (campaignMessages.length !== 3)
                throw new Error("ai_failed_incomplete_messages");
            generatedSegments.push({
                ...selectedSegment,
                nombre: selectedSegment.nombre || `Audiencia ${audienceIndex + 1}`,
                mensajes: campaignMessages,
                audienceIndex
            });
        }
        const campaignSegments = generatedSegments;
        const campaignCreatedAt = new Date();
        const campaignMessages = campaignSegments.flatMap((segment) => segment.mensajes.map((message) => ({
            ts: new Date(),
            text: `[Audiencia ${segment.audienceIndex + 1} - ${segment.nombre}] ${message.tipo}: ${message.texto}`,
            role: "assistant"
        })));
        const totalMessageCount = campaignMessages.length;
        const messageCountInt32 = new mongodb_1.Int32(totalMessageCount);
        const lastMessageTimestamp = totalMessageCount ? campaignMessages[totalMessageCount - 1].ts : campaignCreatedAt;
        let insertedMongoId;
        const audienceDescription = audienceProfiles
            .map((audience, index) => {
            const interestsList = Array.isArray(audience.interests) ? audience.interests.join(",") : "";
            return `#${index + 1}:${audience.ageRange}|${interestsList}|${audience.location}|${audience.gender}`.trim();
        })
            .join(" || ");
        try {
            const database = await (0, db_1.getDb)();
            const campaignLogInsert = await database.collection("CampaignLogs").insertOne({
                logId: campaignId,
                campaignRef: campaignId,
                audience: audienceDescription,
                messages: campaignMessages,
                messageCount: messageCountInt32,
                lastMessageTs: lastMessageTimestamp,
                createdAt: campaignCreatedAt
            });
            insertedMongoId = campaignLogInsert?.insertedId ? String(campaignLogInsert.insertedId) : undefined;
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
            });
        }
        catch (persistError) {
            console.error("CampaignLogs/AIRequests persistence error", persistError);
        }
        const responsePayload = {
            _id: insertedMongoId,
            logId: campaignId,
            campaignRef: campaignId,
            audience: audienceProfiles.map((audience) => ({
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
            messages: campaignMessages.map((message) => ({
                role: message.role,
                text: message.text,
                ts: message.ts.toISOString()
            })),
            messageCount: totalMessageCount,
            lastMessageTs: lastMessageTimestamp.toISOString(),
            createdAt: campaignCreatedAt.toISOString()
        };
        return {
            content: [{ type: "text", text: JSON.stringify(responsePayload) }],
            structuredContent: responsePayload
        };
    });
}
