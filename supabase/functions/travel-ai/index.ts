import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const OPENAI_KEY = Deno.env.get("OPENAI_API_KEY") ?? "";
const CLAUDE_KEY = Deno.env.get("ANTHROPIC_API_KEY") ?? "";
const DEEPSEEK_KEY = Deno.env.get("DEEPSEEK_API_KEY") ?? "";

// ────────────────────────────────────────────────────────────
// Prompt builder
// ────────────────────────────────────────────────────────────
const GENERATE_PROMPT = (
  destination: string,
  start: string,
  end: string,
  style: string,
) => `
你是一位专业旅游规划师。请为以下旅行生成完整的攻略，以JSON格式返回，不要有任何额外文字。

目的地：${destination}
出发日期：${start}
返回日期：${end}
旅行风格：${style}

JSON格式要求：
{
  "destination": "目的地名称（英文）",
  "dateRange": { "start": "YYYY-MM-DD", "end": "YYYY-MM-DD" },
  "itinerary": [
    {
      "day": 1,
      "date": "YYYY-MM-DD",
      "title": "城市A → 城市B",
      "events": [
        {
          "time": "HH:MM",
          "title": "活动名称",
          "description": "简短说明",
          "location": { "name": "地点名称", "lat": 纬度, "lng": 经度 },
          "type": "transport|attraction|food|accommodation"
        }
      ]
    }
  ],
  "checklist": [
    { "id": "uuid", "title": "待办事项", "completed": false, "dayIndex": null }
  ],
  "culture": {
    "type": "mythology_tree|dynasty_tree|general",
    "title": "知识图谱标题",
    "nodes": [
      {
        "id": "唯一id",
        "name": "名称",
        "subtitle": "副标题",
        "description": "详细描述（100字内）",
        "emoji": "相关emoji",
        "parentId": null
      }
    ]
  },
  "tips": ["贴士1", "贴士2"],
  "sos": [
    { "title": "机构名称", "phone": "电话号码", "subtitle": "说明", "emoji": "相关emoji" }
  ]
}

请确保：
1. 每个景点都有真实的GPS坐标（精确到小数点后4位）
2. 文化知识图谱包含至少8个节点，有清晰的父子层级关系
3. SOS必须包含中国大使馆紧急联系号码
4. checklist包含5-8个实用待办事项
5. tips包含5-8条实用旅行贴士
`;

// ────────────────────────────────────────────────────────────
// AI provider callers
// ────────────────────────────────────────────────────────────
async function callOpenAI(
  prompt: string,
  isChat = false,
  messages?: Array<{ role: string; content: string }>,
): Promise<string> {
  const body = isChat && messages
    ? { model: "gpt-4o", messages }
    : {
      model: "gpt-4o",
      messages: [{ role: "user", content: prompt }],
      response_format: { type: "json_object" },
    };

  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${OPENAI_KEY}`,
    },
    body: JSON.stringify(body),
  });
  const data = await res.json();
  return data.choices[0].message.content;
}

async function callClaude(
  prompt: string,
  isChat = false,
  messages?: Array<{ role: string; content: string }>,
): Promise<string> {
  const claudeMessages = isChat && messages
    ? messages.filter((m) => m.role !== "system")
    : [{ role: "user", content: prompt }];

  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": CLAUDE_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: "claude-opus-4-5",
      max_tokens: 8192,
      messages: claudeMessages,
    }),
  });
  const data = await res.json();
  return data.content[0].text;
}

async function callDeepSeek(prompt: string): Promise<string> {
  const res = await fetch("https://api.deepseek.com/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${DEEPSEEK_KEY}`,
    },
    body: JSON.stringify({
      model: "deepseek-chat",
      messages: [{ role: "user", content: prompt }],
      response_format: { type: "json_object" },
    }),
  });
  const data = await res.json();
  return data.choices[0].message.content;
}

// ────────────────────────────────────────────────────────────
// Main handler
// ────────────────────────────────────────────────────────────
Deno.serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
      },
    });
  }

  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Content-Type": "application/json",
  };

  try {
    const body = await req.json();
    const { action, provider = "openai" } = body;
    let result: string;

    if (action === "generate_trip") {
      const { destination, startDate, endDate, style } = body;
      const prompt = GENERATE_PROMPT(destination, startDate, endDate, style);

      if (provider === "claude") result = await callClaude(prompt);
      else if (provider === "deepseek") result = await callDeepSeek(prompt);
      else result = await callOpenAI(prompt);
    } else if (action === "chat") {
      const { messages, tripContext } = body;
      const systemMsg = {
        role: "system",
        content: `你是专业旅游助手。当前行程背景：${tripContext}。请用中文简洁回答用户问题，回答控制在200字以内。`,
      };
      const fullMessages = [systemMsg, ...messages];

      if (provider === "claude") {
        result = await callClaude("", true, fullMessages);
      } else {
        result = await callOpenAI("", true, fullMessages);
      }
    } else {
      return new Response(
        JSON.stringify({ error: `Unknown action: ${action}` }),
        { status: 400, headers: corsHeaders },
      );
    }

    return new Response(result, { headers: corsHeaders });
  } catch (e) {
    console.error("Edge function error:", e);
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: corsHeaders },
    );
  }
});
