import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall, onRequest } from "firebase-functions/v2/https";

initializeApp();

const youtubeURL = "https://www.youtube.com";

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

export const createOpenYouTube = onCall(
  { region: "us-central1" },
  async (request) => {
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

    const ref = await getFirestore()
      .collection("users")
      .doc(request.auth.uid)
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
