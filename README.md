# Успевай

Текущая версия: **6.1.0 (16)** — умный экран дня, прогресс уроков и удобная работа с заданиями.

Минималистичное приложение для iPhone: расписание, домашние задания, импорт фото и напоминания после уроков.

## Запуск

1. На Mac установите Xcode и XcodeGen (`brew install xcodegen`).
2. Выполните `xcodegen generate` и откройте `Uspevai.xcodeproj`.
3. В Signing & Capabilities выберите свою Apple Developer Team и уникальный Bundle Identifier.
4. Подключите iPhone и нажмите Run.

## IPA через GitHub

Добавьте Secrets: `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`. Создайте тег вида `v6.1.0` или запустите workflow вручную. Готовый IPA появится в Artifacts. Обычный push в `main` не запускает дорогую macOS-сборку — это бережёт бесплатные минуты GitHub Actions.

На Windows содержимое файлов для Secrets можно получить в PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\certificate.p12")) | Set-Clipboard
[Convert]::ToBase64String([IO.File]::ReadAllBytes("C:\path\profile.mobileprovision")) | Set-Clipboard
```

Первая команда копирует сертификат, вторая — provisioning profile. В Secret нужно вставлять результат команды целиком, без кавычек и имени файла.

Каждый новый релиз должен получать новый `MARKETING_VERSION` в `project.yml`; номер Release-сборки повышается автоматически.

Без Apple Secrets Action создаёт `Uspevai-unsigned.ipa`. Такой IPA необходимо подписать своим Apple ID через AltStore или Sideloadly. При наличии Apple Secrets дополнительно создаётся подписанный `Uspevai.ipa`.
