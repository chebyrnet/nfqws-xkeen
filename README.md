# nfqws-xkeen

Связка **XKeen / mihomo** → **nfqws2** на Keenetic (Entware): в NFQUEUE попадают только пакеты с `routing-mark` от outbound’а NFQWS.

Пакет патчит штатный firewall nfqws2 (полный набор правил POSTROUTING / PREROUTING / NAT), а не подменяет его урезанной цепочкой. После обновления nfqws2 достаточно `nfqws-xkeen repatch`.

[Документация](https://chebyrnet.github.io/nfqws-xkeen/) · [исходники](docs-site/content/) · [Issues](https://github.com/chebyrnet/nfqws-xkeen/issues)

---

## Зачем

Ручная схема с `S99nfqws-xkeen` и `XKEEN_MARK_ONLY` + `return 0` в `S51nfqws2` отключает штатные правила. Своя цепочка легко отстаёт от портов/стратегий nfqws2 (нет PRE/NAT/FIN-RST).

**nfqws-xkeen** вместо этого:

1. Вписывает в `nfqws2.conf` блок настроек с пояснениями.
2. Патчит `S51nfqws2`: при `XKEEN_MARK_ONLY=1` подставляет ваш mark в `POLICY_MARK`.
3. Оставляет работу firewall nfqws2 и хук `100-nfqws2.sh`.

```text
клиент → mihomo (proxy NFQWS, routing-mark 0x10000000)
       → WAN → iptables nfqws_* (только mark) → NFQUEUE → nfqws2
```

## Требования

- Keenetic + Entware
- [nfqws2-keenetic](https://github.com/nfqws/nfqws2-keenetic)
- [XKeen](https://github.com/jameszeroX/XKeen) с ядром **mihomo**

## Установка

```sh
curl -fsSL https://raw.githubusercontent.com/chebyrnet/nfqws-xkeen/main/install.sh | sh
```

Или из клона репозитория:

```sh
sh install.sh --from-dir .
```

Установщик кладёт файлы в `/opt/share/nfqws-xkeen`, линк `nfqws-xkeen` → `/opt/sbin/`, делает бэкап, патчит `S51` и conf, перезапускает nfqws2.

## Быстрый старт (mihomo)

В `proxies`:

```yaml
proxies:
  - name: NFQWS
    type: direct
    udp: true
    ip-version: ipv4
    routing-mark: 268435456   # 0x10000000
```

Метка должна совпадать с блоком в `/opt/etc/nfqws2/nfqws2.conf`:

```sh
XKEEN_MARK_ONLY=1
XKEEN_ROUTE_MARK=0x10000000
XKEEN_ROUTE_MASK=0x10000000
```

На нужных правилах/группах выбирайте outbound **NFQWS**. Подробнее — [docs-site/content/mihomo-setup.mdx](docs-site/content/mihomo-setup.mdx).

Локально сайт доки (Nextra):

```sh
cd docs-site && npm install && npm run dev
# статическая сборка:
npm run build
# под GitHub Pages (basePath /nfqws-xkeen):
npm run build:pages
```

После пуша в `main` workflow `Deploy docs` выкладывает `docs-site/out` на GitHub Pages (`https://chebyrnet.github.io/nfqws-xkeen/`). В настройках репо: Pages → Source → GitHub Actions.

Рекомендуется (mihomo уже фильтрует домены):

```sh
NFQWS_EXTRA_ARGS="$MODE_ALL"
```

## CLI

```sh
nfqws-xkeen              # меню
nfqws-xkeen status
nfqws-xkeen enable
nfqws-xkeen disable      # XKEEN_MARK_ONLY=0
nfqws-xkeen repatch      # после opkg upgrade nfqws2
nfqws-xkeen doctor
nfqws-xkeen check        # есть ли новая версия на GitHub
nfqws-xkeen uninstall
```

## Обновление nfqws2

```sh
# обновили nfqws2 штатно
nfqws-xkeen repatch
nfqws-xkeen doctor
```

Перед патчем всегда пишется бэкап в `/opt/var/lib/nfqws-xkeen/`.

## Удаление

```sh
nfqws-xkeen uninstall
# или:
curl -fsSL https://raw.githubusercontent.com/chebyrnet/nfqws-xkeen/main/uninstall.sh | sh

# бэкапы (по желанию):
rm -rf /opt/var/lib/nfqws-xkeen
```

## Миграция со старых ручных скриптов

При `enable` / install, если найдены `/opt/etc/init.d/S99nfqws-xkeen` или `zz-nfqws-xkeen.sh`, они отключаются и переносятся в state-директорию. Restore правил делает штатный `100-nfqws2.sh`.

## Лицензия

MIT — см. [LICENSE](LICENSE).

Обход DPI регулируется законодательством вашей страны. Используйте на свой страх и риск.
