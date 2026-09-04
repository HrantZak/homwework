# Бесплатная настройка сообщества Успевай

Firebase работает на серверах Google. Компьютер и NAS после настройки можно выключать.

## 1. Создайте проект

1. Откройте [Firebase Console](https://console.firebase.google.com/).
2. Нажмите **Create a project / Создать проект**.
3. Назовите проект `Uspevai`.
4. Google Analytics можно отключить — для сообщества он не нужен.
5. Нажмите **Create project**.

## 2. Добавьте iOS-приложение

1. На главной странице проекта нажмите значок **iOS+**.
2. В поле Bundle ID укажите `am.hrant.uspevai`.
3. В поле App nickname укажите `Uspevai`.
4. App Store ID оставьте пустым.
5. Нажмите **Register app**.
6. Скачайте `GoogleService-Info.plist`.
7. Положите файл сюда: `Uspevai/GoogleService-Info.plist`.

Остальные шаги установки SDK в Firebase Console можно пропустить: зависимости и запуск Firebase уже добавлены в код.

## 3. Включите анонимный вход

1. Слева откройте **Build → Authentication**.
2. Нажмите **Get started**.
3. Откройте вкладку **Sign-in method**.
4. Выберите **Anonymous**.
5. Включите переключатель **Enable** и нажмите **Save**.

## 4. Создайте Firestore

1. Слева откройте **Build → Firestore Database**.
2. Нажмите **Create database**.
3. Выберите **Production mode**.
4. Выберите ближайший регион и нажмите **Enable**.

## 5. Установите безопасные правила

1. В Firestore откройте вкладку **Rules**.
2. Полностью замените содержимое текстом из файла `firestore.rules`.
3. Нажмите **Publish**.

Правила позволяют читать открытые профили, а изменять профиль может только его владелец.

## 6. Соберите IPA

1. Отправьте изменения и `GoogleService-Info.plist` в GitHub.
2. Откройте **Actions → Build Uspevai IPA → Run workflow**.
3. Скачайте IPA из **Artifacts**.

## Проверка

На двух iPhone откройте **Профиль → Сообщество Успевай**, опубликуйте профили и добавьте друг друга по восьмизначному коду.
