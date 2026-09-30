#define AppVersion "1.1.14"
#define SourceRoot AddBackslash(SourcePath) + "..\..\dist\setup-payload\TotalIgnore-Vencord-1.15.9-Windows"
#define AssetRoot AddBackslash(SourcePath) + "..\..\dist\setup-assets"

[Setup]
AppId={{DA2F8641-938C-4C14-B463-53958E56CF6A}
AppName=TotalIgnore by Dr. Avinash Mandre
AppVersion={#AppVersion}
AppPublisher=Dr. Avinash Mandre
AppPublisherURL=https://github.com/SEGORUNDESTRUCTIBLE/TotalIgnore
AppSupportURL=https://github.com/SEGORUNDESTRUCTIBLE/TotalIgnore/issues
DefaultDirName={localappdata}\Programs\TotalIgnore
DefaultGroupName=TotalIgnore
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\..\dist
OutputBaseFilename=TotalIgnore-Setup-{#AppVersion}
SetupIconFile={#AssetRoot}\TotalIgnore.ico
WizardImageFile={#AssetRoot}\WizardSide.bmp
WizardSmallImageFile={#AssetRoot}\WizardSmall.bmp
WizardStyle=modern dynamic
WizardSizePercent=100
Compression=lzma2/ultra64
SolidCompression=yes
UninstallDisplayIcon={app}\TotalIgnore.ico
UninstallDisplayName=TotalIgnore by Dr. Avinash Mandre
CloseApplications=yes
RestartApplications=no
DisableWelcomePage=no
DisableDirPage=no
DisableReadyPage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Messages]
WelcomeLabel1=Welcome to TotalIgnore
WelcomeLabel2=Install the creator-branded Vencord build with TotalIgnore for Discord Stable.%n%nCreated by Dr. Avinash Mandre.
FinishedHeadingLabel=TotalIgnore is ready
FinishedLabel=Start Discord and enable TotalIgnore in User Settings > Vencord > Plugins.

[Files]
Source: "{#SourceRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#AssetRoot}\TotalIgnore.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\TotalIgnore on GitHub"; Filename: "https://github.com/SEGORUNDESTRUCTIBLE/TotalIgnore"
Name: "{group}\Uninstall TotalIgnore"; Filename: "{uninstallexe}"

[Code]
function SetEnvironmentVariable(lpName, lpValue: string): Boolean;
  external 'SetEnvironmentVariableW@kernel32.dll stdcall';

procedure RestoreEnvironmentVariable(const Name, Value: string);
begin
  SetEnvironmentVariable(Name, Value);
end;

function RunVencordInstaller(const Parameters: string; var ExitCode: Integer): Boolean;
var
  OldDataDir, OldDevInstall, InstallerPath, LogPath, CommandLine: string;
begin
  OldDataDir := GetEnv('VENCORD_USER_DATA_DIR');
  OldDevInstall := GetEnv('VENCORD_DEV_INSTALL');
  InstallerPath := ExpandConstant('{app}\dist\Installer\VencordInstallerCli.exe');
  LogPath := ExpandConstant('{tmp}\TotalIgnore-VencordInstaller.log');
  DeleteFile(LogPath);
  CommandLine :=
    '/D /S /C ""' + InstallerPath + '" ' + Parameters + ' -debug > "' + LogPath + '" 2>&1"';
  SetEnvironmentVariable('VENCORD_USER_DATA_DIR', ExpandConstant('{app}'));
  SetEnvironmentVariable('VENCORD_DEV_INSTALL', '1');
  try
    Result := Exec(
      ExpandConstant('{sys}\cmd.exe'),
      CommandLine,
      ExpandConstant('{app}'),
      SW_HIDE,
      ewWaitUntilTerminated,
      ExitCode
    );
  finally
    RestoreEnvironmentVariable('VENCORD_USER_DATA_DIR', OldDataDir);
    RestoreEnvironmentVariable('VENCORD_DEV_INSTALL', OldDevInstall);
  end;
end;

function GetVencordInstallerFailureMessage(const Action: string; ExitCode: Integer): string;
var
  LogPath, LogText: string;
  LogContents: AnsiString;
begin
  LogPath := ExpandConstant('{tmp}\TotalIgnore-VencordInstaller.log');
  LogContents := '';
  if FileExists(LogPath) then
    LoadStringFromFile(LogPath, LogContents);

  LogText := LogContents;
  if Length(LogText) > 5000 then
    LogText := Copy(LogText, Length(LogText) - 4999, 5000);

  if LogText = '' then
    LogText := 'The Vencord installer did not produce diagnostic output.';
  if Pos('The system cannot find the file specified.', LogText) > 0 then
    LogText := LogText + #13#10#13#10 +
      'Discord may still be updating or its newest app folder may be incomplete. ' +
      'Start Discord and wait for it to finish updating, then exit it completely and retry setup. ' +
      'If Discord will not start, repair or reinstall Discord first.';

  Result :=
    Action + ' (exit code ' + IntToStr(ExitCode) + ').' + #13#10#13#10 +
    'Diagnostic output:' + #13#10 + LogText + #13#10#13#10 +
    'The full log is at:' + #13#10 + LogPath;
end;

function IsDiscordRunning(): Boolean;
var
  ExitCode: Integer;
begin
  Result :=
    Exec(
      ExpandConstant('{sys}\cmd.exe'),
      '/C tasklist /FI "IMAGENAME eq Discord.exe" /NH | find /I "Discord.exe" >nul',
      '',
      SW_HIDE,
      ewWaitUntilTerminated,
      ExitCode
    ) and (ExitCode = 0);
end;

function GetLatestDiscordAppVersion(): string;
var
  FindRec: TFindRec;
  Candidate: string;
begin
  Result := '';
  if FindFirst(ExpandConstant('{localappdata}\Discord\app-*'), FindRec) then
  begin
    try
      repeat
        Candidate := ExpandConstant('{localappdata}\Discord\' + FindRec.Name + '\resources');
        if DirExists(Candidate) and (CompareText(FindRec.Name, Result) > 0) then
          Result := FindRec.Name;
      until not FindNext(FindRec);
    finally
      FindClose(FindRec);
    end;
  end;
end;

function InitializeSetup(): Boolean;
var
  LatestAppVersion, LatestAppAsar: string;
begin
  Result := True;
  if not FileExists(ExpandConstant('{localappdata}\Discord\Update.exe')) then
  begin
    Log('Setup preflight blocked: Discord Stable was not found.');
    SuppressibleMsgBox(
      'Discord Stable was not found for this Windows user. Install Discord Stable first, then run this setup again.',
      mbError,
      MB_OK,
      MB_OK
    );
    Result := False;
  end;

  if Result then
  begin
    LatestAppVersion := GetLatestDiscordAppVersion();
    if LatestAppVersion <> '' then
    begin
      LatestAppAsar := ExpandConstant(
        '{localappdata}\Discord\' + LatestAppVersion + '\resources\app.asar'
      );
      if not FileExists(LatestAppAsar) then
      begin
        Log('Setup preflight blocked: Discord app archive is missing: ' + LatestAppAsar);
        SuppressibleMsgBox(
          'Discord''s newest app folder (' + LatestAppVersion + ') is incomplete: resources\app.asar is missing.' + #13#10#13#10 +
          'Start Discord and wait for its update to finish, then exit Discord completely and run setup again. ' +
          'If Discord will not start, repair or reinstall Discord first. No files have been changed.',
          mbError,
          MB_OK,
          MB_OK
        );
        Result := False;
      end;
    end;
  end;

  if Result and IsDiscordRunning() then
  begin
    Log('Setup preflight blocked: Discord is still running.');
    SuppressibleMsgBox(
      'Discord is still running, possibly in the system tray. Exit Discord completely, then run this setup again. No files have been changed.',
      mbError,
      MB_OK,
      MB_OK
    );
    Result := False;
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ExitCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    if not RunVencordInstaller('-install -branch stable', ExitCode) then
      RaiseException('Could not start the Vencord installer. Close Discord and try again.');
    if ExitCode <> 0 then
      RaiseException(GetVencordInstallerFailureMessage('Vencord could not patch Discord Stable', ExitCode));
  end;
end;

function InitializeUninstall(): Boolean;
begin
  Result := False;
  if IsDiscordRunning() then
  begin
    MsgBox(
      'Discord is still running, possibly in the system tray. Exit Discord completely, then run the uninstaller again.',
      mbError,
      MB_OK
    );
    Exit;
  end;

  Result := MsgBox(
    'This will remove Vencord from Discord Stable and uninstall TotalIgnore. Your Vencord settings are kept.',
    mbConfirmation,
    MB_YESNO
  ) = IDYES;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ExitCode: Integer;
begin
  if CurUninstallStep = usUninstall then
  begin
    if not RunVencordInstaller('-uninstall -branch stable', ExitCode) then
      RaiseException('Could not start the Vencord uninstaller. Close Discord and try again.');
    if ExitCode <> 0 then
      RaiseException(GetVencordInstallerFailureMessage('Vencord could not be removed from Discord Stable', ExitCode));
  end;
end;
