# Recovery — что делать, если вернулся MDM

Нужен только Wi-Fi в Recovery и одна команда. Флешка не обязательна.

## Стабильная ссылка (всегда последний релиз)

```
https://github.com/rodion-gudz/unleash/releases/latest/download/unleash-standalone.sh
```

Этот URL не меняется при выходе новых версий — можно перепечатывать его с телефона в любой момент.

## 1. Загрузиться в Recovery

- **Apple Silicon:** выключить Mac → зажать кнопку питания до «Loading startup options» → **Options** → Continue
- FileVault выключен → пароль не спросят.
  Если включён: сначала разблокировать том — `diskutil apfs unlockVolume disk3s1`
- Меню сверху: **Utilities → Terminal**
- Интернет: значок Wi-Fi в правом верхнем углу → подключиться к сети

## 2. Скачать и запустить

```bash
curl -L https://github.com/rodion-gudz/unleash/releases/latest/download/unleash-standalone.sh -o /tmp/u
bash /tmp/u suppress
```

- `suppress` — подавить enrollment, **без создания пользователя** (обычный случай)
- `bash /tmp/u bypass` — полный bypass с временным админом `Apple` / `1234` (если вылез экран Remote Management при установке/после вайпа)
- `bash /tmp/u heal` — просто проверить и до-применить

## 3. Перезагрузиться

```bash
reboot
```

## 4. После входа

```bash
/usr/bin/profiles status -type enrollment      # ждём: MDM enrollment: No
tail -5 /var/log/unleash-heal.log              # автолечение уже отработало
```

Автолечение (LaunchDaemon `com.unleash.heal`) уже установлено — при каждой загрузке
и раз в сутки блок возвращается сам. Ничего больше делать не нужно.

## Если интернета в Recovery нет

Варианты: телефон в режиме модема (подключить Mac к нему по Wi-Fi) или флешка с
`unleash-standalone.sh`, скачанным заранее. Других способов нет — Recovery на Apple
Silicon подписан и файлы внутрь него не положить.
