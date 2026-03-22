/// Simple runtime configuration for services.
/// Set SUPABASE_FUNCTIONS_BASE to your Supabase functions base URL, e.g.
/// https://<project>.functions.supabase.co

const String SUPABASE_FUNCTIONS_BASE =
    'https://zouitgpqqudhqdcbuhbz.supabase.co/functions/v1';

/// If you deploy the send-sms function at the root path /send-sms, the
/// full URL used by the client will be:
///   '$SUPABASE_FUNCTIONS_BASE/send-sms'
