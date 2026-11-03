#!/usr/bin/env node
// Ponte 9router: servidor MCP (stdio) sem dependencias.
// Deixa o Claude oficial (logado na sua conta) mandar tarefas para os
// modelos do 9router pelo endpoint compativel com OpenAI.
//
// Variaveis de ambiente:
//   NINE_ROUTER_URL    ex.: http://localhost:20128/v1  (endereco /v1 do seu 9router)
//   NINE_ROUTER_KEY    chave/token do 9router (se ele pedir)
//   NINE_ROUTER_MODEL  modelo padrao (opcional)

const URL_BASE = (process.env.NINE_ROUTER_URL || "http://localhost:20128/v1").replace(/\/+$/, "");
const CHAVE = process.env.NINE_ROUTER_KEY || "";
const MODELO_PADRAO = process.env.NINE_ROUTER_MODEL || "";

const FERRAMENTAS = [
  {
    name: "perguntar_9router",
    description:
      "Envia um pedido para um modelo do 9router e devolve a resposta em texto. " +
      "Use para tarefas baratas ou em volume: rascunhos, resumos, traducoes, variacoes de texto, " +
      "segunda opiniao. Nao envie segredos (senhas, tokens, chaves).",
    inputSchema: {
      type: "object",
      properties: {
        prompt: { type: "string", description: "O pedido completo para o modelo." },
        modelo: { type: "string", description: "Nome do modelo no 9router (opcional)." },
        sistema: { type: "string", description: "Instrucao de sistema (opcional)." },
        max_tokens: { type: "integer", description: "Limite de tokens da resposta (opcional)." },
      },
      required: ["prompt"],
    },
  },
  {
    name: "listar_modelos_9router",
    description: "Lista os modelos disponiveis no 9router.",
    inputSchema: { type: "object", properties: {} },
  },
];

function cabecalhos() {
  const h = { "Content-Type": "application/json" };
  if (CHAVE) h.Authorization = `Bearer ${CHAVE}`;
  return h;
}

async function chamar(nome, args = {}) {
  if (nome === "listar_modelos_9router") {
    const r = await fetch(`${URL_BASE}/models`, { headers: cabecalhos() });
    const corpo = await r.text();
    if (!r.ok) throw new Error(`9router respondeu ${r.status}: ${corpo.slice(0, 500)}`);
    const dados = JSON.parse(corpo);
    const ids = (dados.data || []).map((m) => m.id);
    return ids.length ? ids.join("\n") : corpo;
  }
  if (nome === "perguntar_9router") {
    if (!args.prompt) throw new Error("Falta o campo 'prompt'.");
    const modelo = args.modelo || MODELO_PADRAO;
    if (!modelo) throw new Error("Informe 'modelo' ou defina NINE_ROUTER_MODEL. Use listar_modelos_9router para ver os nomes.");
    const mensagens = [];
    if (args.sistema) mensagens.push({ role: "system", content: args.sistema });
    mensagens.push({ role: "user", content: args.prompt });
    const corpoReq = { model: modelo, messages: mensagens, stream: false };
    if (args.max_tokens) corpoReq.max_tokens = args.max_tokens;
    const r = await fetch(`${URL_BASE}/chat/completions`, {
      method: "POST",
      headers: cabecalhos(),
      body: JSON.stringify(corpoReq),
    });
    const corpo = await r.text();
    if (!r.ok) throw new Error(`9router respondeu ${r.status}: ${corpo.slice(0, 500)}`);
    const dados = JSON.parse(corpo);
    const texto = dados.choices?.[0]?.message?.content;
    return typeof texto === "string" ? texto : corpo;
  }
  throw new Error(`Ferramenta desconhecida: ${nome}`);
}

function enviar(msg) {
  process.stdout.write(JSON.stringify(msg) + "\n");
}

async function tratar(msg) {
  const { id, method, params } = msg;
  const temId = id !== undefined && id !== null;
  try {
    switch (method) {
      case "initialize":
        return enviar({
          jsonrpc: "2.0",
          id,
          result: {
            protocolVersion: params?.protocolVersion || "2025-06-18",
            capabilities: { tools: {} },
            serverInfo: { name: "ponte-9router", version: "1.0.0" },
          },
        });
      case "ping":
        return enviar({ jsonrpc: "2.0", id, result: {} });
      case "tools/list":
        return enviar({ jsonrpc: "2.0", id, result: { tools: FERRAMENTAS } });
      case "tools/call":
        try {
          const texto = await chamar(params?.name, params?.arguments);
          return enviar({ jsonrpc: "2.0", id, result: { content: [{ type: "text", text: texto }] } });
        } catch (e) {
          return enviar({
            jsonrpc: "2.0",
            id,
            result: { isError: true, content: [{ type: "text", text: String(e.message || e) }] },
          });
        }
      default:
        if (temId) enviar({ jsonrpc: "2.0", id, error: { code: -32601, message: `Metodo nao suportado: ${method}` } });
    }
  } catch (e) {
    if (temId) enviar({ jsonrpc: "2.0", id, error: { code: -32603, message: String(e.message || e) } });
  }
}

let buffer = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (pedaco) => {
  buffer += pedaco;
  let i;
  while ((i = buffer.indexOf("\n")) >= 0) {
    const linha = buffer.slice(0, i).trim();
    buffer = buffer.slice(i + 1);
    if (!linha) continue;
    let msg;
    try {
      msg = JSON.parse(linha);
    } catch {
      continue;
    }
    tratar(msg);
  }
});
