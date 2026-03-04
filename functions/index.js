const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const Anthropic = require("@anthropic-ai/sdk").default;

initializeApp();

const db = getFirestore();
const anthropicKey = defineSecret("ANTHROPIC_API_KEY");

/**
 * Proxy for Anthropic Claude API — keeps the API key server-side.
 * Flutter calls this via FirebaseFunctions.instance.httpsCallable('claudeProxy').
 */
exports.claudeProxy = onCall(
  { secrets: [anthropicKey], timeoutSeconds: 60 },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Login required");
    }

    const client = new Anthropic({ apiKey: anthropicKey.value() });
    const { systemPrompt, tools, messages } = request.data;

    try {
      const response = await client.messages.create({
        model: "claude-3-haiku-20240307",
        max_tokens: 1024,
        system: systemPrompt,
        tools: tools,
        messages: messages,
      });
      return response;
    } catch (err) {
      console.error("Claude API error:", err);
      throw new HttpsError("internal", "Claude API call failed");
    }
  }
);

/**
 * Daily CRON job — runs every day at midnight UTC.
 * Checks every user: if they logged at least one expense yesterday,
 * increment their streak; otherwise reset streak and increment daysMissed.
 */
exports.updateDailyStreaks = onSchedule(
  {
    schedule: "every day 00:00",
    timeZone: "UTC",
  },
  async () => {
    const now = new Date();
    const yesterday = new Date(now);
    yesterday.setDate(yesterday.getDate() - 1);
    const yesterdayStr = yesterday.toISOString().split("T")[0];

    const usersSnapshot = await db.collection("users").get();

    const batch = db.batch();
    let updateCount = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const summary = userData.expenseSummary || {};
      const todayDate = summary.todayDate || "";

      const currentStreak = userData.streakCount || 0;
      const currentMissed = userData.daysMissed || 0;

      if (todayDate === yesterdayStr) {
        batch.update(userDoc.ref, {
          streakCount: currentStreak + 1,
        });
      } else {
        batch.update(userDoc.ref, {
          streakCount: 0,
          daysMissed: currentMissed + 1,
        });
      }

      updateCount++;

      // Firestore batches limited to 500 operations
      if (updateCount % 450 === 0) {
        await batch.commit();
      }
    }

    if (updateCount % 450 !== 0) {
      await batch.commit();
    }

    console.log(`Updated streaks for ${updateCount} users`);
  }
);

/**
 * Firestore trigger — safety net that re-validates the summary
 * whenever a new expense is created. This catches any drift from
 * client-side transaction failures.
 */
exports.onExpenseCreated = onDocumentCreated(
  "users/{uid}/expenses/{expenseId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const expenseData = snap.data();
    const uid = event.params.uid;

    const amount = expenseData.amount || 0;
    const expenseDate = expenseData.date?.toDate();
    if (!expenseDate) return;

    const now = new Date();
    const todayStr = now.toISOString().split("T")[0];
    const expenseDateStr = expenseDate.toISOString().split("T")[0];

    const userRef = db.collection("users").doc(uid);

    await db.runTransaction(async (transaction) => {
      const userDoc = await transaction.get(userRef);
      if (!userDoc.exists) return;

      const userData = userDoc.data();
      const summary = { ...(userData.expenseSummary || {}) };

      const currentMonthStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}`;

      // Get Monday of current week
      const dayOfWeek = now.getDay(); // 0=Sun, 1=Mon...6=Sat
      const daysFromMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
      const monday = new Date(now);
      monday.setDate(monday.getDate() - daysFromMonday);
      monday.setHours(0, 0, 0, 0);
      const weekMondayStr = monday.toISOString().split("T")[0];

      // Get Monday of expense's week
      const eDayOfWeek = expenseDate.getDay();
      const eDaysFromMonday = eDayOfWeek === 0 ? 6 : eDayOfWeek - 1;
      const eMonday = new Date(expenseDate);
      eMonday.setDate(eMonday.getDate() - eDaysFromMonday);
      eMonday.setHours(0, 0, 0, 0);
      const eWeekMondayStr = eMonday.toISOString().split("T")[0];

      const expenseMonthStr = `${expenseDate.getFullYear()}-${String(expenseDate.getMonth() + 1).padStart(2, "0")}`;

      let changed = false;

      // Today — only reconcile if client may have missed it
      if (expenseDateStr === todayStr && summary.todayDate !== todayStr) {
        summary.todayDate = todayStr;
        summary.todayTotal = amount;
        summary.todayEntryCount = 1;
        changed = true;
      }

      // Week
      if (eWeekMondayStr === weekMondayStr && summary.weekStartDate !== weekMondayStr) {
        summary.weekStartDate = weekMondayStr;
        summary.weekTotal = amount;
        const weekDays = new Array(7).fill(false);
        const dayIdx = eDaysFromMonday;
        weekDays[dayIdx] = true;
        summary.weekDaysLogged = weekDays;
        changed = true;
      }

      // Month
      if (expenseMonthStr === currentMonthStr && summary.monthYear !== currentMonthStr) {
        const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
        summary.monthYear = currentMonthStr;
        summary.monthTotal = amount;
        const monthDays = new Array(daysInMonth).fill(false);
        monthDays[expenseDate.getDate() - 1] = true;
        summary.monthDaysLogged = monthDays;
        changed = true;
      }

      if (changed) {
        transaction.update(userRef, { expenseSummary: summary });
      }
    });
  }
);
