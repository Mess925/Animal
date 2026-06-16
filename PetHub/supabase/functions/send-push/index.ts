import { serve } from "https://deno.land/std/http/server.ts"

serve(async () => {
  return new Response(
    JSON.stringify({
      success: true,
      message: "send-push function is working"
    }),
    {
      headers: { "Content-Type": "application/json" }
    }
  )
})