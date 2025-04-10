TO START THE VIRTUAL ENVIRONMENT OF Python 3.11.2 use:
- cd services
- venv\Scripts\activate

flutter build web --web-renderer html

# Build for port 8080 (HomePage only)
flutter build web --web-renderer html --release -t lib/main_home.dart -o build/web_home

# Build for port 8081 (DataView + OverlayEditor)
flutter build web --web-renderer html --release -t lib/main_data.dart -o build/web_data

flutter run -d chrome --web-renderer html -t lib/main_home.dart
flutter run -d chrome --web-renderer html -t lib/main_data.dart


pyinstaller --onefile --add-binary="C:\Users\papar\Desktop\Prova_Comunicazione_PLC\Lib\site-packages\snap7\lib\snap7.dll;." service.py  

cd services
cd api
pyinstaller --clean service.spec