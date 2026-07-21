import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

function localApi() {
  return {
    name: 'beerify-local-api',
    apply: 'serve' as const,
    configureServer(server: { middlewares: { use: (handler: (request: import('node:http').IncomingMessage, response: import('node:http').ServerResponse, next: (error?: unknown) => void) => void) => void }; ssrLoadModule: (path: string) => Promise<Record<string, (request: Request) => Promise<Response>>> }) {
      process.env.BEERIFY_LOCAL_DEV = '1'
      server.middlewares.use(async (incoming, outgoing, next) => {
        const pathname = new URL(incoming.url ?? '/', 'http://localhost').pathname
        if (pathname !== '/api/room' && pathname !== '/api/invite' && pathname !== '/api/maps') return next()
        try {
          const chunks: Buffer[] = []
          for await (const chunk of incoming) chunks.push(Buffer.from(chunk))
          const headers = new Headers()
          for (const [name, value] of Object.entries(incoming.headers)) if (value) headers.set(name, Array.isArray(value) ? value.join(', ') : value)
          const request = new Request(`http://${incoming.headers.host ?? 'localhost'}${incoming.url}`, {
            method: incoming.method,
            headers,
            body: incoming.method === 'GET' || incoming.method === 'HEAD' ? undefined : Buffer.concat(chunks),
          })
          const module = await server.ssrLoadModule(pathname === '/api/room' ? '/api/room.ts' : pathname === '/api/maps' ? '/api/maps.ts' : '/api/invite.ts')
          const handler = module[incoming.method ?? 'GET']
          if (!handler) { outgoing.statusCode = 405; return outgoing.end() }
          const response = await handler(request)
          outgoing.statusCode = response.status
          response.headers.forEach((value, name) => outgoing.setHeader(name, value))
          outgoing.end(Buffer.from(await response.arrayBuffer()))
        } catch (error) { next(error) }
      })
    },
  }
}

// https://vite.dev/config/
export default defineConfig({
  plugins: [react(), localApi()],
})
