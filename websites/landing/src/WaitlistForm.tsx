import { useState, type FormEvent } from 'react'

export function WaitlistForm({
  id = 'waitlist-email',
}: {
  id?: string
}) {
  const [email, setEmail] = useState('')
  const [joined, setJoined] = useState(false)

  function onSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!email.trim()) return
    setJoined(true)
  }

  if (joined) {
    return (
      <p className="text-sm text-cyan" role="status">
        You're on the list. We'll write when it's ready.
      </p>
    )
  }

  return (
    <form
      onSubmit={onSubmit}
      className="flex w-full max-w-lg items-center gap-1 rounded-full border border-cyan/25 bg-white p-1 shadow-[0_12px_40px_rgba(77,182,255,0.18)]"
    >
      <label className="sr-only" htmlFor={id}>
        Email
      </label>
      <input
        id={id}
        type="email"
        required
        autoComplete="email"
        value={email}
        onChange={(event) => setEmail(event.target.value)}
        placeholder="Email address"
        className="min-h-11 min-w-0 flex-1 rounded-full bg-transparent px-4 text-sm text-navy outline-none placeholder:text-muted"
      />
      <button
        type="submit"
        className="min-h-11 shrink-0 rounded-full bg-cyan px-5 text-sm font-medium text-white hover:bg-[#3aa8f2]"
      >
        Join waitlist
      </button>
    </form>
  )
}
