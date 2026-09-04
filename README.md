# Успевай

Текущая версия: **8.0.0 (29)** — сетевые друзья, публичная аналитика профиля, экономика монет и маркетплейс со 150 косметическими наградами.

Приложение для iPhone: расписание, разовые замены учебных дней, домашние задания, импорт фото, оценки, профиль, учебный огонёк и 130 достижений четырёх уровней редкости.

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

Каждый новый релиз должен получать новые `MARKETING_VERSION` и `CURRENT_PROJECT_VERSION` в `project.yml`. Номер меняется в настройках проекта до сборки, поэтому Xcode не пытается перезаписывать `Info.plist` во время работы.

## Сторонние материалы

Шрифт Monocraft создан IdreesInc, распространяется по SIL Open Font License 1.1 и не связан с Mojang или Minecraft. Полный текст лицензии находится в `Uspevai/Fonts/OFL.txt`.

Без Apple Secrets Action создаёт `Uspevai-unsigned.ipa`. Такой IPA необходимо подписать своим Apple ID через AltStore или Sideloadly. При наличии Apple Secrets дополнительно создаётся подписанный `Uspevai.ipa`.
