@echo off
setlocal
cd /d "%~dp0"
chcp 65001 > nul

net stop NVDisplay.ContainerLocalSystem
net start NVDisplay.ContainerLocalSystem

endlocal
