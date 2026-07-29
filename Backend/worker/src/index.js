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

  const match = url.pathname.match(/^\/v1\/cases\/([^/]+)$/);
  if (request.method !== "GET" || !match) {
    return jsonResponse({ error: "not_found", message: "Route not found." }, 404);
  }

  const receiptNumber = normalizeReceiptNumber(match[1]);
  if (!receiptPattern.test(receiptNumber)) {
    return jsonResponse(
      { error: "invalid_receipt_number", message: "Receipt number must be 3 letters followed by 10 numbers." },
      400
    );
  }

  const cache = caches.default;
  const cacheKey = new Request(`https://cache.mycaseupdates.app/v1/cases/${receiptNumber}`, request);
  const cached = await cache.match(cacheKey);
  if (cached) {
    return cached;
  }

  const responseBody = isMockEnabled(env)
    ? mockCaseStatus(receiptNumber)
    : await fetchUSCISCaseStatus(receiptNumber, env);

  const response = jsonResponse(responseBody, 200, {
    "Cache-Control": `public, max-age=${cacheTTL(env)}`
  });

  context.waitUntil(cache.put(cacheKey, response.clone()));
  return response;
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
    console.error("USCIS status request failed", {
      status: response.status,
      receiptNumber: maskReceiptNumber(receiptNumber)
    });
    throw new ServiceError("uscis_request_failed", "Unable to retrieve case status.", response.status);
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
  return {
    receiptNumber,
    formType: firstString(data, ["formType", "form_type", "form", "caseType"]) ?? "USCIS Case",
    title: firstString(data, ["title", "statusTitle", "caseStatus", "status"]) ?? "Status Updated",
    description: firstString(data, ["description", "statusDescription", "caseStatusDescription", "message"]) ?? "The case status was updated.",
    updatedAt: firstString(data, ["updatedAt", "lastUpdated", "modifiedDate"]) ?? new Date().toISOString()
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

function firstString(object, keys) {
  for (const key of keys) {
    const value = object?.[key];
    if (typeof value === "string" && value.trim()) {
      return value;
    }
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
    "Access-Control-Allow-Headers": "Content-Type, Authorization"
  };
}

class ServiceError extends Error {
  constructor(code, message, status = 500) {
    super(message);
    this.code = code;
    this.status = status;
  }
}
