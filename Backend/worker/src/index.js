const receiptPattern = /^[A-Z]{3}[0-9]{10}$/;

export default {
  async fetch(request, env, context) {
    try {
      return await handleRequest(request, env, context);
    } catch (error) {
      if (error instanceof ServiceError) {
        return jsonResponse(
          { error: error.code, message: error.message },
          error.status
        );
      }

      console.error("Unhandled worker error", error);
      return jsonResponse(
        { error: "internal_error", message: "The case status service is unavailable." },
        500
      );
    }
  }
};

async function handleRequest(request, env, context) {
  const url = new URL(request.url);

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders() });
  }

  if (request.method === "GET" && url.pathname === "/health") {
    return jsonResponse({ ok: true, service: "mycaseupdates-api" });
  }

  if (request.method === "GET" && url.pathname === "/v1/plans") {
    return jsonResponse(planCatalog(env));
  }

  if (request.method === "POST" && url.pathname === "/v1/entitlements/verify") {
    return jsonResponse(await verifyEntitlement(request, env));
  }

  const match = url.pathname.match(/^\/v1\/cases\/([^/]+)$/);
  if (request.method !== "GET" || !match) {
    return jsonResponse({ error: "not_found", message: "Route not found." }, 404);
  }

  const plan = requestedPlan(request);
  const receiptNumber = normalizeReceiptNumber(match[1]);
  if (!receiptPattern.test(receiptNumber)) {
    return jsonResponse(
      { error: "invalid_receipt_number", message: "Receipt number must be 3 letters followed by 10 numbers." },
      400
    );
  }

  const cache = globalThis.caches?.default;
  const cacheKey = new Request(`https://cache.mycaseupdates.app/v1/cases/${receiptNumber}?plan=${plan}`, request);
  if (cache) {
    const cached = await cache.match(cacheKey);
    if (cached) {
      return cached;
    }
  }

  const status = isMockEnabled(env)
    ? mockCaseStatus(receiptNumber)
    : await fetchUSCISCaseStatus(receiptNumber, env);
  const responseBody = {
    ...status,
    plan: planMetadata(plan, env)
  };

  const response = jsonResponse(responseBody, 200, {
    "Cache-Control": `public, max-age=${cacheTTL(env)}`
  });

  if (cache) {
    context.waitUntil(cache.put(cacheKey, response.clone()));
  }

  return response;
}

async function verifyEntitlement(request, env) {
  let body = {};
  try {
    body = await request.json();
  } catch {
    throw new ServiceError("invalid_json", "Request body must be valid JSON.", 400);
  }

  const appAccountToken = typeof body.appAccountToken === "string" ? body.appAccountToken : "";
  const transactionId = typeof body.transactionId === "string" ? body.transactionId : "";

  if (!appAccountToken || !transactionId) {
    throw new ServiceError(
      "missing_purchase_information",
      "Purchase verification requires an app account token and transaction id.",
      400
    );
  }

  if (!env.APP_STORE_SHARED_SECRET && !env.APP_STORE_ISSUER_ID) {
    return {
      tier: "free",
      isPremium: false,
      verificationStatus: "not_configured",
      message: "App Store server-side purchase verification is not configured yet.",
      limits: limitsForPlan("free", env)
    };
  }

  return {
    tier: "free",
    isPremium: false,
    verificationStatus: "pending_implementation",
    message: "App Store purchase verification credentials are present, but verification logic has not been enabled.",
    limits: limitsForPlan("free", env)
  };
}

async function fetchUSCISCaseStatus(receiptNumber, env) {
  requireEnv(env, "USCIS_TOKEN_URL");
  requireEnv(env, "USCIS_CLIENT_ID");
  requireEnv(env, "USCIS_CLIENT_SECRET");
  requireEnv(env, "USCIS_BASE_URL");
  requireEnv(env, "USCIS_CASE_STATUS_PATH_TEMPLATE");

  const accessToken = await fetchAccessToken(env);
  const statusURL = buildCaseStatusURL(receiptNumber, env);
  const response = await fetch(statusURL, {
    headers: {
      "Accept": "application/json",
      "Authorization": `Bearer ${accessToken}`
    }
  });

  if (!response.ok) {
    const upstreamMessage = response.status === 404
      ? "USCIS did not return a status for this receipt number. The current backend uses the USCIS sandbox endpoint, so only USCIS sandbox test receipt numbers are available until production USCIS credentials are enabled."
      : "Unable to retrieve case status.";
    console.error("USCIS status request failed", {
      status: response.status,
      receiptNumber: maskReceiptNumber(receiptNumber)
    });
    throw new ServiceError("uscis_request_failed", upstreamMessage, response.status);
  }

  const data = await response.json();
  return mapUSCISResponse(receiptNumber, data);
}

