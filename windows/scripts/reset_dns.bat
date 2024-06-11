@echo off
setlocal
cd /d "%~dp0"
chcp 65001 > nul

Netsh winsock reset
Netsh int ip reset
ipconfig /release
ipconfig /renew
ipconfig /flushdns

endlocal
