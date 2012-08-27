@echo off

if "%init%" EQU "done" goto :init_done
setlocal disabledelayedexpansion
if exist "%~1" (
	rem Загружаем параметры обмена
	for /f "usebackq eol=; delims== tokens=1,*" %%i in ("%~dpnx1") do (
		set %%i=%%~j
	)
)
	rem Применяем глобальные параметры
for /f "delims=<[]" %%i in ('find /n "<SettingsBlock>" "%~dpnx0" ^| find "<SettingsBlock>"') do set /a SKIP=%%i
for /f "usebackq skip=%SKIP% eol=; delims== tokens=1,*" %%i in ("%~dpnx0") do (
	if not defined %%i set %%i=%%~j
)
if not defined LDATE set LDATE=!date!
if not defined LTIME set LTIME=!time!
set init=done
:init_done
setlocal enabledelayedexpansion
if not defined LOG (
	set LOGFILE=con
) else (
	call :gen_file_name LOGFILE
)
echo dump_base;restore_base;kick_users;start_proc | find "%~1" 1>nul 2>nul ^
	&& (call :call_proc %*) ^
	|| (call :run_proc)
exit /b %ERRORLEVEL%

:call_proc

	set proc=%1
	set cmdline=%*
	set cmdline=!cmdline:%proc%=!
	call :%proc% %cmdline%
exit /b %ERRORLEVEL%

:run_proc

	setlocal
	call :arg_parser IBOUT:IBIN:BASEFILE
	call :kick_users ICBASE:%IBOUT%
	call :dump_base ICBASE:%IBOUT% BASEFILE:%BASEFILE%
	call :kick_users ICBASE:%IBIN%
	call :restore_base ICBASE:%IBIN% BASEFILE:%BASEFILE%
	rem call :roll_files
exit /b %ERRORLEVEL%

:dump_base

	call :roll_base MODE:DumpIB %*
exit /b %ERRORLEVEL%

:restore_base

	call :roll_base MODE:RestoreIB %*
exit /b %ERRORLEVEL%

:roll_base

	setlocal
	call :arg_parser ICBASE:BASEFILE:MODE %*
	set BASEFILE=%BASEFILE:"=""%
	set CMDLINE=designer /s%ICSERVER%\%ICBASE% /n%ICUSER% /p%ICPASS% /DisableStartupMessages /%MODE% %BASEFILE%
	rem for /f "tokens=*" %%i in ('call %~nx0 start_proc exec:"%ICEXE%" cmdline:"%CMDLINE%" ^2^>nul ^|findstr /r .') do echo:%%i
	for /f %%i in ('call %~nx0 start_proc exec:"%ICEXE%" cmdline:"%CMDLINE%" ^2^>nul ^|findstr /r ^^[0-9]^$') do set PID=%%i
	if "%PID%" NEQ "" call :wait_for_pid %PID%
exit /b %ERRORLEVEL%

:wait_for_pid

	ping -n 5 -w 1000 127.0.0.1 >nul
	for /f %%i in ('tasklist /nh /fi "PID eq %1" ^| find "%1" ^>nul ^&^& echo:one ^|^| echo:none') do (
		if "%%i" NEQ "none" call :wait_for_pid %1
	)
exit /b

:start_proc

	setlocal
	call :arg_parser exec:cmdline:workdir:host:user:pass:record %*

	if "%exec%" EQU "" (
		call :err 1000
		exit /b %ERRORLEVEL%
	)

	if "%host%" NEQ "" (
		set host=/NODE:%host%
		if "%user%" NEQ "" (
			set user=/USER:%user%
			if "%pass%" NEQ "" (
				set pass=/PASSWORD:%pass%
			)
		)
	)

	if "%record%" NEQ "" (
		set record=/RECORD:%record%
	)

	set global_params=%record% %host% %user% %pass%

	for /f "tokens=*" %%G IN ('wmic  %global_params%  process call create "%exec% %cmdline%"^,"%workdir%"') do ( 
		rem echo %%G
		set _tmp=%%G
		set _tmp=!_tmp:^>=^^^>!
		echo !_tmp! | find "ProcessId" > nul && (
			for /f  "tokens=2 delims=;= " %%H in ('echo !_tmp!') do (
				call set /A PID=%%H
			)
		)
		echo !_tmp! | find "ReturnValue" > nul && (
			for /f  "tokens=2 delims=;= " %%I in ('echo !_tmp!') do (
				call set /A RETCOD=%%I
			)
		)
		rem call :concat
	)
	set _tmp=
	
	rem successful execution
	if "%PID%" NEQ "" (
		echo %PID%
		exit /b
		rem exit /B %PID%
	) else (
		call :err %RETCOD%
	)

exit /b %ERRORLEVEL%

:kick_users

	setlocal
	call :arg_parser ICBASE %*
	call :gen_file_name VBSFILE
	set VBSLOG=%VBSFILE:VBS=LOG%
	call :gen_vbs001_file filename:%VBSFILE% ICUSER:%ICUSER% ICPASS:%ICPASS% ICSERVER:%ICSERVER% ICBASE:%ICBASE%
	cscript %VBSFILE% //nologo 2>%VBSLOG%
	for /f "" %%i in (%VBSLOG%) do (
		rem Вставить обработку ошибок
		rem if "%%~zi" NEQ "0" ()
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
	rem echo:%~1 %~2
	for /f "tokens=1,* delims=:" %%i in ('echo:%~1') do (
		echo %comstr% | find "%%i" > nul && (
			set %%i=%%~j
		)
	)
	shift
	for /f %%i in ('echo:%1^|findstr /r . ^>nul ^&^& echo:full^|^| echo:empty') do (
		if "%%i" NEQ "empty" goto :nextShift
	)
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
		call :escapes _tmp
		for /f "tokens=*" %%j in ('echo:!_tmp!') do echo:%%j>>%filename%
		set /a count=count-1
	)
	:gen_file_end
exit /b %ERORLEVEL%

:escapes

	set %1=!%1:^<=^^^<!
	set %1=!%1:^>=^^^>!
	set %1=!%1:^&=^^^&!
	set %1=!%1:^(=^^^(!
	set %1=!%1:^)=^^^)!
exit /b

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
BASEDATE=!date:~-4!.!date:~3,2!.!date:~0,2!
BASEFILE=!PATH2ARC!!IBOUT!_!BASEDATE!.dt
PRIORITY=NORMAL
ICUSER=robot
ICPASS=p@ssw0rd
ICSERVER=server
ICEXE=C:\Program Files (x86)\1cv82\8.2.15.289\bin\1cv8.exe
