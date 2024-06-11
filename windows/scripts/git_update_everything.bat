@echo off
setlocal
cd /d "%~dp0"
chcp 65001 > nul

where -q "fd.exe" || (
	echo.please, install "fd", https://github.com/sharkdp/fd
	exit /b 1
)

set GIT_SSH=C:\Windows\System32\OpenSSH\ssh.exe
set /p ssh=enter ssh: 
ssh-add "%userprofile%/.ssh/%ssh%"

@rem find hidden `.git` folders, echo parent directory, sort
for /f "tokens=*" %%a in ('fd "^.git$" -H --strip-cwd-prefix --exec cmd /c echo {//} ^| sort') do (
	echo.update "%%a"
	pushd %%a
	git pull
	popd
)

ssh-add -D
endlocal
