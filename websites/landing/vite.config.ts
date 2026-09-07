import path from 'node:path'
import { fileURLToPath } from 'node:url'
import tailwindcss from '@tailwindcss/vite'
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

const root = fileURLToPath(new URL('.', import.meta.url))
const repoRoot = path.resolve(root, '../..')

export default defineConfig({
  plugins: [react(), tailwindcss()],
  resolve: {
    alias: {
      '@brand': path.resolve(repoRoot, 'assets/brand/cdl-v2'),
    },
  },
  server: {
    fs: {
      allow: [repoRoot],
    },
    proxy: {
      '/joinWaitlist': {
        target: 'https://us-central1-caocap-ficruty.cloudfunctions.net',
        changeOrigin: true,
      },
    },
  },
})
