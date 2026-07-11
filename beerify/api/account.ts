import { createClient } from '@supabase/supabase-js'

function json(status: number, body: unknown): Response {
  return new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' } })
}

export function OPTIONS(): Response {
  return new Response(null, { status: 204, headers: {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  } })
}

export async function DELETE(request: Request): Promise<Response> {
  const url = process.env.SUPABASE_URL ?? process.env.VITE_SUPABASE_URL
  const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY
  const token = request.headers.get('Authorization')?.replace(/^Bearer\s+/i, '')
  if (!url || !serviceKey) return json(503, { error: 'Account deletion is not configured' })
  if (!token) return json(401, { error: 'Sign in before deleting your account' })

  const supabase = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data, error } = await supabase.auth.getUser(token)
  if (error || !data.user) return json(401, { error: 'Your sign-in has expired' })
  const { error: deleteError } = await supabase.auth.admin.deleteUser(data.user.id)
  if (deleteError) return json(500, { error: 'Could not delete the account' })
  return json(200, { ok: true })
}
