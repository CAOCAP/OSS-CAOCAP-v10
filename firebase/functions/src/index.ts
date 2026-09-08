import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { createCommand, validID, validSummary } from "./commandProtocol";
import { executeComputerUseStep } from "./computerUse";

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

// App Check is deliberately not enforced on these Mac-required beta callables.
// Account ownership, quotas and the server-side kill switch remain mandatory.
export const createOpenYouTube = onCall({ region: "us-central1" }, async request =>
  createCommand(requireLinkedAccount(request), validID(request.data?.requestId, true), "openYouTube", youtubeURL, null));
export const createOpenYouTubeVideo = onCall({ region: "us-central1" }, async request => {
  const uid = requireLinkedAccount(request);
  const url = canonicalWatchURL(request.data?.url);
  if (!url) throw new HttpsError("invalid-argument", "URL must be a YouTube watch link.");
  return createCommand(uid, validID(request.data?.requestId, true), "openYouTubeVideo", url, null);
});
export const createOpenURL = onCall({ region: "us-central1" }, async request => {
  const uid = requireLinkedAccount(request);
  const url = canonicalDocumentationURL(request.data?.url);
  if (!url) throw new HttpsError("invalid-argument", "URL must be an allowlisted documentation link.");
  return createCommand(uid, validID(request.data?.requestId, true), "openURL", url, null);
});
export const createComputerUseTask = onCall({ region: "us-central1" }, async request =>
  createCommand(requireLinkedAccount(request), validID(request.data?.requestId), "computerUse", null, validSummary(request.data?.taskSummary)));
export const computerUseStep = onCall(
  { region: "us-central1", secrets: [openAIAPIKey], timeoutSeconds: 60 },
  async request => executeComputerUseStep(requireLinkedAccount(request), request.data, openAIAPIKey.value())
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
