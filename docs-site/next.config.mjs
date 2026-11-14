import nextra from 'nextra'

// https://nextra.site/docs/guide/static-exports
const withNextra = nextra({
  search: {
    codeblocks: false
  }
})

const isPages = process.env.GITHUB_PAGES === 'true'

/**
 * @type {import('next').NextConfig}
 */
const nextConfig = {
  output: 'export',
  images: {
    unoptimized: true
  },
  reactStrictMode: true,
  ...(isPages
    ? {
        basePath: '/nfqws-xkeen',
        assetPrefix: '/nfqws-xkeen/'
      }
    : {})
}

export default withNextra(nextConfig)
