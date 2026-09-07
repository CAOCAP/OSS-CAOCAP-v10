import { useState, type FormEvent } from 'react'

const joinedKey = 'caocap-waitlist-joined'

function alreadyJoined(): boolean {
  try {
    return localStorage.getItem(joinedKey) === '1'
  } catch {
    return false
  }
}

function rememberJoined() {
  try {
    localStorage.setItem(joinedKey, '1')
  } catch {
    // Private mode can block storage; the in-session success state still holds.
  }
}

export function WaitlistForm({
  id = 'waitlist-email',
  compact = false,
}: {
  id?: string
  compact?: boolean
}) {
  const [email, setEmail] = useState('')
  const [website, setWebsite] = useState('')
  const [joined, setJoined] = useState(alreadyJoined)
  const [pending, setPending] = useState(false)
  const [error, setError] = useState(false)

  async function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!email.trim() || pending) return
    setError(false)
    setPending(true)
    try {
      const response = await fetch('/joinWaitlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: email.trim(), website }),
      })
      if (!response.ok) {
        setError(true)
        return
      }
      rememberJoined()
      setJoined(true)
    } catch {
      setError(true)
    } finally {
      setPending(false)
    }
  }

  if (joined) {
    return (
      <p className="text-sm text-cyan" role="status">
        You're on the list. We'll write when it's ready.
      </p>
    )
  }

  return (
    <div className={`w-full ${compact ? 'max-w-md' : 'max-w-lg'}`}>
      <form
        onSubmit={onSubmit}
        className="flex w-full items-center gap-1 rounded-full border border-cyan/25 bg-white p-1 shadow-[0_12px_40px_rgba(77,182,255,0.18)]"
      >
        <label className="sr-only" htmlFor={id}>
          Email
        </label>
        <input
          id={id}
          type="email"
          required
          autoComplete="email"
          disabled={pending}
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          placeholder="Email address"
          className="min-h-11 min-w-0 flex-1 rounded-full bg-transparent px-4 text-sm text-navy outline-none placeholder:text-muted disabled:opacity-60"
        />
        <input
          type="text"
          name="website"
          tabIndex={-1}
          autoComplete="off"
          aria-hidden="true"
          value={website}
          onChange={(event) => setWebsite(event.target.value)}
          className="absolute -left-[9999px] h-0 w-0 overflow-hidden opacity-0"
        />
        <button
          type="submit"
          disabled={pending}
          className="min-h-11 shrink-0 rounded-full bg-cyan px-5 text-sm font-medium text-white hover:bg-[#3aa8f2] disabled:opacity-60"
        >
          {pending ? 'Joining…' : 'Join waitlist'}
        </button>
      </form>
      {error ? (
        <p className="mt-3 text-center text-sm text-muted" role="alert">
          Couldn't join right now. Try again.
        </p>
      ) : null}
    </div>
  )
}
