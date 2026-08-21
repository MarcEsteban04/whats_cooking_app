// The three AI providers, in the order they are tried.
//
// docs/project_dev.md Sprint 59: "Never expose AI API keys inside Flutter." All
// three keys live here, in the Edge Function's environment, and never reach the
// client — see supabase/README.md for setting them.

/** What every provider is asked for, and what each one gives back. */
export interface ChatRequest {
  readonly system: string;
  readonly messages: ReadonlyArray<{ role: "user" | "assistant"; content: string }>;
  /** Hard ceiling on the reply, so a runaway generation cannot run up a bill. */
  readonly maxOutputTokens: number;
  /** Low, because this app wants correct food rather than creative food. */
  readonly temperature: number;
  /**
   * One picture, attached to the last user message (Sprint 49).
   *
   * **Its presence changes which providers can answer.** Most chat models cannot
   * see, and the default text model on at least one provider here cannot — so a
   * request carrying an image is routed to that provider's vision model, and
   * providers with none configured are skipped rather than sent a request they
   * will reject. See [chat].
   */
  readonly image?: {
    readonly mimeType: string;
    /** Raw base64, no `data:` prefix. Each adapter wraps it its own way. */
    readonly base64: string;
  };
}

export interface ChatReply {
  readonly text: string;
  readonly provider: ProviderName;
  readonly model: string;
  readonly promptTokens: number | null;
  readonly completionTokens: number | null;
}

export type ProviderName = "groq" | "gemini" | "openai";

/** Why a provider did not answer, and whether the next one is worth trying. */
export class ProviderError extends Error {
  constructor(
    readonly provider: ProviderName,
    message: string,
    /**
     * False only for a failure that every provider would repeat — a request this
     * function built wrongly. Trying two more providers with the same bad
     * request wastes three round trips to arrive at the same answer.
     */
    readonly worthFailingOver = true,
  ) {
    super(message);
    this.name = "ProviderError";
  }
}

interface Provider {
  readonly name: ProviderName;
  readonly keyEnv: string;
  readonly modelEnv: string;
  readonly defaultModel: string;
  /**
   * The model used when the request carries an image, and its override (Sprint 49).
   *
   * Separate from [modelEnv] because on Groq it is a different model entirely, and
   * because vision pricing is not text pricing — an operator who wants to move one
   * should not be forced to move both.
   *
   * `null` means this provider cannot see, and it is skipped for image requests.
   */
  readonly visionModelEnv: string | null;
  readonly defaultVisionModel: string | null;
  call(
    key: string,
    model: string,
    request: ChatRequest,
    signal: AbortSignal,
  ): Promise<ChatReply>;
}

/**
 * The chain, in order.
 *
 * Groq first because it is the fastest of the three by a wide margin, and this
 * sits in front of a user waiting for dinner advice. Gemini second on cost.
 * OpenAI last as the one most likely to be up when the other two are not —
 * which is exactly what you want from a last resort rather than a first choice.
 *
 * Model names are read from the environment with these as defaults, because
 * model identifiers get retired on a schedule nobody tells you about, and
 * replacing one should not need a redeploy of this file.
 */
const PROVIDERS: readonly Provider[] = [
  {
    name: "groq",
    keyEnv: "GROQ_AI_API_KEY",
    modelEnv: "GROQ_MODEL",
    defaultModel: "llama-3.3-70b-versatile",
    // The text default above cannot see at all, which is the whole reason vision
    // gets its own field rather than reusing `GROQ_MODEL`.
    visionModelEnv: "GROQ_VISION_MODEL",
    defaultVisionModel: "meta-llama/llama-4-scout-17b-16e-instruct",
    call: callOpenAiCompatible("https://api.groq.com/openai/v1/chat/completions", "groq"),
  },
  {
    name: "gemini",
    keyEnv: "GEMINI_AI_API_KEY",
    modelEnv: "GEMINI_MODEL",
    defaultModel: "gemini-2.0-flash",
    // The same model. Flash reads pictures, so there is nothing to switch to.
    visionModelEnv: "GEMINI_VISION_MODEL",
    defaultVisionModel: "gemini-2.0-flash",
    call: callGemini,
  },
  {
    name: "openai",
    keyEnv: "OPENAI_API_KEY",
    modelEnv: "OPENAI_MODEL",
    defaultModel: "gpt-4o-mini",
    visionModelEnv: "OPENAI_VISION_MODEL",
    defaultVisionModel: "gpt-4o-mini",
    call: callOpenAiCompatible("https://api.openai.com/v1/chat/completions", "openai"),
  },
];

