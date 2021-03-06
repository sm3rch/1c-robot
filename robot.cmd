@echo off

for /f "tokens=4" %%i in ('chcp') do set CODEPAGE=%%i
chcp 1251>nul

if "%init%" EQU "done" goto :init_done
setlocal disabledelayedexpansion
if exist "%~1" (
	rem ��������� ��������� ������
	for /f "usebackq eol=; delims== tokens=1,*" %%i in ("%~dpnx1") do (
		set %%i=%%~j
	)
)
	REM rem ��������� ���������� ���������
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
for /f "tokens=*" %%i in ('echo:change_system_header:dump_base;restore_base;kick_users;restore_normal_mode;start_proc ^| find "%~1" 1^>nul 2^>nul ^&^& echo:call_proc %*^|^|echo:run_proc') do (call :%%i)
set ERRORNUMBER=%ERRORLEVEL%
chcp %CODEPAGE%>nul
exit /b %ERRORNUMBER%

:call_proc

	set proc=%1
	set cmds=%*
	set cmds=!cmds:%proc%=!
	call :%proc% %cmds%
exit /b %ERRORLEVEL%

:run_proc

	setlocal
	call :arg_parser IBOUT:IBIN:BASEFILE %*
	call :dump_base ICBASE:%IBOUT% BASEFILE:%BASEFILE% || goto :run_proc_end
	call :restore_base ICBASE:%IBIN% BASEFILE:%BASEFILE%
	call :roll_files BASEFILE:%BASEFILE% PATH2ARC:%PATH2ARC%
	:run_proc_end
exit /b %ERRORLEVEL%

:roll_files

	setlocal
	call :arg_parser BASEFILE:PATH2ARC %*
	if exist "%BASEFILE%" ( 
		xcopy /y "%BASEFILE%" "%PATH2ARC%" >nul && del /q /f "%BASEFILE%"
	)
exit /b %ERRORLEVEL%

:dump_base

	call :kick_users %*
	REM :dump_base_again
	REM set /a cnt=1+cnt
	REM call :roll_base MODE:DumpIB %* || if %cnt% LEQ 3 goto :dump_base_again
	call :roll_base MODE:DumpIB %*
	call :restore_normal_mode %*
exit /b %ERRORLEVEL%

:restore_base

	call :kick_users %*
	call :roll_base MODE:RestoreIB %*
	call :restore_normal_mode %*
	call :change_system_header %*
exit /b %ERRORLEVEL%

