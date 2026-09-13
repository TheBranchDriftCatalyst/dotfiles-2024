import { useEffect, useState } from 'react'

export function App() {
  const [msg, setMsg] = useState('…waiting for backend')

  useEffect(() => {
    fetch('/api/hello')
      .then((r) => r.json())
      .then((d) => setMsg(d.msg))
      .catch(() =>
        setMsg(
          'backend not running — try: cd backend && uv run uvicorn main:app --reload'
        )
      )
  }, [])

  return (
    <main style={{ fontFamily: 'system-ui', padding: '2rem' }}>
      <h1>⚗️ flake + direnv demo</h1>
      <p>backend says: {msg}</p>
    </main>
  )
}
