@echo off
setlocal enabledelayedexpansion

echo runproc; | find "%~1" 1>nul 2>nul && (
	set _tmp=%~1
	set !_tmp:-=!=%~2
) || (
	
)


call :runproc
exit /b %ERRORLEVEL%

:runproc

	if "%init%" NEQ "" (goto :initdone)
	setlocal disabledelayedexpansion
	rem Загружаем параметры обмена
	REM for /f "usebackq eol=; delims== tokens=1,*" %%i in ("%~dpnx1") do (
		REM set %%i=%%~j
	REM )
	rem Применяем глобальные параметры
	for /f "delims=<[]" %%i in ('find /n "<SettingsBlock>" "%~dpnx0" ^| find "<SettingsBlock>"') do set /a SKIP=%%i
	for /f "usebackq skip=%SKIP% eol=; delims== tokens=1,*" %%i in ("%~dpnx0") do (
		if not defined %%i set %%i=%%~j
	)
	if not defined LDATE set LDATE=!date!
	if not defined LTIME set LTIME=!time!
	setlocal enabledelayedexpansion
	if not defined LOG (
		set LOGFILE=con
	) else (
		call :gen_file_name LOGFILE
	)













exit /b %ERRORLEVEL%

	set RDATE=!date:~-4!.!date:~3,2!.!date:~0,2!


:dump_base

	setlocal
	call :arg_parser ICBASE:BASEFILE %*
	set CMDLINE=designer /s%ICSRV%\%ICBASE% /n%ICUSR% /p%ICPASS% /DisableStartupMessages /DumpIB ""%BASEFILE%""
	call :run_prog prog:"%ICEXE%" cmdline:"%CMDLINE%" || call :err
exit /b %ERRORLEVEL%

:restore_base

	setlocal
	call :arg_parser ICBASE:BASEFILE %*
	set CMDLINE=designer /s%ICSRV%\%ICBASE% /n%ICUSR% /p%ICPASS% /DisableStartupMessages /RestoreIB ""%BASEFILE%""
	call :run_prog prog:"%ICEXE%" cmdline:"%CMDLINE%" || call :err
exit /b %ERRORLEVEL%

:kick_users

	setlocal
	call :arg_parser ICBASE %*
	call :gen_file_name VBSFILE
	set VBSLOG=%VBSFILE:VBS=LOG%
	call :gen_vbs001_file filemane:%VBSFILE% ICUSER:%ICUSER% ICPASS:%ICPASS% ICSERVER:%ICSERVER% ICBASE:%ICBASE%
	cscript %VBSFILE% //nologo 2>%VBSLOG%
	for /f "tokens=4 delims=[] " %%i in ('dir intlname.ols ^| find /n /v "" ^| find "[7]"') do (
		rem Вставить обработку ошибок
		if "%%i" NEQ "0" ()
	)
	del /q /f %VBSLOG%
	del /q /f %VBSFILE%
exit /b %ERRORLEVEL%

:gen_file_name

	set _tmp=%1
	set %1=%LDATE%%LTIME%
	set %1=!%1::=!
	set %1=!%1:.=!
	set %1=!%1: =!
	set %1=!%1:,=!.!_tmp:file=!
	set _tmp=
exit /b

:arg_parser

	set comstr=%~1
	shift
	:nextShift
	echo:%~1 %~2
	for /f "tokens=1,* delims=:" %%i in ("%~1") do (
		echo %comstr% | find "%%i" > nul && (
			set %%i=%%j
		)
	)
	shift
	if "%~1" NEQ "" goto :nextShift
exit /b

:gen_file

	setlocal
	call :arg_parser find:filename %*
	rem:>%filename%
	for /f "delims=<[]" %%i in ('find /n "<%find%>" "%~dpnx0" ^| find "<%find%>"') do set /a BBEG=%%i
	for /f "delims=<[]" %%i in ('find /n "</%find%>" "%~dpnx0" ^| find "</%find%>"') do set /a BEND=%%i
	set /a count=BEND-BBEG-3
	for /f "usebackq skip=%BBEG% tokens=*" %%i in ("%~dpnx0") do (
		if !count! LEQ 0 goto :gen_file_end
		set _tmp=%%i
		set _tmp=!_tmp:^<=^^^<!
		set _tmp=!_tmp:^>=^^^>!
		set _tmp=!_tmp:^&=^^^&!
		for /f "tokens=*" %%j in ('echo:!_tmp!') do echo:%%j>>%filename%
		set /a count=count-1
	)
	:gen_file_end
exit /b %ERORLEVEL%

:gen_vbs001_file

	setlocal
	call :arg_parser filename:ICUSER:ICPASS:ICSERVER:ICBASE %*
	call :gen_file find:vbs001 
exit /b %ERORLEVEL%

:err

exit /b %ERORLEVEL%

<vbs001>
Dim Connector
Dim AgentConnection
Dim Cluster
Dim WorkingProcess
Dim WorkingProcessConnection
Dim ibDesc
Dim connections
Dim ConnectString

Set Connector = CreateObject("V82.COMConnector")
Set AgentConnection = Connector.ConnectAgent("%ICSERVER%")
Set Cluster = AgentConnection.GetClusters()(0)
AgentConnection.Authenticate Cluster, "", ""
Set WorkingProcess = AgentConnection.GetWorkingProcesses(Cluster)(0)
ConnectString = WorkingProcess.HostName & ":" & WorkingProcess.MainPort
Set WorkingProcessConnection = Connector.ConnectWorkingProcess(ConnectString)
WorkingProcessConnection.AddAuthentication "%ICUSER%", "%ICPASS%"
Set ibDesc = WorkingProcessConnection.CreateInfoBaseInfo()
ibDesc.Name = "%ICBASE%"
connections = WorkingProcessConnection.GetInfoBaseConnections(ibDesc)

Dim i
Dim Connection
For i = LBound(connections) To UBound(connections)
	Set Connection = connections(i)
	If (Connection.AppID <> "COMConsole") Then
		WorkingProcessConnection.Disconnect Connection
	End If
Next
</vbs001>

<SettingsBlock>
;******************************************************************************************
; Глобальные настройки робота. !Внимание! кодировка должна быть 866
;******************************************************************************************
LDATE=!date:~-4!!date:~3,2!!date:~0,2!
LTIME=!time: =0!
PRIORITY=NORMAL
ICUSER=robot
ICPASS=p@ssw0rd
ICSERVER=server
ICEXE=C:\Program Files\1cv82\common\1cestart.exe