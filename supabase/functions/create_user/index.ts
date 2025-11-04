import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2.39.7";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization, x-client-info, apikey"
};
Deno.serve(async (req)=>{
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders
    });
  }
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", {
      status: 405,
      headers: corsHeaders
    });
  }
  const body = await req.json();
  const { email, role, fname, mname, lname, contact_number, position, profile_image_url, suffix, plate_number } = body;
  if (!email || !role || !fname || !lname) {
    return new Response(JSON.stringify({
      error: 'Missing required fields.'
    }), {
      status: 400,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  const supabase = createClient(Deno.env.get('SUPABASE_URL'), Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'));
  // Check if a public.users row already exists for this email BEFORE inviting
  const { data: existingByEmail, error: existingByEmailErr } = await supabase.from('users').select('id').eq('email', email).maybeSingle();
  if (existingByEmail) {
    return new Response(JSON.stringify({
      error: 'A user with this email already exists.',
      field_errors: {
        email: 'Email is already registered.'
      }
    }), {
      status: 409,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  // Invite user by email
  const { data: userData, error: inviteError } = await supabase.auth.admin.inviteUserByEmail(email, {
    redirectTo: 'https://ksync.netlify.app/#/set-password',
    data: {
      role,
      fname,
      mname,
      lname,
      contact_number,
      position,
      profile_image_url,
      suffix,
      plate_number
    }
  });
  // Log the invite response for debugging
  console.log("User Invite Response:", userData, inviteError);
  if (inviteError) {
    return new Response(JSON.stringify({
      error: inviteError.message
    }), {
      status: 400,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  const id = userData.user?.id;
  if (!id) {
    return new Response(JSON.stringify({
      error: "User ID missing after invite"
    }), {
      status: 400,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  // Check if a public.users row already exists for this id (defensive check)
  const { data: existingById, error: existingByIdErr } = await supabase.from('users').select('id').eq('id', id).maybeSingle();
  if (existingById) {
    return new Response(JSON.stringify({
      error: 'A user record with this id already exists.'
    }), {
      status: 409,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  // Insert into users table
  const { error: insertError } = await supabase.from('users').insert([
    {
      id,
      email,
      fname,
      mname,
      lname,
      contact_number,
      position,
      role,
      profile_image_url,
      suffix,
      plate_number
    }
  ]);
  if (insertError) {
    // Handle a possible race condition where another process inserted between the check and the insert
    if (insertError?.code === '23505' || insertError.message && insertError.message.toLowerCase().includes('duplicate key')) {
      return new Response(JSON.stringify({
        error: 'A user with this email or id already exists.',
        field_errors: {
          email: 'Email is already registered.'
        }
      }), {
        status: 409,
        headers: {
          ...corsHeaders,
          "Content-Type": "application/json"
        }
      });
    }
    // For other insert errors, consider cleaning up the invited user in auth
    // This is optional but good practice to prevent orphaned auth users
    try {
      await supabase.auth.admin.deleteUser(id);
      console.log(`Cleaned up auth user ${id} due to insert failure`);
    } catch (cleanupError) {
      console.error(`Failed to cleanup auth user ${id}:`, cleanupError);
    }
    return new Response(JSON.stringify({
      error: `Failed to insert user into table: ${insertError.message}`
    }), {
      status: 400,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json"
      }
    });
  }
  return new Response(JSON.stringify({
    id,
    message: "User invited successfully and data inserted."
  }), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json"
    }
  });
});
