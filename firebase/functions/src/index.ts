import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

initializeApp();

const openAIAPIKey = defineSecret("OPENAI_API_KEY");

const youtubeURL = "https://www.youtube.com";
const youtubeVideoID = /^[A-Za-z0-9_-]{11}$/;

/** Returns `https://www.youtube.com/watch?v=VIDEO_ID` when `raw` is an allowlisted watch URL. */
export function canonicalWatchURL(raw: unknown): string | null {
  if (typeof raw !== "string") {
    return null;
  }

  const trimmed = raw.trim();
  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    return null;
  }

  if (url.protocol !== "https:") {
    return null;
  }

  const host = url.hostname.toLowerCase();
  let videoID: string | null = null;
  if (host === "youtu.be" || host === "www.youtu.be") {
    const parts = url.pathname.split("/").filter(Boolean);
    if (parts.length !== 1) {
      return null;
    }
    videoID = parts[0];
  } else if (host === "youtube.com" || host === "www.youtube.com") {
    const path = url.pathname.replace(/^\/+|\/+$/g, "");
    if (path !== "watch") {
      return null;
    }
    videoID = url.searchParams.get("v");
  } else {
    return null;
  }

  if (!videoID || !youtubeVideoID.test(videoID)) {
    return null;
  }

    return `https://www.youtube.com/watch?v=${videoID}`;
}

const documentationHosts = new Set([
  "developer.apple.com",
  "www.developer.apple.com",
  "docs.swift.org",
  "swift.org",
  "www.swift.org",
]);

/** Returns a canonical https URL when `raw` is on an allowlisted documentation host. */
export function canonicalDocumentationURL(raw: unknown): string | null {
  if (typeof raw !== "string") {
    return null;
  }

  const trimmed = raw.trim();
  let url: URL;
  try {
    url = new URL(trimmed);
  } catch {
    return null;
  }

  if (url.protocol !== "https:") {
    return null;
  }
  if (url.username || url.password) {
    return null;
  }
  if (url.port && url.port !== "443") {
    return null;
  }

  const host = url.hostname.toLowerCase();
  if (!documentationHosts.has(host)) {
    return null;
  }

  let canonicalHost = host;
  if (host === "www.developer.apple.com") {
    canonicalHost = "developer.apple.com";
  } else if (host === "www.swift.org") {
    canonicalHost = "swift.org";
  }

  const canonical = new URL(`https://${canonicalHost}`);
  canonical.pathname = url.pathname || "/";
  canonical.search = url.search;
  return canonical.toString();
}

const waitlistEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Lowercase trimmed address, or null when it is not a simple email. */
export function normalizeWaitlistEmail(raw: unknown): string | null {
  if (typeof raw !== "string") {
    return null;
  }

  const email = raw.trim().toLowerCase();
  if (!waitlistEmail.test(email) || email.includes("/")) {
    return null;
  }

  return email;
}

function requireLinkedAccount(request: { auth?: { uid: string; token: { firebase?: { sign_in_provider?: string } } } }): string {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }

  const provider = request.auth.token.firebase?.sign_in_provider;
  if (provider === "anonymous") {
    throw new HttpsError(
      "permission-denied",
      "Anonymous sessions cannot create commands."
    );
  }

  return request.auth.uid;
}

export const createOpenYouTube = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = requireLinkedAccount(request);

    const ref = await getFirestore()
      .collection("users")
      .doc(uid)
      .collection("commands")
      .add({
        type: "openYouTube",
        url: youtubeURL,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });

    return { commandId: ref.id };
  }
);

export const createOpenYouTubeVideo = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = requireLinkedAccount(request);
    const url = canonicalWatchURL(request.data?.url);
    if (!url) {
      throw new HttpsError(
        "invalid-argument",
        "URL must be a YouTube watch link."
      );
    }

    console.info("createOpenYouTubeVideo canonical url", url);

    const ref = await getFirestore()
      .collection("users")
      .doc(uid)
      .collection("commands")
      .add({
        type: "openYouTubeVideo",
        url,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });

    return { commandId: ref.id };
  }
);

export const createOpenURL = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = requireLinkedAccount(request);
    const url = canonicalDocumentationURL(request.data?.url);
    if (!url) {
      throw new HttpsError(
        "invalid-argument",
        "URL must be an allowlisted documentation link."
      );
    }

    console.info("createOpenURL canonical url", url);

    const ref = await getFirestore()
      .collection("users")
      .doc(uid)
      .collection("commands")
      .add({
        type: "openURL",
        url,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });

    return { commandId: ref.id };
  }
);