async function fetchAccessToken(env) {
  const body = new URLSearchParams();
  body.set("grant_type", "client_credentials");
  body.set("client_id", env.USCIS_CLIENT_ID);
  body.set("client_secret", env.USCIS_CLIENT_SECRET);

  if (env.USCIS_SCOPE) {
    body.set("scope", env.USCIS_SCOPE);
  }

  const response = await fetch(env.USCIS_TOKEN_URL, {
    method: "POST",
    headers: {
      "Accept": "application/json",
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body
  });

  if (!response.ok) {
    console.error("USCIS token request failed", { status: response.status });
    throw new ServiceError("uscis_auth_failed", "Unable to authenticate with the case status provider.", 502);
  }

  const token = await response.json();
  if (!token.access_token) {
    throw new ServiceError("uscis_auth_invalid_response", "Case status provider returned an invalid auth response.", 502);
  }

  return token.access_token;
}

function buildCaseStatusURL(receiptNumber, env) {
  const baseURL = env.USCIS_BASE_URL.replace(/\/+$/, "");
  const path = env.USCIS_CASE_STATUS_PATH_TEMPLATE.replace("{receiptNumber}", encodeURIComponent(receiptNumber));
  return `${baseURL}${path.startsWith("/") ? "" : "/"}${path}`;
}

function mapUSCISResponse(receiptNumber, data) {
  const status = data?.case_status ?? data;

  return {
    receiptNumber,
    formType: firstString(status, ["formType", "form_type", "form", "caseType"]) ?? "USCIS Case",
    title: firstString(status, ["current_case_status_text_en", "title", "statusTitle", "caseStatus", "status"]) ?? "Status Updated",
    description: stripHTML(
      firstString(status, ["current_case_status_desc_en", "description", "statusDescription", "caseStatusDescription", "message"]) ??
      "The case status was updated."
    ),
    updatedAt: normalizedDate(firstString(status, ["modifiedDate", "updatedAt", "lastUpdated", "submittedDate"])) ?? new Date().toISOString()
  };
}

function mockCaseStatus(receiptNumber) {
  return {
    receiptNumber,
    formType: "USCIS Case",
    title: "Case Status Check Ready",
    description: "Mock response from the My Case Updates API. Replace Cloudflare secrets with USCIS sandbox credentials to enable live checks.",
    updatedAt: new Date().toISOString()
  };
}

function planCatalog(env) {
  return {
    free: {
      name: "Free",
      price: "$0",
      limits: limitsForPlan("free", env),
      features: [
        "Track up to 2 cases",
        "Manual refresh",
        "Masked receipt numbers",
        "Basic status history"
      ]
    },
    premium: {
      name: "Premium",
      monthlyPrice: "$1.99",
      yearlyPrice: "$14.99",
      productIds: {
        monthly: "mycaseupdates.premium.monthly",
        yearly: "mycaseupdates.premium.yearly"
      },
      limits: limitsForPlan("premium", env),
      features: [
        "Track up to 10 cases",
        "Automatic backend checks",
        "Push notifications for status changes",
        "Priority refresh",
        "Richer status history"
      ]
    }
  };
}

function planMetadata(plan, env) {
  return {
    tier: plan,
    limits: limitsForPlan(plan, env),
    source: "request_header_until_storekit_verification"
  };
}

function limitsForPlan(plan, env) {
  const isPremium = plan === "premium";
  return {
    caseLimit: numberFromEnv(env, isPremium ? "PREMIUM_CASE_LIMIT" : "FREE_CASE_LIMIT", isPremium ? 10 : 2),
    automaticRefreshIntervalMinutes: numberFromEnv(
      env,
      isPremium ? "PREMIUM_REFRESH_INTERVAL_MINUTES" : "FREE_REFRESH_INTERVAL_MINUTES",
      isPremium ? 60 : 0
    ),
    pushNotifications: isPremium,
    automaticChecks: isPremium
  };
}

function requestedPlan(request) {
  const value = request.headers.get("X-Subscription-Tier")?.toLowerCase();
  return value === "premium" ? "premium" : "free";
}

function firstString(object, keys) {
  for (const key of keys) {
    const value = object?.[key];
    if (typeof value === "string" && value.trim()) {
      return value;
    }
  }
  return null;
}

function stripHTML(value) {
  return value
    .replace(/<[^>]*>/g, "")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/\s+/g, " ")
    .trim();
}

function normalizedDate(value) {
  if (!value) {
    return null;
  }

  const match = value.match(/^(\d{2})-(\d{2})-(\d{4})\s+(\d{2}):(\d{2}):(\d{2})$/);
  if (match) {
    const [, month, day, year, hour, minute, second] = match;
    return new Date(Date.UTC(Number(year), Number(month) - 1, Number(day), Number(hour), Number(minute), Number(second))).toISOString();
  }

  const parsed = Date.parse(value);
  if (Number.isFinite(parsed)) {
    return new Date(parsed).toISOString();
  }
  return null;
}

function normalizeReceiptNumber(value) {
  return decodeURIComponent(value).toUpperCase().replace(/[^A-Z0-9]/g, "");
}

function maskReceiptNumber(receiptNumber) {
  return `${"*".repeat(Math.max(0, receiptNumber.length - 4))}${receiptNumber.slice(-4)}`;
}

function cacheTTL(env) {
  const value = Number(env.CACHE_TTL_SECONDS ?? "300");
  return Number.isFinite(value) && value >= 0 ? value : 300;
}

function numberFromEnv(env, key, fallback) {
  const value = Number(env[key]);
  return Number.isFinite(value) ? value : fallback;
}

function isMockEnabled(env) {
  return String(env.MOCK_USCIS_RESPONSES ?? "false").toLowerCase() === "true";
}

function requireEnv(env, key) {
  if (!env[key]) {
    throw new ServiceError("missing_configuration", `Missing backend configuration: ${key}`, 500);
  }
}

function jsonResponse(body, status = 200, headers = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      ...corsHeaders(),
      ...headers
    }
  });
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization, X-Subscription-Tier"
  };
}

class ServiceError extends Error {
  constructor(code, message, status = 500) {
    super(message);
    this.code = code;
    this.status = status;
  }
}
