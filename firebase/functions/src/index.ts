import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();

const youtubeHomepageURL = "https://www.youtube.com";
const videoIDPattern = /^[A-Za-z0-9_-]{11}$/;

function requireSignedInUser(request: { auth?: { uid: string; token: { firebase?: { sign_in_provider?: string } } } }) {
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

export function canonicalWatchURL(raw: unknown): string | null {
  if (typeof raw !== "string") {
    return null;
  }

  const trimmed = raw.trim();
  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    return null;
  }

  if (parsed.protocol !== "https:") {
    return null;
  }

  const host = parsed.hostname.toLowerCase();
  let videoID: string | null = null;

  if (host === "youtu.be" || host === "www.youtu.be") {
    const parts = parsed.pathname.split("/").filter(Boolean);
    if (parts.length !== 1) {
      return null;
    }
    videoID = parts[0];
  } else if (host === "youtube.com" || host === "www.youtube.com") {
    const path = parsed.pathname.replace(/^\/+|\/+$/g, "");
    if (path !== "watch") {
      return null;
    }
    videoID = parsed.searchParams.get("v");
  } else {
    return null;
  }

  if (!videoID || !videoIDPattern.test(videoID)) {
    return null;
  }

  return `https://www.youtube.com/watch?v=${videoID}`;
}

export const createOpenYouTube = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = requireSignedInUser(request);

    const ref = await getFirestore()
      .collection("users")
      .doc(uid)
      .collection("commands")
      .add({
        type: "openYouTube",
        url: youtubeHomepageURL,
        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
      });

    return { commandId: ref.id };
  }
);

export const createOpenYouTubeVideo = onCall(
  { region: "us-central1" },
  async (request) => {
    const uid = requireSignedInUser(request);
    const url = canonicalWatchURL(
      (request.data as { url?: unknown } | undefined)?.url
    );
    if (!url) {
      throw new HttpsError(
        "invalid-argument",
        "URL must be an https YouTube watch link."
      );
    }

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
