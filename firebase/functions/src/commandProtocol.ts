import { randomUUID } from "node:crypto";
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

export const commandTypes = ["openYouTube", "openYouTubeVideo", "openURL", "computerUse"] as const;
export type CommandType = typeof commandTypes[number];
export const limits = { claimMs: 60_000, reportingMs: 300_000, steps: 20, summary: 500, preview: 8000 };
export function validID(value: unknown, optional = false): string {
  if (value === undefined && optional) return randomUUID();
  if (typeof value !== "string" || !/^[A-Za-z0-9_-]{8,64}$/.test(value)) {
    throw new HttpsError("invalid-argument", "A valid request identifier is required.");
  }
  return value;
}
export function validSummary(value: unknown): string {
  if (typeof value !== "string" || !value.trim() || value.trim().length > limits.summary) {
    throw new HttpsError("invalid-argument", "Describe a task in 1–500 characters.");
  }
  return value.trim();
}
export function commandDocument(id: string, type: CommandType, url: string | null, summary: string | null, now: Timestamp) {
  return {
    schemaVersion: 2, requestId: id, type, url, taskSummary: summary,
    target: type === "computerUse" ? "com.apple.TextEdit" : null,
    createdAt: now, expiresAt: Timestamp.fromMillis(now.toMillis() + limits.claimMs),
    reportingDeadline: Timestamp.fromMillis(now.toMillis() + limits.reportingMs),
    status: "pending", claimedByDeviceId: null, claimedAt: null, startedAt: null, finishedAt: null,
    steps: [], result: null, failureCode: null,
  };
}
export async function createCommand(uid: string, id: string, type: CommandType, url: string | null, summary: string | null) {
  const db = getFirestore();
  const ref = db.doc(`users/${uid}/commands/${id}`);
  const now = Timestamp.now();
  const rate = db.doc(`commandUsage/${uid}`);
  const control = db.doc("serviceControls/computerUse");
  return db.runTransaction(async tx => {
    const existing = await tx.get(ref);
    if (existing.exists) {
      const data = existing.data()!;
      if (data.type !== type || data.url !== url || data.taskSummary !== summary) {
        throw new HttpsError("already-exists", "This request identifier was used for different input.");
      }
      return { commandId: id, alreadyExisted: true };
    }
    const usage = await tx.get(rate);
    const configuration = type === "computerUse" ? await tx.get(control) : null;
    if (type === "computerUse" && configuration?.data()?.enabled !== true) {
      throw new HttpsError("unavailable", "Computer use is temporarily unavailable.", { failureCode: "serviceUnavailable" });
    }
    const minute = Math.floor(now.toMillis() / 60_000);
    const count = usage.data()?.minute === minute ? Number(usage.data()?.count ?? 0) : 0;
    if (count >= 6) throw new HttpsError("resource-exhausted", "Please wait before sending another request.", { failureCode: "quotaExceeded" });
    tx.set(rate, { minute, count: count + 1 });
    tx.create(ref, commandDocument(id, type, url, summary, now));
    return { commandId: id, alreadyExisted: false };
  });
}

export function validateAction(name: unknown, args: unknown): Record<string, unknown> {
  if (!args || typeof args !== "object" || Array.isArray(args)) return invalidAction();
  const a = args as Record<string, unknown>;
  const exact = (keys: string[]) => Object.keys(a).length === keys.length && keys.every(k => Object.hasOwn(a, k));
  // The prepared-document slice deliberately has no menu clicks, file dialogs, or app switching.
  if (name === "type" && exact(["text"]) && typeof a.text === "string" && a.text.length > 0 && a.text.length <= 8000) return { type: name, text: a.text };
  if (name === "keypress" && exact(["keys"]) && Array.isArray(a.keys) && a.keys.every(k => typeof k === "string")) {
    const key = a.keys.join("+");
    if (["cmd+s", "cmd+a", "left", "right", "up", "down", "backspace", "enter"].includes(key)) return { type: name, keys: a.keys };
  }
  if (name === "wait" && exact([])) return { type: name };
  if (name === "finish" && exact(["summary"]) && typeof a.summary === "string" && a.summary.length <= 500) return { type: name, summary: a.summary };
  return invalidAction();
}
function invalidAction(): never {
  throw new HttpsError("internal", "The model returned an unsupported action.", { failureCode: "invalidModelAction" });
}
