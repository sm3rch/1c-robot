@echo off
setlocal enabledelayedexpansion

REM echo runproc; | find "%~1" 1>nul 2>nul && (
	REM set _tmp=%~1
	REM set !_tmp:-=!=%~2
REM ) || (
	
REM )


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

	set RDATE=!date:~-4!.!date:~3,2!.!date:~0,2!

	call :roll_proc IBUOT:CBIT_UC_CONF IBIN:TEST_CBIT BASEFILE:Z:\CBIT_UC_CONF_%RDATE%.dt
	call :roll_proc IBUOT:CEBIT_2011_2012 IBIN:TEST_CEBIT BASEFILE:Z:\CBIT_2011_2012_%RDATE%.dt
	rem call :roll_files
exit /b %ERRORLEVEL%

:roll_proc

	setlocal
	call :arg_parser IBOUT:IBIN:BASEFILE
	call :kick_users ICBASE:%IBOUT%
	call :dump_base ICBASE:%IBOUT% BASEFILE:"%BASEFILE%"
	call :kick_users ICBASE:%IBIN%
	call :restore_base ICBASE:%IBIN% BASEFILE:"%BASEFILE%"
exit /b %ERRORLEVEL%

:dump_base

	setlocal
	call :arg_parser ICBASE:BASEFILE %*
	set CMDLINE=designer /s%ICSRV%\%ICBASE% /n%ICUSR% /p%ICPASS% /DisableStartupMessages /DumpIB ""%BASEFILE%""
	call :roll_base CMDLINE:"%CMDLINE%"
exit /b %ERRORLEVEL%

:restore_base

	setlocal
	call :arg_parser ICBASE:BASEFILE %*
	set CMDLINE=designer /s%ICSRV%\%ICBASE% /n%ICUSR% /p%ICPASS% /DisableStartupMessages /RestoreIB ""%BASEFILE%""
	call :roll_base CMDLINE:"%CMDLINE%"
exit /b %ERRORLEVEL%

:roll_base

	setlocal
	call :arg_parser CMDLINE %*
	for /f "" %%i in ('call :start_proc exec:"%ICEXE%" cmdline:"%CMDLINE%"') do set PID=%%i
	if "%PID%" NEQ "" call :wait_for_pid %PID%
exit /b %ERRORLEVEL%

:wait_for_pid

	ping -n 5 -w 1000 127.0.0.1 >nul
	for /f "tokens=1 delims=. " %%i in ('tasklist /nh /fi "PID eq %1"') do (
		if "%%i" NEQ "" call :wait_for_pid %1
	)
exit /b

:start_proc

	setlocal
	call :argParser exec:cmdline:workdir:host:user:pass:record %*

	if "%exec:"=%" EQU "" (
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

	for /f "usebackq tokens=*" %%G IN (`wmic  %global_params%  process call create "%exec% %cmdline%"^,"%workdir%"`) do ( 
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
			set %%i=%%~j
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