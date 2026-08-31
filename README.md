# Успевай

Минималистичное приложение для iPhone: расписание, домашние задания, импорт фото и напоминания после уроков.

## Запуск

1. На Mac установите Xcode и XcodeGen (`brew install xcodegen`).
2. Выполните `xcodegen generate` и откройте `Uspevai.xcodeproj`.
3. В Signing & Capabilities выберите свою Apple Developer Team и уникальный Bundle Identifier.
4. Подключите iPhone и нажмите Run.

## IPA через GitHub

Добавьте Secrets: `APPLE_CERTIFICATE_BASE64`, `APPLE_CERTIFICATE_PASSWORD`, `APPLE_PROVISION_PROFILE_BASE64`, `KEYCHAIN_PASSWORD`. Создайте тег вида `v1.0.1` или запустите workflow вручную. Готовый IPA появится в Artifacts.

Каждый новый релиз должен получать новый `MARKETING_VERSION` в `project.yml`; номер Release-сборки повышается автоматически.
