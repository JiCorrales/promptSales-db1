"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.registerCreateCampaignMessagesTool = registerCreateCampaignMessagesTool;
const mongodb_1 = require("mongodb");
const zod_1 = require("zod");
const db_1 = require("../../db");
const messages_1 = require("./ai/messages");
const audienceSchema = zod_1.z.object({
    edad: zod_1.z.object({ min: zod_1.z.number().int().min(13), max: zod_1.z.number().int().max(100) }).optional(),
    intereses: zod_1.z.array(zod_1.z.string()).optional(),
    ubicaciones: zod_1.z.array(zod_1.z.string()).optional(),
    genero: zod_1.z.enum(["masculino", "femenino", "mixto"]).optional(),
    nivelSocioeconomico: zod_1.z.enum(["bajo", "medio", "alto", "mixto"]).optional()
});
function registerCreateCampaignMessagesTool(server) {
    server.registerTool("createCampaignMessages", {
        title: "Crear mensajes para campaña de marketing",
        description: "Crea tres mensajes para una campaña de mercadeo a partir de una descripción textual y un perfil de público meta. El tool debe almacenar la solicitud y generar una bitácora automática de tres mensajes adaptados al público objetivo, utilizando la información proporcionada sobre la campaña. Los mensajes deben ser coherentes con el propósito de la campaña, reflejar el tono adecuado para ese público meta y registrar en la bitácora cualquier decisión creativa tomada. El resultado debe incluir: ID de la campaña creada, la solicitud original, el público objetivo, los tres mensajes generados, la bitácora que describe el razonamiento, ajustes y consideraciones creativas.",
        inputSchema: {
            descripcion: zod_1.z
                .string()
                .min(200)
                .describe("Descripción detallada de la campaña de mercadeo (mínimo 200 caracteres)"),
            publico: zod_1.z.array(audienceSchema).describe("Definición del público objetivo")
        },
        outputSchema: {
            _id: zod_1.z.string().optional(),
            logId: zod_1.z.string(),
            campaignRef: zod_1.z.string(),
            audience: zod_1.z.array(zod_1.z.object({
                edad: zod_1.z.object({ min: zod_1.z.number().int().min(13), max: zod_1.z.number().int().max(100) }).nullable().optional(),
                intereses: zod_1.z.array(zod_1.z.string()),
                ubicaciones: zod_1.z.array(zod_1.z.string()),
                genero: zod_1.z.enum(["masculino", "femenino", "mixto"]).nullable().optional(),
                nivelSocioeconomico: zod_1.z.enum(["bajo", "medio", "alto", "mixto"]).nullable().optional()
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
    }, async ({ descripcion, publico }) => {
        const campaignId = `campaign_${Date.now()}`;
        const audienceProfiles = Array.isArray(publico) ? publico : [publico];
        const generatedSegments = [];
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
            const ageRange = audience.edad ? `${audience.edad.min ?? ""}-${audience.edad.max ?? ""}` : "";
            const interestsList = Array.isArray(audience.intereses) ? audience.intereses.join(",") : "";
            const locationsList = Array.isArray(audience.ubicaciones) ? audience.ubicaciones.join(",") : "";
            return `#${index + 1}:${ageRange}|${interestsList}|${locationsList}|${audience.genero || ""}`.trim();
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
                edad: audience.edad || null,
                intereses: audience.intereses || [],
                ubicaciones: audience.ubicaciones || [],
                genero: audience.genero || null,
                nivelSocioeconomico: audience.nivelSocioeconomico || null
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
