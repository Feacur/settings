@echo off
setlocal
cd /d "%~dp0"
chcp 65001 > nul

where -q "fd.exe" || (
	echo.please, install "fd", https://github.com/sharkdp/fd
	exit /b 1
)

@rem find hidden `.git` folders, echo parent directory, sort
for /f "tokens=*" %%a in ('fd "^.git$" -H --strip-cwd-prefix --exec cmd /c echo {//} ^| sort') do (
	echo.update "%%a"
	pushd %%a
	git pull
	popd
)

endlocal