/** How long any single provider gets before the next one is tried. */
const PROVIDER_TIMEOUT_MS = 12_000;

export interface ChainResult {
  readonly reply: ChatReply;
  /** How many providers were tried, including the one that answered. */
  readonly attempts: number;
}

/**
 * Asks each configured provider in turn until one answers.
 *
 * **The timeout is the point.** A provider that returns an error is easy; a
 * provider that accepts the connection and then thinks for forty seconds is what
 * actually ruins the experience, and it is the case a plain try/catch misses
 * entirely. Each attempt gets its own `AbortController`, so a slow first
 * provider costs the reader twelve seconds rather than the whole request.
 *
 * Providers with no key configured are skipped silently rather than counted as
 * failures — running with one key is a supported state, and it should not look
 * like an outage in the usage table.
 *
 * **An image narrows the chain** (Sprint 49). Providers whose vision model has been
 * blanked are skipped, and the rest are asked with their vision model rather than
 * their text one. A picture sent to a text model comes back as a 400, which does
 * not fail over — so filtering here is the difference between falling through to
 * the next provider and giving up on the first.
 */
export async function chat(request: ChatRequest): Promise<ChainResult> {
  const seeing = request.image !== undefined;

  const available = PROVIDERS.filter((p) => {
    if ((Deno.env.get(p.keyEnv) ?? "") === "") {
      return false;
    }
    return seeing ? visionModelFor(p) !== "" : true;
  });

  if (available.length === 0) {
    throw new ProviderError(
      "groq",
      seeing
        ? "No AI provider on this function can read a picture."
        : "No AI provider key is configured on this function.",
      false,
    );
  }

  let attempts = 0;
  let last: unknown;

  for (const provider of available) {
    attempts += 1;

    const key = Deno.env.get(provider.keyEnv)!;
    const model = seeing
      ? visionModelFor(provider)
      : Deno.env.get(provider.modelEnv) ?? provider.defaultModel;
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), PROVIDER_TIMEOUT_MS);

    try {
      const reply = await provider.call(key, model, request, controller.signal);
      return { reply, attempts };
    } catch (error) {
      last = error;

      // A request this function built wrongly will be built wrongly for the next
      // provider too. Stop rather than spending two more round trips on it.
      if (error instanceof ProviderError && !error.worthFailingOver) {
        break;
      }

      console.warn(
        `[ai] ${provider.name} failed, ${
          attempts < available.length ? "falling over" : "no providers left"
        }: ${error instanceof Error ? error.message : String(error)}`,
      );
    } finally {
      clearTimeout(timer);
    }
  }

  throw last instanceof Error
    ? last
    : new ProviderError("groq", "Every AI provider failed.");
}

/**
 * Which model this provider reads pictures with, or `""` when it does not.
 *
 * An explicitly empty environment variable turns vision off for that provider,
 * which is the switch to reach for when one of them starts charging differently
 * for it. `null` in the table means the provider never had it.
 */
function visionModelFor(provider: Provider): string {
  if (provider.visionModelEnv === null) {
    return provider.defaultVisionModel ?? "";
  }
  return Deno.env.get(provider.visionModelEnv) ?? provider.defaultVisionModel ?? "";
}

/** Groq and OpenAI both speak the OpenAI chat-completions shape. */
function callOpenAiCompatible(endpoint: string, name: ProviderName) {
  return async function (
    key: string,
    model: string,
    request: ChatRequest,
    signal: AbortSignal,
  ): Promise<ChatReply> {
    const response = await fetch(endpoint, {
      method: "POST",
      signal,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        model,
        temperature: request.temperature,
        max_tokens: request.maxOutputTokens,
        messages: [
          { role: "system", content: request.system },
          ...withImageOpenAi(request),
        ],
      }),
    });

    if (!response.ok) {
      throw await providerHttpError(name, response);
    }

    const body = await response.json();
    const text = body?.choices?.[0]?.message?.content;

    if (typeof text !== "string" || text.trim() === "") {
      // An empty completion is a failure worth failing over on: the provider is
      // up but useless for this request, and the next one may not be.
      throw new ProviderError(name, "Empty completion.");
    }

    return {
      text: text.trim(),
      provider: name,
      model,
      promptTokens: body?.usage?.prompt_tokens ?? null,
      completionTokens: body?.usage?.completion_tokens ?? null,
    };
  };
}

