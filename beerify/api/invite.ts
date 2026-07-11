function escapeHtml(value: string): string {
  return value.replace(/[&<>'"]/g, (character) => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;',
  })[character]!)
}

export async function GET(request: Request): Promise<Response> {
  const raw = new URL(request.url).searchParams.get('code')?.trim().toUpperCase() ?? ''
  const code = /^[A-Z2-9]{6}$/.test(raw) ? raw : ''
  const destination = code ? `/?room=${encodeURIComponent(code)}&via=invite` : '/'
  const nativeDestination = code ? `beerify://join?room=${encodeURIComponent(code)}` : 'beerify://open'
  const title = code ? `Join Beerify room ${code}` : 'Join the night on Beerify'
  const safeTitle = escapeHtml(title)
  return new Response(`<!doctype html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <title>${safeTitle}</title>
    <meta property="og:title" content="${safeTitle}">
    <meta property="og:description" content="Your mates are already in. Join the room, log the order and see how the night unfolds.">
    <meta property="og:type" content="website">
    <meta name="theme-color" content="#10241c">
    <meta http-equiv="refresh" content="2;url=${destination}">
  </head>
  <body style="background:#10241c;color:#f7f7f4;font:18px system-ui;padding:2rem">
    <p>Opening Beerify…</p>
    <script>
      if (/iPhone|iPad|iPod/.test(navigator.userAgent)) {
        location.href = ${JSON.stringify(nativeDestination)};
        setTimeout(() => location.replace(${JSON.stringify(destination)}), 900);
      } else {
        location.replace(${JSON.stringify(destination)});
      }
    </script>
  </body>
</html>`, { headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' } })
}
