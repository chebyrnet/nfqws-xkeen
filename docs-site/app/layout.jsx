import { Footer, Layout, Navbar } from 'nextra-theme-docs'
import { Head } from 'nextra/components'
import { getPageMap } from 'nextra/page-map'
import 'nextra-theme-docs/style.css'

export const metadata = {
  title: {
    default: 'nfqws-xkeen',
    template: '%s - nfqws-xkeen'
  },
  description:
    'Пакет для Keenetic Entware: подружить mihomo (XKeen) и nfqws2'
}

const navbar = (
  <Navbar
    logo={<b>nfqws-xkeen</b>}
    projectLink="https://github.com/chebyrnet/nfqws-xkeen"
  />
)

const footer = (
  <Footer>MIT {new Date().getFullYear()} nfqws-xkeen</Footer>
)

export default async function RootLayout({ children }) {
  return (
    <html lang="ru" dir="ltr" suppressHydrationWarning>
      <Head />
      <body>
        <Layout
          navbar={navbar}
          footer={footer}
          pageMap={await getPageMap('/docs')}
          docsRepositoryBase="https://github.com/chebyrnet/nfqws-xkeen/tree/main/docs-site"
          editLink="Редактировать на GitHub"
        >
          {children}
        </Layout>
      </body>
    </html>
  )
}
