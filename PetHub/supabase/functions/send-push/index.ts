import { serve } from "https://deno.land/std/http/server.ts"

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

  const header = {
    alg: "ES256",
    kid: keyId
  }

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

serve(async (req) => {
  try {
    const { token, title, body } = await req.json()

    if (!token) {
      return Response.json({ error: "Missing token" }, { status: 400 })
    }

    const jwt = await createJWT()
    const bundleId = Deno.env.get("APNS_BUNDLE_ID")!

    const response = await fetch(
      `https://api.sandbox.push.apple.com/3/device/${token}`,
      {
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
              title: title ?? "PetHub",
              body: body ?? "Test notification"
            },
            sound: "default"
          }
        })
      }
    )

    const text = await response.text()

    return Response.json({
      success: response.ok,
      status: response.status,
      response: text
    })
  } catch (error) {
    return Response.json({
      success: false,
      error: String(error)
    }, { status: 500 })
  }
})