/**
 * The messages, with the picture attached to the last user turn (Sprint 49).
 *
 * **The last user turn, not a message of its own.** The image is evidence for the
 * question being asked, and a provider that receives it as a separate turn is free
 * to describe it instead of answering. Text first inside that turn, for the same
 * reason: the instruction should be read before the picture, not after it.
 *
 * A `data:` URI rather than a URL, because there is nothing to link to — the photo
 * is never stored (docs/ARCHITECTURE.md §6.4). It exists in this request and
 * nowhere else.
 */
function withImageOpenAi(request: ChatRequest): unknown[] {
  const messages = [...request.messages];
  const image = request.image;

  if (image === undefined || messages.length === 0) {
    return messages;
  }

  const last = messages[messages.length - 1];
  messages[messages.length - 1] = {
    role: last.role,
    // deno-lint-ignore no-explicit-any -- the multimodal shape is not the string
    // one, and widening `ChatRequest` for the wire format would leak it upward.
    content: [
      { type: "text", text: last.content },
      {
        type: "image_url",
        image_url: { url: `data:${image.mimeType};base64,${image.base64}` },
      },
    ] as any,
  };

  return messages;
}

/** Gemini takes a different shape, so it gets its own adapter. */
async function callGemini(
  key: string,
  model: string,
  request: ChatRequest,
  signal: AbortSignal,
): Promise<ChatReply> {
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: "POST",
      signal,
      headers: {
        "Content-Type": "application/json",
        // A header rather than a query parameter, so the key cannot end up in
        // anybody's access log.
        "x-goog-api-key": key,
      },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: request.system }] },
        contents: request.messages.map((message, index) => ({
          role: message.role === "assistant" ? "model" : "user",
          parts: [
            { text: message.content },
            // Same rule as the OpenAI adapter: the picture rides on the last turn,
            // after its text.
            ...(request.image !== undefined &&
                index === request.messages.length - 1
              ? [{
                inline_data: {
                  mime_type: request.image.mimeType,
                  data: request.image.base64,
                },
              }]
              : []),
          ],
        })),
        generationConfig: {
          temperature: request.temperature,
          maxOutputTokens: request.maxOutputTokens,
        },
      }),
    },
  );

  if (!response.ok) {
    throw await providerHttpError("gemini", response);
  }

  const body = await response.json();
  const text = body?.candidates?.[0]?.content?.parts
    ?.map((part: { text?: string }) => part?.text ?? "")
    .join("");

  if (typeof text !== "string" || text.trim() === "") {
    throw new ProviderError("gemini", "Empty completion.");
  }

  return {
    text: text.trim(),
    provider: "gemini",
    model,
    promptTokens: body?.usageMetadata?.promptTokenCount ?? null,
    completionTokens: body?.usageMetadata?.candidatesTokenCount ?? null,
  };
}

/**
 * Turns a non-2xx into a [ProviderError], deciding whether to fail over.
 *
 * 429 and 5xx are the whole reason this chain exists — one provider being rate
 * limited or down is exactly when another should answer. A 401 also fails over,
 * because one bad key should not take the feature down; it is logged loudly so
 * it gets fixed. A 400 does not: the request was malformed, and the next
 * provider will say so too.
 *
 * The body is read and truncated rather than passed on. It can contain the
 * prompt, and the prompt can contain what somebody has in their fridge.
 */
async function providerHttpError(
  name: ProviderName,
  response: Response,
): Promise<ProviderError> {
  const detail = (await response.text().catch(() => "")).slice(0, 200);
  const failOver = response.status !== 400;

  if (response.status === 401 || response.status === 403) {
    console.error(`[ai] ${name} rejected the configured key (${response.status}).`);
  }

  return new ProviderError(
    name,
    `HTTP ${response.status}${detail ? `: ${detail}` : ""}`,
    failOver,
  );
}
