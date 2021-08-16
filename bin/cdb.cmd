@echo off

if exist "%~dp0nwjs\nw.exe" (
	if exist "%~dp0castle.js" (
		start /D %~dp0 nwjs\nw.exe --nwapp package.json %*
	) else (
		echo.
		echo Missing "castle.js".
		pause
	)
) else (
	echo.
	echo This requires "nw.exe" in ./nwjs/ folder.
	echo Get it on: https://nwjs.io/
	pause
)