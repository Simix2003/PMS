TO START THE VIRTUAL ENVIRONMENT OF Python 3.11.2 use:
PS D:\Imix\Lavori\2025\3SUN\IX-Monitor\ix_monitor>                     
>> # Activate it
>> & "service/venv/Scripts/Activate.ps1"
pyinstaller --clean service.spec


flutter build web --web-renderer html

# Build for port 8050 (HomePage only)
flutter build web --web-renderer html --release -t lib/main_home.dart -o build/web_home

# Build for port 8051 (DataView + OverlayEditor)
flutter build web --web-renderer html --release -t lib/main_data.dart -o build/web_data

# Build for port 8052 (Stringatrici)
flutter build web --web-renderer html --release -t lib/main_stringatrici.dart -o build/web_stringatrici

# Build for port 8053 (Visual)
flutter build web --web-renderer html --release -t lib/main_visual.dart -o build/web_visual

flutter run -d chrome --web-renderer html -t lib/main_home.dart
flutter run -d chrome --web-renderer html -t lib/main_data.dart
flutter run -d chrome --web-renderer html -t lib/main_stringatrici.dart
flutter run -d chrome --web-renderer html -t lib/main_visual.dart


pyinstaller --onefile --add-binary="C:\Users\papar\Desktop\Prova_Comunicazione_PLC\Lib\site-packages\snap7\lib\snap7.dll;." service.py  

cd service
pyinstaller --clean service.spec

Per installare MySQL se esce errore 13, bisogna andare sotto C/Users e nella cartella "Default" asegnare ad "EVERYONE" tutti i permessi per la cartella.

Se si vuole aggiungere la password al server mysql:
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Master36!';
FLUSH PRIVILEGES;

Per Resettare l'Auto Increment:
ALTER TABLE your_table_name AUTO_INCREMENT = 1;

Per HTTPS:
Aprire Git Bash
Scrivere : 
$ openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout key.pem -out cert.pem

In modo da creare i due certificati necessari per HTTPS.

i file saranno sotto : C:\Users\papar

Bisogna spostarli sotto : C:\IX-Monitor\ssl

OS: Windows ( In modo da avere possibilità di far girare EXE o Container Linux)
CPU: 8 vCPU o superiore
RAM: 16 GB o superiore
SSD: 256 GB o superiore ( DATABASE MYSQL IN LOCALE OPPURE NOOO???)
IP statico + porte aperte 8001 e 8050–>8055