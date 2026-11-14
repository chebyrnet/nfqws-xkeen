import nextra from 'nextra'

// https://nextra.site/docs/guide/static-exports
// https://nextra.site/docs/file-conventions/content-directory
const withNextra = nextra({
  search: {
    codeblocks: false
  },
  contentDirBasePath: '/docs'
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