:roll_base

	setlocal
	set ARGS=ICBASE:BASEFILE:EPFFILE:MODE
	echo %* | find "ICUSER" > nul && (set ARGS=!ARGS!:ICUSER)
	echo %* | find "ICPASS" > nul && (set ARGS=!ARGS!:ICPASS)
	call :arg_parser !ARGS! %*
	if not defined ICBASE (exit /b 10002)
	if defined ICUSER (set ICUSER=/n%ICUSER%)
	if defined ICPASS (set ICPASS=/p%ICPASS%)
	if defined MODE (
		if defined BASEFILE (set BASEFILE=%BASEFILE:"=""%) else (exit /b 10003)
		for /f %%i in ('echo:%ICBASE%*%BASEFILE%^|findstr /r .\*. ^>nul ^|^|echo:error') do exit /b 10006
		if "%MODE%" EQU "RestoreIB" (
			if not exist "%BASEFILE%" exit /b 10007
		)
		set CMDLINE=designer /s%ICSERVER%\%ICBASE% %ICUSER% %ICPASS% /DisableStartupMessages /%MODE% %BASEFILE%
	) else (
		if defined EPFFILE  (
			call :get_full_path EPFFILE %EPFFILE%
			set EPFFILE=!EPFFILE:"=""!
		) else (exit /b 10004)
		set CMDLINE=enterprise /s%ICSERVER%\%ICBASE% %ICUSER% %ICPASS% /DisableStartupMessages /Execute !EPFFILE!
	)
	REM for /f "tokens=*" %%i in ('call %~nx0 start_proc exec:"%ICEXE%" cmdline:"%CMDLINE%" ^|findstr /r .') do (
	for /f %%i in ('call %~nx0 start_proc exec:"%ICEXE%" cmdline:"%CMDLINE%" ^|findstr /r ^^[0-9]^$') do (
		rem echo:%%i
		set PID=%%i
	)
	if "%PID%" NEQ "" call :wait_for_pid %PID%
	if defined MODE (
		if "%MODE%" EQU "DumpIB" (
			if not exist "%BASEFILE%" (set ERRORLEVEL=10005)
		)
	)
exit /b %ERRORLEVEL%

:wait_for_pid

	setlocal
	:wait_for_pid_start
	set /a num=1+num
	ping -n 5 -w 1000 127.0.0.1 >nul
	for /f %%i in ('tasklist /nh /fi "PID eq %1" ^| find "%1" ^>nul ^&^& echo:one ^|^| echo:none') do (
		if "%%i" NEQ "none" (
			if %num% GEQ %PROCTIMEOUT% (
				set ERRORLEVEL=10001
			) else (
				goto :wait_for_pid_start
			)
		)
	)
exit /b %ERRORLEVEL%

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

	REM for /f "tokens=*" %%G IN ('wmic %global_params%  process call create "%exec% %cmdline%"^,"%workdir%"^|findstr "="') do ( 
	for /f "tokens=*" %%G IN ('wmic %global_params% process call create "%exec% %cmdline%"^,"%workdir%"^|findstr "="') do ( 
		rem %%G
		for /f  "tokens=2 delims=;= " %%H in ('echo:%%G') do (
			echo %%G | find "ProcessId" > nul && (call set /A PID=%%H)
			echo %%G | find "ReturnValue" > nul && (call set /A RETCOD=%%H)
		)
		rem call :concat
	)

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

	call :run_vbs number:001 %*
exit /b %ERRORLEVEL%

:change_system_header

	call :run_vbs number:002 %*
exit /b %ERRORLEVEL%

:restore_normal_mode

	call :run_vbs number:003 %*
exit /b %ERRORLEVEL%

:run_vbs

	setlocal
	call :arg_parser number:ICBASE %*
	if not defined number exit /b 
	for /f %%i in ('echo:%ICBASE%^|findstr /r . ^>nul ^|^|echo:error') do (exit /b 20000)
	call :gen_file_name VBSFILE
	set VBSLOG=%VBSFILE:VBS=LOG%
	call :gen_vbs%number%_file filename:%VBSFILE% ICUSER:%ICUSER% ICPASS:%ICPASS% ICSERVER:%ICSERVER% ICBASE:%ICBASE%
	cscript %VBSFILE% //nologo 2>%VBSLOG%
	for /f "" %%i in (%VBSLOG%) do (
		rem �������� ��������� ������
		if "%%~zi" NEQ "0" (set ERRORLEVEL=20001)
	)
	if %ERRORLEVEL% EQU 0 (
		del /q /f %VBSLOG%
		del /q /f %VBSFILE%
	)
exit /b %ERRORLEVEL%

:gen_file_name

	set _tmp=%1
	for /l %%j in (1,1,10) do (set /? | find "." > nul)
	set /a rnd=!time:~-2!*!random! 2>nul
	set %1=%LDATE%%LTIME%!rnd:~0,3!
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
	for /f "tokens=1,* delims=:" %%i in ('echo:%1') do (
		echo %comstr% | find "%%i" > nul && (set %%i=%%~j)
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
	for /f "usebackq skip=%BBEG% tokens=*" %%i in ("%~dpnx0") do (
		set _tmp=%%i
		call :escapes _tmp
		echo:!_tmp! | find "</%find%>" > nul && goto :gen_file_end
		for /f "tokens=*" %%j in ('echo:!_tmp!') do echo:%%j>>%filename%
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

:get_full_path

	set %~1=%~dpnx2
exit /b

:gen_vbs001_file

	setlocal
	call :arg_parser filename:ICUSER:ICPASS:ICSERVER:ICBASE %*
	call :gen_file find:vbs001 
exit /b %ERORLEVEL%

:gen_vbs002_file

	setlocal
	call :arg_parser filename:ICUSER:ICPASS:ICSERVER:ICBASE %*
	call :gen_file find:vbs002 
exit /b %ERORLEVEL%

:gen_vbs003_file

	setlocal
	call :arg_parser filename:ICUSER:ICPASS:ICSERVER:ICBASE %*
	call :gen_file find:vbs003 
exit /b %ERORLEVEL%

:err
exit /b %ERORLEVEL%

<vbs001>
Dim Connector
Dim AgentConnection
Dim Cluster
Dim WorkingProcess
Dim WorkingProcessConnection
Dim ConnectString

Set Connector = CreateObject("V82.COMConnector")
Set AgentConnection = Connector.ConnectAgent("%ICSERVER%")
Set Cluster = AgentConnection.GetClusters()(0)
AgentConnection.Authenticate Cluster, "", ""
Set WorkingProcess = AgentConnection.GetWorkingProcesses(Cluster)(0)
ConnectString = WorkingProcess.HostName & ":" & WorkingProcess.MainPort
Set WorkingProcessConnection = Connector.ConnectWorkingProcess(ConnectString)
WorkingProcessConnection.AddAuthentication "%ICUSER%", "%ICPASS%"

For Each ibDesc In WorkingProcessConnection.GetInfoBases()
	If ibDesc.Name = "%ICBASE%" Then
		Exit For
	End If
Next
ibDesc.ScheduledJobsDenied = True
WorkingProcessConnection.UpdateInfobase (ibDesc)

For Each Connection In WorkingProcessConnection.GetInfoBaseConnections(ibDesc)
	If (InStr("COMConsole|SrvrConsole", Connection.AppID) = 0) Then
		WorkingProcessConnection.Disconnect Connection
	End If
Next
</vbs001>

<vbs002>
Dim IC
Dim VersionNumber

Set IC = CreateObject("V82.Application")
IC.Connect ("Srvr=""%ICSERVER%"";Ref=""%ICBASE%"";Usr=""%ICUSER%"";Pwd=""%ICPASS%""")
IC.Constants.[����������������].Set ("%ICBASE%" & "_" & IC.Constants.[�����������������������].Get())
IC.Exit (False)
</vbs002>

<vbs003>
Dim Connector
Dim AgentConnection
Dim Cluster
Dim WorkingProcess
Dim WorkingProcessConnection
Dim ConnectString

Set Connector = CreateObject("V82.COMConnector")
Set AgentConnection = Connector.ConnectAgent("%ICSERVER%")
Set Cluster = AgentConnection.GetClusters()(0)
AgentConnection.Authenticate Cluster, "", ""
Set WorkingProcess = AgentConnection.GetWorkingProcesses(Cluster)(0)
ConnectString = WorkingProcess.HostName & ":" & WorkingProcess.MainPort
Set WorkingProcessConnection = Connector.ConnectWorkingProcess(ConnectString)
WorkingProcessConnection.AddAuthentication "%ICUSER%", "%ICPASS%"

For Each ibDesc In WorkingProcessConnection.GetInfoBases()
	If ibDesc.Name = "%ICBASE%" Then
		Exit For
	End If
Next
ibDesc.ScheduledJobsDenied = False
WorkingProcessConnection.UpdateInfobase (ibDesc)
</vbs003>

<SettingsBlock>
;******************************************************************************************
; ���������� ��������� ������. !��������! ��������� ������ ���� 1251
;******************************************************************************************
PROCTIMEOUT=2160
LDATE=!date:~-4!!date:~3,2!!date:~0,2!
LTIME=!time: =0!
BASEDATE=!date:~-4!.!date:~3,2!.!date:~0,2!
BASEFILE=%~dp0!IBOUT!_!BASEDATE!.dt
PRIORITY=NORMAL
ICUSER=robot
ICPASS=p@ssw0rd
ICSERVER=server
ICEXE=C:\Program Files\1cv82\8.2.15.289\bin\1cv8.exe
