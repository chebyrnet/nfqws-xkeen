'use client'

import { useEffect } from 'react'
import { useRouter } from 'next/navigation'

export function ClientRedirect({ to }) {
  const router = useRouter()

  useEffect(() => {
    router.replace(to)
  }, [router, to])

  return (
    <p>
      Страница переехала:{' '}
      <a href={to}>{to}</a>
    </p>
  )
}
