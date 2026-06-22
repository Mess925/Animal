import { serve } from "https://deno.land/std/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

function base64url(input: ArrayBuffer | string) {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input)

  let binary = ""
  for (const byte of bytes) binary += String.fromCharCode(byte)

  return btoa(binary)
    .replaceAll("+", "-")
    .replaceAll("/", "_")
    .replaceAll("=", "")
}

async function createJWT() {
  const keyId = Deno.env.get("APNS_KEY_ID")!
  const teamId = Deno.env.get("APNS_TEAM_ID")!
  const p8 = Deno.env.get("APNS_P8_KEY")!

  const pem = p8
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "")

  const keyData = Uint8Array.from(atob(pem), c => c.charCodeAt(0))

  const privateKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"]
  )

  const header = { alg: "ES256", kid: keyId }
  const payload = {
    iss: teamId,
    iat: Math.floor(Date.now() / 1000)
  }

  const unsignedToken =
    `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(payload))}`

  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    privateKey,
    new TextEncoder().encode(unsignedToken)
  )

  const sigBytes = new Uint8Array(signature)

  if (sigBytes.length !== 64) {
    throw new Error(`Invalid ES256 signature length: ${sigBytes.length}`)
  }

  return `${unsignedToken}.${base64url(sigBytes.buffer)}`
}

async function sendApnsPush(params: {
  token: string
  title: string
  body: string
}) {
  const jwt = await createJWT()
  const bundleId = Deno.env.get("APNS_BUNDLE_ID")!
  const apnsEnvironment = Deno.env.get("APNS_ENVIRONMENT") ?? "sandbox"

  const apnsHost =
    apnsEnvironment === "production"
      ? "https://api.push.apple.com"
      : "https://api.sandbox.push.apple.com"

  const response = await fetch(`${apnsHost}/3/device/${params.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${jwt}`,
      "apns-topic": bundleId,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json"
    },
    body: JSON.stringify({
      aps: {
        alert: {
          title: params.title,
          body: params.body
        },
        sound: "default"
      }
    })
  })

  const text = await response.text()

  return {
    token: params.token.slice(0, 8) + "...",
    success: response.ok,
    status: response.status,
    response: text
  }
}

serve(async (req) => {
  try {
    if (req.method !== "POST") {
      return Response.json({ error: "Method not allowed" }, { status: 405 })
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const internalSecret = Deno.env.get("INTERNAL_NOTIFY_SECRET")

    const authHeader = req.headers.get("Authorization") ?? ""
    const requestedByInternalService =
      internalSecret != null &&
      req.headers.get("X-Internal-Notify-Secret") === internalSecret

    const { user_id, title, body } = await req.json()

    if (!user_id) {
      return Response.json({ error: "Missing user_id" }, { status: 400 })
    }

    if (!requestedByInternalService) {
      if (!authHeader.startsWith("Bearer ")) {
        return Response.json({ error: "Missing auth token" }, { status: 401 })
      }

      const authedClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } }
      })

      const { data: { user }, error: authError } = await authedClient.auth.getUser()

      if (authError || !user) {
        return Response.json({ error: "Invalid auth token" }, { status: 401 })
      }

      if (user.id !== user_id) {
        return Response.json(
          { error: "Not authorized to notify this user" },
          { status: 403 }
        )
      }
    }

    const admin = createClient(supabaseUrl, serviceRoleKey)

    const { data: tokens, error } = await admin
      .from("push_tokens")
      .select("token")
      .eq("user_id", user_id)

    if (error) {
      return Response.json(
        { success: false, error: error.message },
        { status: 500 }
      )
    }

    if (!tokens || tokens.length === 0) {
      return Response.json({
        success: false,
        message: "No push tokens found for user"
      })
    }

    const results = []

    for (const row of tokens) {
      const result = await sendApnsPush({
        token: row.token,
        title: title ?? "PetHub",
        body: body ?? "You have a new update"
      })

      results.push(result)
    }

    return Response.json({
      success: results.some((r) => r.success),
      sent: results.filter((r) => r.success).length,
      total: results.length,
      results
    })
  } catch (error) {
    return Response.json(
      {
        success: false,
        error: String(error)
      },
      { status: 500 }
    )
  }
})
