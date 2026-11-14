import Link from 'next/link'
import './page.css'

export const metadata = {
  title: 'nfqws-xkeen',
  description:
    'Пакет для Keenetic Entware: подружить mihomo (XKeen) и nfqws2'
}

export default function HomePage() {
  return (
    <div className="home-content">
      <div className="content-container">
        <h1 className="headline">
          Подружите mihomo и nfqws2
          <br /> на Keenetic
        </h1>
        <p className="subtitle">
          nfqws-xkeen - небольшой пакет для Entware. Он помогает направить в
          nfqws2 только тот трафик, который вы сами выбрали в mihomo (XKeen), и
          не трогать остальной интернет на роутере.
        </p>
        <div className="cta-row">
          <Link className="cta" href="/docs">
            Открыть документацию <span>-&gt;</span>
          </Link>
          <a
            className="cta-secondary"
            href="https://github.com/chebyrnet/nfqws-xkeen"
          >
            GitHub
          </a>
        </div>
      </div>

      <div className="features-container">
        <div className="features-grid">
          <div className="feature-card wide">
            <h3>Зачем это нужно</h3>
            <p>
              XKeen с mihomo умеет гибко раскидывать трафик по прокси. nfqws2
              умеет обрабатывать пакеты для обхода DPI. Но из коробки они не
              связаны: пакет говорит nfqws2 принимать только пакеты с меткой от
              отдельного выхода NFQWS в mihomo. Вы сами решаете, какие сайты и
              приложения туда отправлять.
            </p>
          </div>
          <div className="feature-card">
            <h3>Без своей корявой цепочки</h3>
            <p>
              nfqws2 сам строит полный набор правил firewall. Пакет не выкидывает
              штатную логику, а подключает фильтр по метке mihomo и переживает
              обновления через команду repatch.
            </p>
          </div>
          <div className="feature-card">
            <h3>Простая установка</h3>
            <p>
              Одна команда с GitHub, меню в консоли, проверка статуса и
              обновлений. Подходит обычному пользователю Entware на Keenetic.
            </p>
          </div>
          <div className="feature-card">
            <h3>Понятные настройки</h3>
            <p>
              В nfqws2.conf появляется отдельный блок с пояснениями на русском:
              включить режим метки, задать mark и маску так же, как в mihomo.
            </p>
          </div>
          <div className="feature-card">
            <h3>После обновления nfqws2</h3>
            <p>
              Обновили nfqws2 и пропал патч? Выполните nfqws-xkeen repatch и
              nfqws-xkeen doctor. Бэкапы пишутся автоматически.
            </p>
          </div>
        </div>
      </div>
    </div>
  )
}
