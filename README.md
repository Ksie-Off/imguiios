# imgui iOS demo

Standalone iOS-приложение с интерфейсом на ImGui (рендер через Metal). Собирается в обычный `.ipa` на GitHub Actions и ставится через Sideloadly — **без джейлбрейка**.

Внутри: ImGui 1.90.9 + `imgui_impl_metal`, сенсорное управление, демо-меню и демо-отрисовка фигур.

## Ограничение iOS

Рисовать поверх **других** приложений без джейлбрейка/TrollStore нельзя — это ограничение песочницы iOS, а не кода. Здесь ImGui-интерфейс работает внутри собственного окна приложения: меню, чекбокс, FPS и демо-фигуры на фоне. Для полноэкранного оверлея поверх игр нужен TrollStore или джейлбрейк.

## Что нужно

- Аккаунт GitHub
- Windows + [Git](https://git-scm.com/download/win)
- Sideloadly + Apple ID (бесплатного достаточно)
- iPhone на iOS 14.0+

## 1. Залить на GitHub

Создайте на github.com **пустой** репозиторий (без README и лицензии), затем в PowerShell:

```powershell
cd C:\Users\Ksie\Desktop\53
git init
git add .
git commit -m "imgui ios demo"
git branch -M main
git remote add origin https://github.com/Ksie-Off/imguiios.git
git push -u origin main
```

Папка `1` (старый HUD-проект) исключена в `.gitignore` и в репозиторий не попадёт.

## 2. Собрать `.ipa`

1. Откройте репозиторий на GitHub → вкладка **Actions**.
2. Слева выберите **Build** → **Run workflow** (или просто сделайте push — сборка стартует сама).
3. Дождитесь зелёной галочки (5–10 минут; macOS-раннер GitHub бесплатный).
4. Откройте завершённый запуск → внизу **Artifacts** → скачайте **imgui-ipa**.
5. Распакуйте архив — внутри готовый `imgui.ipa`.

## 3. Установить через Sideloadly

1. Подключите iPhone, откройте Sideloadly.
2. Перетащите `imgui.ipa` в окно, введите Apple ID, нажмите **Start**.
3. На iPhone: **Настройки → Основные → VPN и управление устройством** → доверьтесь профилю разработчика.

Бесплатный Apple ID: сертификат на 7 дней, до 3 приложений. После истечения просто подпишите заново.

## Пересборка

После правок в `sources/` сделайте `git push` — Actions соберёт новый `imgui.ipa`. Готовые сборки: **Actions → запуск → Artifacts**.

## Структура

- `sources/main.mm`, `AppDelegate.*` — точка входа и окно
- `sources/ImGuiViewController.*` — Metal-вью, ввод с тача, меню ImGui
- `sources/imgui/` — ImGui + Metal backend
- `Makefile` — сборка через Theos, на выходе `packages/imgui.ipa`
- `.github/workflows/build.yml` — CI-сборка на macOS
