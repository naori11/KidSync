import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    const body = await req.json()

    // Basic validation: ensure textMessage.text and phoneNumbers array exist
    if (!body || !body.textMessage || !body.textMessage.text || !Array.isArray(body.phoneNumbers)) {
      return new Response(JSON.stringify({ error: 'Invalid payload. Expected { textMessage: { text }, phoneNumbers: ["+63..."] }' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    // Read credentials from environment (set these as Supabase function secrets)
    const SMS_USER = Deno.env.get('SMSGATE_USERNAME')
    const SMS_PASS = Deno.env.get('SMSGATE_PASSWORD')

    if (!SMS_USER || !SMS_PASS) {
      console.error('SMSGATE_USERNAME or SMSGATE_PASSWORD is not set')
      return new Response(JSON.stringify({ error: 'SMS gateway credentials are not configured' }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const auth = btoa(`${SMS_USER}:${SMS_PASS}`)
    const smsGateUrl = 'https://api.sms-gate.app/3rdparty/v1/message'

    console.log('send-sms: forwarding to SMSGate', { phoneCount: body.phoneNumbers.length })

    const resp = await fetch(smsGateUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Basic ${auth}`,
      },
      body: JSON.stringify(body),
    })

    const text = await resp.text()

    // Return SMSGate response verbatim but add CORS headers so browser clients don't fail
    const headers = { ...corsHeaders, 'Content-Type': resp.headers.get('content-type') ?? 'application/json' }
    return new Response(text, { status: resp.status, headers })
  } catch (err) {
    console.error('send-sms: error', err)
    return new Response(JSON.stringify({ error: String(err) }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })
  }
})

/*
  Deploy steps:

  1. Create a new function folder (already present here):
     supabase functions new send-sms

  2. Replace the generated index.ts with this file.

  3. Set secrets (on your machine / CI):
     supabase functions secrets set SMSGATE_USERNAME=ASTVXO SMSGATE_PASSWORD=m_cfb-t4kqx4wt

  4. Deploy the function:
     supabase functions deploy send-sms

  5. Call the function from the client instead of calling api.sms-gate.app directly.

  Example request body (client-side):
  {
    "textMessage": { "text": "Hello parent" },
    "phoneNumbers": ["+639996874402"]
  }

  Example curl (server-side):
  curl -X POST -H "Content-Type: application/json" -d '{ "textMessage": { "text": "hello" }, "phoneNumbers": ["+639996874402"] }' https://<your-functions-host>/send-sms

*/
