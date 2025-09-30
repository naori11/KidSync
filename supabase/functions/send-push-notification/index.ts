import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ServiceAccount {
  private_key_id: string;
  private_key: string;
  client_email: string;
  project_id: string;
}

// Simplified Google OAuth2 for Firebase
async function getGoogleAccessToken(serviceAccount: ServiceAccount): Promise<string> {
  try {
    // Create JWT header
    const header = {
      alg: 'RS256',
      typ: 'JWT',
      kid: serviceAccount.private_key_id,
    }

    const now = Math.floor(Date.now() / 1000)
    const payload = {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }

    // Base64URL encode header and payload
    const headerB64 = btoa(JSON.stringify(header))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '')

    const payloadB64 = btoa(JSON.stringify(payload))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '')

    const signatureInput = `${headerB64}.${payloadB64}`

    // Parse private key
    const privateKeyPem = serviceAccount.private_key
      .replace(/-----BEGIN PRIVATE KEY-----/, '')
      .replace(/-----END PRIVATE KEY-----/, '')
      .replace(/\s/g, '')

    const privateKeyBuffer = Uint8Array.from(atob(privateKeyPem), c => c.charCodeAt(0))

    // Import private key for signing
    const cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      privateKeyBuffer,
      {
        name: 'RSASSA-PKCS1-v1_5',
        hash: 'SHA-256',
      },
      false,
      ['sign']
    )

    // Sign the JWT
    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      cryptoKey,
      new TextEncoder().encode(signatureInput)
    )

    const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=/g, '')

    const jwt = `${signatureInput}.${signatureB64}`

    // Exchange JWT for access token
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    })

    const tokenResult = await tokenResponse.json()

    if (!tokenResponse.ok) {
      console.error('❌ Token exchange failed:', tokenResult)
      throw new Error(`Token exchange failed: ${JSON.stringify(tokenResult)}`)
    }

    return tokenResult.access_token
  } catch (error) {
    console.error('❌ JWT creation error:', error)
    throw new Error(`Failed to create access token: ${error}`)
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { to, notification, data } = await req.json()

    // Get Firebase service account from Supabase secrets
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountJson) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable is not set')
    }

    const serviceAccount = JSON.parse(serviceAccountJson)
    const projectId = serviceAccount.project_id

    console.log('🔐 Using service account:', serviceAccount.client_email)
    console.log('🏗️ Project ID:', projectId)

    // Get OAuth2 access token
    const accessToken = await getGoogleAccessToken(serviceAccount)

    // Prepare FCM v1 API payload - all data values must be strings
    const fcmData: Record<string, string> = {}
    if (data) {
      Object.keys(data).forEach(key => {
        // Convert all values to strings for FCM v1 API
        fcmData[key] = typeof data[key] === 'string' ? data[key] : JSON.stringify(data[key])
      })
    }
    fcmData.click_action = 'FLUTTER_NOTIFICATION_CLICK'

    const payload = {
      message: {
        token: to,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: fcmData,
        android: {
          priority: 'high',
          notification: {
            sound: notification.sound || 'default',
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          headers: {
            'apns-priority': '10',
          },
          payload: {
            aps: {
              sound: notification.sound || 'default',
              ...(notification.badge && { badge: notification.badge }),
              'content-available': 1,
            },
          },
        },
      },
    }

    // Send to FCM v1 API
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${accessToken}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(payload),
      }
    )

    const result = await response.json()

    if (response.ok) {
      console.log('✅ FCM v1 message sent successfully:', result)
      return new Response(
        JSON.stringify({ success: true, result }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    } else {
      console.error('❌ FCM v1 error:', result)
      throw new Error(`FCM v1 request failed: ${JSON.stringify(result)}`)
    }
  } catch (error) {
    console.error('❌ Error in send-push-notification function:', error)
    const errorMessage = error instanceof Error ? error.message : 'Unknown error occurred'
    return new Response(
      JSON.stringify({ error: errorMessage }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})

/* To deploy this function:
1. Create the function in Supabase Dashboard:
   supabase functions new send-push-notification

2. Replace the generated index.ts with this code

3. Set the FCM_SERVER_KEY secret:
   supabase secrets set FCM_SERVER_KEY=your_fcm_server_key_here

4. Deploy the function:
   supabase functions deploy send-push-notification
*/