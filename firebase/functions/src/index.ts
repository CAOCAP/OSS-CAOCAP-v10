import { initializeApp } from "firebase-admin/app";
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { HttpsError, onCall } from "firebase-functions/v2/https";

initializeApp();

const youtubeURL = "https://www.youtube.com";

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
