import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    // frontend dev server forwards /api/* to the fastapi backend;
    // BACKEND_URL is set by k8s (http://backend:8000), defaults to local
    proxy: {
      '/api': process.env.BACKEND_URL ?? 'http://localhost:8000',
    },
  },
})
