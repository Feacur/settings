@echo off
setlocal
cd /d "%~dp0"
chcp 65001 > nul

rem @note: it's a lightweight and incomplete version of the "setup" target from the "Makefile"
rem shall fail at some point, for the tools code should be compiled first
rem besides, I only need headers, not binary resuorces to explore the code

set VERSION=gc-eu-mq-dbg
set BASEROM_DIR=baseroms/%VERSION%
set EXTRACTED_DIR=extracted/%VERSION%
set N_THREADS=16

if not exist "%BASEROM_DIR%/baserom.z64" (
	echo.put a matching ROM into the "%BASEROM_DIR%" folder
	exit /b 1
)

echo.[clean up]
rmdir /s /q %EXTRACTED_DIR%

echo.[install requirements]
pip -q install -r requirements.txt || exit /b 1

echo.[decompress baserom]
python tools/decompress_baserom.py %VERSION% || exit /b 1

echo.[extract baserom]
python tools/extract_baserom.py %BASEROM_DIR%/baserom-decompressed.z64 %EXTRACTED_DIR%/baserom -v %VERSION% || exit /b 1

echo.[extract incbins]
python tools/extract_incbins.py %EXTRACTED_DIR%/baserom %EXTRACTED_DIR%/incbin -v %VERSION% || exit /b 1

echo.[msgdis]
python tools/msgdis.py %EXTRACTED_DIR%/baserom %EXTRACTED_DIR%/text -v %VERSION% || exit /b 1

echo.[extract assets]
set TOOLS_ZAPD_DIR=tools/ZAPD
if not exist "%TOOLS_ZAPD_DIR%/ZAPD.exe" (
	echo.build "%TOOLS_ZAPD_DIR%/ZAPD.sln"; it seems only Debug configuration compiles
	echo.copy the "%TOOLS_ZAPD_DIR%/x64/Debug/ZAPD.exe" into the "%TOOLS_ZAPD_DIR%" directory
	echo.modify "extract_assets.py" so that it calls "ZAPD" instead of "ZAPD.out"
	exit /b 1
)
python extract_assets.py %EXTRACTED_DIR%/baserom %EXTRACTED_DIR%/assets -v %VERSION% -j%N_THREADS% || exit /b 1

echo.[extract audio]
set TOOL_AUDIO_DIR=tools/audio
if not exist "%ZAPD_DIR%/sampleconv/sampleconv.exe" (
	echo.need to properly build tools first
	exit /b 1
)
python tools/audio_extraction.py -o %EXTRACTED_DIR% -v %VERSION% --read-xml || exit /b 1

endlocal
