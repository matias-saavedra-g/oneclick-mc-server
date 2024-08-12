@REM ---------------------------- Console ----------------------------
::: Script to start the Minecraft server
:: Creates a new window with the title "Pitufialdea"
@echo off
title MT Server
color 3f
@REM ---------------------------- Console ----------------------------

@REM ---------------------------- Update ----------------------------
::: Updates the server to the latest version
:: The folder directory is the current directory
set folder_directory=%cd%

:: Checks if server.jar exists
if not exist "server.jar" goto :download

::: Outputs the latest server version from the Mojang website
:: The latest server version is saved in the version.txt file
powershell -Command "(Invoke-RestMethod -Uri 'https://launchermeta.mojang.com/mc/game/version_manifest.json').latest.release" > version.txt

:: The server version is saved in the server_version variable
set /p server_version=<version.txt

:: The version.txt file is deleted
del version.txt

:: Separator
echo ------------------------------

:: The server version is displayed in the console
echo Latest server version: %server_version%

:: Tells the current version from the folder's name folder_directory\versions\{folder name}
:: Only outputs {folder name}
for /d %%a in ("%folder_directory%\versions\*") do set current_version=%%~nxa

:: The current version is displayed in the console
echo Current server version: %current_version%

:: Asks the user if they want to upgrade the server
choice /C:yn /T:9999 /D:y /M "Upgrade server?"
if errorlevel 2 goto :start

:: Removes the old server.jar file
del "server.jar"

:: Downloads the new server.jar file from the Mojang website
:: Edit if deprecated
:download
curl "https://piston-data.mojang.com/v1/objects/59353fb40c36d304f2035d51e7d6e6baa98dc05c/server.jar" --output server.jar
@REM ---------------------------- Update ----------------------------

@REM ---------------------------- Backup ----------------------------
::: Script that creates a backup of the world folder using 7zip
:: Checks if %folder_directory%\world exists
if not exist "%folder_directory%\world" goto :start

:: The backup is saved in the backup folder with the current date and time as the file name
for /f "delims=" %%a in ('wmic OS Get localdatetime  ^| find "."') do set dt=%%a 

:: The date and time are saved in the YYYY, MM, DD, HH, Min, and Sec variables
set YYYY=%dt:~0,4%
set MM=%dt:~4,2%
set DD=%dt:~6,2%
set HH=%dt:~8,2%
set Min=%dt:~10,2%
set Sec=%dt:~12,2%

:: The stamp is the current date and time in the format HH-Min-Sec_DD-MM-YYYY
set stamp=%HH%-%Min%-%Sec%_%DD%-%MM%-%YYYY%

:: Creates a backup of the world folder using 7zip
7zG.exe a "%folder_directory%\backup\world_%stamp%.zip" "%folder_directory%\world"

:: Separator
echo ------------------------------
:: Tells the user the backup is complete
echo Backup complete
@REM ---------------------------- Backup ----------------------------

@REM ---------------------------- Start ----------------------------
::: Script to start the Minecraft server
:start
:: Separator
echo ------------------------------
:: Starts the Minecraft server
java -Xms6G -Xmx6G -XX:+UseG1GC -jar server.jar nogui
@REM ---------------------------- Start ----------------------------

@REM ---------------------------- Restart ----------------------------
::: Script to restart the Minecraft server
:restart
:: Separator
echo ------------------------------
:: Asks the user if they want to restart the server
choice /C:yn /T:9999 /D:y /M "Restart server?"
if errorlevel 2 goto :exit

:: Restarts the server
goto :start
@REM ---------------------------- Restart ----------------------------

@REM ---------------------------- Exit ----------------------------
::: Script to exit the Minecraft server
:exit
:: Separator
echo ------------------------------
:: Tells the user the server is exiting
echo Exiting server...
timeout /T 2

:: Exits the server
exit
```
@REM ---------------------------- Exit ----------------------------