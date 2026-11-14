# nfqws-xkeen

Пакет для Keenetic с Entware, который помогает **подружить mihomo (XKeen) и nfqws2**.

Идея простая. У вас уже стоит (или вы ставите) прозрачный прокси на роутере через XKeen с ядром mihomo. Отдельно стоит nfqws2 - программа, которая обрабатывает трафик и помогает обходить DPI. Сами по себе они друг о друге не знают: mihomo умеет помечать нужные пакеты специальной меткой, а nfqws2 по умолчанию ловит трафик по своим правилам (списки доменов, политика Keenetic и так далее).

**nfqws-xkeen** как раз и делает мост между ними:

1. В конфиге mihomo вы заводите отдельный "выход" (proxy) с именем вроде `NFQWS` и меткой пакета.
2. Нужные сайты и сервисы направляете на этот выход (YouTube, Discord и что ещё решите сами).
3. Пакет настраивает nfqws2 так, чтобы он обрабатывал **только** пакеты с этой меткой, а остальной трафик не трогал.

При этом nfqws2 продолжает сам строить полный набор своих правил firewall. Пакет не подменяет их своей урезанной схемой, а аккуратно подключает фильтр по метке mihomo. После обновления nfqws2 обычно достаточно одной команды `nfqws-xkeen repatch`.

Полная документация: [сайт](https://chebyrnet.github.io/nfqws-xkeen/) | [исходники доки](docs-site/content/) | [Issues](https://github.com/chebyrnet/nfqws-xkeen/issues)

---

## Кому это нужно

Если вы на Keenetic используете:

- **XKeen** с ядром **mihomo** - чтобы часть трафика шла через прокси, а часть - напрямую;
- **nfqws2** - чтобы "прямой" трафик к заблокированным или режущимся ресурсам обрабатывался на роутере;

и хотите, чтобы в nfqws2 попадал не весь интернет, а только то, что вы сами выбрали в правилах mihomo - этот пакет как раз для такого сценария.

Типичный пример: обычный трафик идёт через VPN/прокси-группы mihomo, а YouTube и Discord выводите "напрямую", но через nfqws2, чтобы DPI не мешал.

---

## Что должно быть установлено заранее

1. Роутер Keenetic с **Entware**.
2. Пакет **[nfqws2-keenetic](https://github.com/nfqws/nfqws2-keenetic)** (служба `/opt/etc/init.d/S51nfqws2` и конфиг `/opt/etc/nfqws2/nfqws2.conf`).
3. **[XKeen](https://github.com/jameszeroX/XKeen)** с ядром **mihomo** (не только Xray).

Полезные ссылки по окружению: [документация Keenetic](https://support.keenetic.ru/ultra/kn-1811/ru/20980.html), [веб для nfqws](https://github.com/nfqws/nfqws-keenetic-web), [Xkeen-UI](https://github.com/umarcheh001/Xkeen-UI).

---

## Установка на роутер

Одной командой с GitHub:

```sh
curl -fsSL https://raw.githubusercontent.com/chebyrnet/nfqws-xkeen/main/install.sh | sh
```

Или из клона репозитория на самом роутере / с машины, откуда копируете файлы:

```sh
sh install.sh --from-dir .
```

Что сделает установщик:

1. Положит файлы в `/opt/share/nfqws-xkeen`.
2. Сделает команду `nfqws-xkeen` в `/opt/sbin/nfqws-xkeen`.
3. Сохранит резервные копии `S51nfqws2` и `nfqws2.conf` в `/opt/var/lib/nfqws-xkeen/`.
4. Добавит в `nfqws2.conf` блок настроек nfqws-xkeen.
5. Пропатчит `S51nfqws2`, чтобы при включённом режиме метки работал фильтр mihomo.
6. Перезапустит nfqws2.

Если nfqws2 ещё не установлен, установщик предупредит и не будет ломать систему. Сначала поставьте nfqws2, потом снова запустите установку или выполните `nfqws-xkeen enable`.

---

## Быстрая настройка mihomo

### 1. Добавьте proxy NFQWS

В конфиге mihomo (через XKeen / Xkeen-UI / файл конфига) в секции `proxies` добавьте:

```yaml
proxies:
  - name: NFQWS
    type: direct
    udp: true
    ip-version: ipv4
    routing-mark: 268435456   # это hex 0x10000000
```

Число `268435456` и значение `XKEEN_ROUTE_MARK=0x10000000` в `/opt/etc/nfqws2/nfqws2.conf` - это одна и та же метка. Если поменяете одно, поменяйте и другое.

### 2. Направьте нужные правила на NFQWS

В группах и правилах маршрутизации выберите outbound **NFQWS** для тех сервисов, которые должны идти в nfqws2, а не через обычный VPN.

### 3. Проверьте блок в nfqws2.conf

После установки в начале `/opt/etc/nfqws2/nfqws2.conf` должен появиться блок с пояснениями. По умолчанию там:

```sh
XKEEN_MARK_ONLY=1
XKEEN_ROUTE_MARK=0x10000000
XKEEN_ROUTE_MASK=0x10000000
```

Подробный разбор настроек mihomo: [docs-site/content/mihomo-setup.mdx](docs-site/content/mihomo-setup.mdx).

### 4. Рекомендация по режиму списков nfqws2

Раз mihomo уже решает, какой трафик отдавать в nfqws, повторная фильтрация по доменным спискам внутри nfqws2 часто не нужна и только грузит роутер. Имеет смысл выставить:

```sh
NFQWS_EXTRA_ARGS="$MODE_ALL"
```

Стратегии обхода (HTTP/HTTPS/QUIC) пакет не меняет - их вы настраиваете в nfqws2 как обычно.

---

## Команды

```sh
nfqws-xkeen              # интерактивное меню
nfqws-xkeen status       # патч, конфиг, процесс, iptables
nfqws-xkeen enable       # включить интеграцию
nfqws-xkeen disable      # временно выключить (XKEEN_MARK_ONLY=0)
nfqws-xkeen repatch      # после обновления nfqws2
nfqws-xkeen doctor       # быстрая проверка "всё ли на месте"
nfqws-xkeen check        # есть ли новая версия пакета на GitHub
nfqws-xkeen update       # обновить пакет
nfqws-xkeen uninstall    # снять патч и блок из conf
```

---

## После обновления nfqws2

Штатное обновление nfqws2 часто перезаписывает `/opt/etc/init.d/S51nfqws2` и снимает наш патч. Конфиг с блоком настроек обычно остаётся.

Сделайте:

```sh
nfqws-xkeen repatch
nfqws-xkeen doctor
```

Перед каждым патчем пишется бэкап в `/opt/var/lib/nfqws-xkeen/`.

---

## Удаление

```sh
nfqws-xkeen uninstall
```

Или:

```sh
curl -fsSL https://raw.githubusercontent.com/chebyrnet/nfqws-xkeen/main/uninstall.sh | sh
```

Бэкапы можно удалить отдельно:

```sh
rm -rf /opt/var/lib/nfqws-xkeen
```

---

## Документация для разработчиков сайта

```sh
cd docs-site
npm install
npm run dev          # локальный просмотр
npm run build        # статика в out/
npm run build:pages  # статика с basePath для GitHub Pages
```

Workflow `Deploy docs` выкладывает сайт на `https://chebyrnet.github.io/nfqws-xkeen/`. В настройках репозитория: Pages -> Source -> GitHub Actions.

---

## Лицензия

MIT, см. [LICENSE](LICENSE).

Обход DPI и сетевые настройки регулируются законодательством вашей страны. Используйте на свой страх и риск.
