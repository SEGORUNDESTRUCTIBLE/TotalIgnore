#define AppVersion "1.1.2"
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
  OldDataDir, OldDevInstall: string;
begin
  OldDataDir := GetEnv('VENCORD_USER_DATA_DIR');
  OldDevInstall := GetEnv('VENCORD_DEV_INSTALL');
  SetEnvironmentVariable('VENCORD_USER_DATA_DIR', ExpandConstant('{app}'));
  SetEnvironmentVariable('VENCORD_DEV_INSTALL', '1');
  try
    Result := Exec(
      ExpandConstant('{app}\dist\Installer\VencordInstallerCli.exe'),
      Parameters,
      ExpandConstant('{app}'),
      SW_SHOW,
      ewWaitUntilTerminated,
      ExitCode
    );
  finally
    RestoreEnvironmentVariable('VENCORD_USER_DATA_DIR', OldDataDir);
    RestoreEnvironmentVariable('VENCORD_DEV_INSTALL', OldDevInstall);
  end;
end;

function InitializeSetup(): Boolean;
begin
  Result := True;
  if not FileExists(ExpandConstant('{localappdata}\Discord\Update.exe')) then
  begin
    MsgBox(
      'Discord Stable was not found for this Windows user. Install Discord Stable first, then run this setup again.',
      mbError,
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
      RaiseException(
        'Vencord could not patch Discord Stable (exit code ' + IntToStr(ExitCode) +
        '). Make sure Discord is fully closed, then run the setup again.'
      );
  end;
end;

function InitializeUninstall(): Boolean;
begin
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
      RaiseException(
        'Vencord could not be removed from Discord Stable (exit code ' +
        IntToStr(ExitCode) + '). Close Discord and run the uninstaller again.'
      );
  end;
end;
