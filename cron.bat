@echo off
cd C:\projekte\meinetaskapp
C:\laragon\bin\php\php-8.3.36-Win32-vs16-x64\php.exe artisan schedule:run >> storage\logs\cron.log 2>&1