// cua-driver exposes these as MCP tools; declared here as OpenAI function-calling tools so any
// tool-capable model can drive them (cua-driver is explicitly model-agnostic — see
// docs/macos-agent-plan.md Phase 3). This is our own simplified action surface for the model,
// not a 1:1 mirror of cua-driver's tool names — apps/macos/caocap/ComputerUseHelper/CuaDriverClient.swift
// translates each of these into the real cua-driver call (click/double_click/type_text/press_key
// or hotkey/scroll), verified against the installed cua-driver 0.24.0 binary's `describe` output.
const computerUseTools = [
  {
    type: "function",
    name: "click",
    description: "Click at a pixel coordinate within the target app's window.",
    parameters: {
      type: "object",
      properties: {
        x: { type: "integer" },
        y: { type: "integer" },
        button: { type: "string", enum: ["left", "right"] },
      },
      required: ["x", "y"],
    },
  },
  {
    type: "function",
    name: "double_click",
    description: "Double-click at a pixel coordinate within the target app's window.",
    parameters: {
      type: "object",
      properties: {
        x: { type: "integer" },
        y: { type: "integer" },
      },
      required: ["x", "y"],
    },
  },
  {
    type: "function",
    name: "type",
    description: "Type text at the current text cursor position.",
    parameters: {
      type: "object",
      properties: {
        text: { type: "string" },
      },
      required: ["text"],
    },
  },
  {
    type: "function",
    name: "keypress",
    description: "Press a key combination, e.g. [\"cmd\", \"s\"] to save.",
    parameters: {
      type: "object",
      properties: {
        keys: { type: "array", items: { type: "string" } },
      },
      required: ["keys"],
    },
  },
  {
    type: "function",
    name: "scroll",
    description: "Scroll within the target app's window.",
    parameters: {
      type: "object",
      properties: {
        direction: { type: "string", enum: ["up", "down", "left", "right"] },
        amount: { type: "integer", description: "Number of scroll steps, 1-50. Default 3." },
        by: { type: "string", enum: ["line", "page"], description: "Scroll granularity. Default line." },
      },
      required: ["direction"],
    },
  },
  {
    type: "function",
    name: "wait",
    description: "Wait briefly, e.g. for a dialog to finish animating in.",
    parameters: { type: "object", properties: {} },
  },
  {
    type: "function",
    name: "finish",
    description: "Call once the task is fully complete, including having actually saved the file. Do not call this speculatively.",
    parameters: {
      type: "object",
      properties: {
        summary: { type: "string", description: "One sentence describing what was done." },
      },
      required: ["summary"],
    },
  },
];

interface ComputerUseStepRequest {
  taskSummary?: unknown;
  screenshotBase64?: unknown;
  previousResponseId?: unknown;
  previousCallId?: unknown;
}

export const computerUseStep = onCall(
  { region: "us-central1", secrets: [openAIAPIKey], timeoutSeconds: 60 },
  async (request) => {
    requireLinkedAccount(request);

    const data = request.data as ComputerUseStepRequest;
    const taskSummary = typeof data?.taskSummary === "string" ? data.taskSummary : null;
    const screenshotBase64 = typeof data?.screenshotBase64 === "string" ? data.screenshotBase64 : null;
    const previousResponseId = typeof data?.previousResponseId === "string" ? data.previousResponseId : undefined;
    const previousCallId = typeof data?.previousCallId === "string" ? data.previousCallId : undefined;

    if (!taskSummary || !screenshotBase64) {
      throw new HttpsError("invalid-argument", "taskSummary and screenshotBase64 are required.");
    }

    const input: Record<string, unknown>[] = [];

    if (!previousResponseId) {
      input.push({
        role: "system",
        content: [
          {
            type: "input_text",
            text:
              "You control TextEdit on macOS through the provided function tools to complete this task: " +
              taskSummary +
              ". Look at the screenshot, decide the single next action, and call exactly one tool. " +
              "Call finish only once the file has actually been saved, not before.",
          },
        ],
      });
    } else if (previousCallId) {
      input.push({
        type: "function_call_output",
        call_id: previousCallId,
        output: JSON.stringify({ status: "ok" }),
      });
    }

    input.push({
      role: "user",
      content: [
        { type: "input_image", image_url: `data:image/png;base64,${screenshotBase64}` },
      ],
    });

    const body: Record<string, unknown> = {
      model: "gpt-6-astra",
      tools: computerUseTools,
      truncation: "auto",
      input,
    };
    if (previousResponseId) {
      body.previous_response_id = previousResponseId;
    }

    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${openAIAPIKey.value()}`,
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error("computerUseStep: OpenAI request failed", errorText);
      throw new HttpsError("internal", "The model couldn't be reached.");
    }

    const responseData = (await response.json()) as {
      id: string;
      output?: { type: string; call_id?: string; name?: string; arguments?: string; content?: { type: string; text?: string }[] }[];
    };

    const output = responseData.output ?? [];
    const functionCall = output.find((item) => item.type === "function_call");

    let actions: Record<string, unknown>[] = [];
    let done = false;
    let message: string | undefined;
    let callId: string | undefined;

    if (functionCall) {
      callId = functionCall.call_id;
      let args: Record<string, unknown> = {};
      try {
        args = JSON.parse(functionCall.arguments || "{}");
      } catch (error) {
        console.error("computerUseStep: failed to parse tool arguments", error);
      }
      if (functionCall.name === "finish") {
        done = true;
        message = typeof args.summary === "string" ? args.summary : "Task finished.";
      } else {
        actions = [{ type: functionCall.name, ...args }];
      }
    } else {
      const textItem = output.find((item) => item.type === "message");
      message = textItem?.content?.find((part) => part.type === "output_text")?.text;
    }

    return { responseId: responseData.id, callId, actions, message, done };
  }
);

export const joinWaitlist = onRequest(
  { region: "us-central1", cors: true, invoker: "public" },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ ok: false });
      return;
    }

    const body =
      typeof req.body === "object" && req.body !== null
        ? (req.body as { email?: unknown; website?: unknown })
        : {};
    const website =
      typeof body.website === "string" ? body.website.trim() : "";
    if (website.length > 0) {
      res.status(200).json({ ok: true });
      return;
    }

    const email = normalizeWaitlistEmail(body.email);
    if (!email) {
      res.status(400).json({ ok: false });
      return;
    }

    const ref = getFirestore().collection("waitlist").doc(email);
    const existing = await ref.get();
    if (!existing.exists) {
      await ref.set({
        email,
        source: "landing",
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    res.status(200).json({ ok: true });
  }
);
