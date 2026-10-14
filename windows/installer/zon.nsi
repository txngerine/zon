; ZON — Windows installer (NSIS).
;
; Built by CI (.github/workflows/ci.yml), which passes:
;   /DVERSION=1.0.0            display version (pubspec, no build number)
;   /DVERSION_QUAD=1.0.0.1     4-part version required by VIProductVersion
;   /DAPPDIR=<abs path>        the flutter build output folder to pack
;   /DOUTFILE=<abs path>       where to write the setup exe
;
; Per-user install (no admin): %LOCALAPPDATA%\Programs\ZON by default,
; uninstaller registered under HKCU so it shows in Apps & features.

!include "MUI2.nsh"
!include "LogicLib.nsh"

!ifndef VERSION
  !define VERSION "1.0.0"
!endif
!ifndef VERSION_QUAD
  !define VERSION_QUAD "1.0.0.1"
!endif
!ifndef APPDIR
  !define APPDIR "..\..\build\windows\x64\runner\Release"
!endif
!ifndef OUTFILE
  !define OUTFILE "zon-windows-x64-setup.exe"
!endif

!define APP_NAME "ZON"
!define APP_EXE "zon.exe"
!define PUBLISHER "dev.zon"
!define UNINSTALL_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\ZON"
!define APP_KEY "Software\ZON"

Name "${APP_NAME} ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\${APP_NAME}"
InstallDirRegKey HKCU "${APP_KEY}" "InstallLocation"
RequestExecutionLevel user
Unicode true
SetCompressor /SOLID lzma
ManifestDPIAware true
BrandingText "${APP_NAME} ${VERSION}"

!define MUI_ICON "..\runner\resources\app_icon.ico"
!define MUI_UNICON "..\runner\resources\app_icon.ico"
!define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXE}"
!define MUI_FINISHPAGE_RUN_TEXT "Launch ${APP_NAME}"

!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

VIProductVersion "${VERSION_QUAD}"
VIAddVersionKey /LANG=0 "ProductName" "${APP_NAME}"
VIAddVersionKey /LANG=0 "CompanyName" "${PUBLISHER}"
VIAddVersionKey /LANG=0 "FileVersion" "${VERSION}"
VIAddVersionKey /LANG=0 "FileDescription" "${APP_NAME} Installer"
VIAddVersionKey /LANG=0 "LegalCopyright" "(C) 2026 ${PUBLISHER}"

; Stops a running zon.exe (asks first). Used from .onInit and un.onInit.
!macro CloseZon
  nsExec::ExecToStack 'cmd.exe /C tasklist /FI "IMAGENAME eq ${APP_EXE}" /NH | findstr /I /C:${APP_EXE}'
  Pop $0
  Pop $1
  ${If} $0 == 0
    MessageBox MB_YESNO|MB_ICONEXCLAMATION \
      "${APP_NAME} is running. Close it and continue?" IDNO abort_step
    nsExec::Exec 'cmd.exe /C taskkill /IM ${APP_EXE} /F'
    Pop $0
    Sleep 700
  ${EndIf}
  Goto done_step
abort_step:
  Abort
done_step:
!macroend

Function .onInit
  !insertmacro CloseZon
FunctionEnd

Function un.onInit
  !insertmacro CloseZon
FunctionEnd

Section "${APP_NAME}" SecApp
  SectionIn RO

  SetOutPath "$INSTDIR"
  File /r "${APPDIR}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; Start menu
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk" "$INSTDIR\Uninstall.exe"

  ; Apps & features
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "DisplayIcon" "$INSTDIR\${APP_EXE}"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "${UNINSTALL_KEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${UNINSTALL_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoModify" 1
  WriteRegDWORD HKCU "${UNINSTALL_KEY}" "NoRepair" 1

  WriteRegStr HKCU "${APP_KEY}" "InstallLocation" "$INSTDIR"

  ; .torrent: always available under "Open with"; become the default only
  ; when the file type has no handler yet (never steal one silently).
  WriteRegStr HKCU "Software\Classes\${APP_NAME}.torrent" "" "${APP_NAME} Torrent File"
  WriteRegStr HKCU "Software\Classes\${APP_NAME}.torrent\DefaultIcon" "" "$INSTDIR\${APP_EXE},0"
  WriteRegStr HKCU "Software\Classes\${APP_NAME}.torrent\shell\open\command" "" '"$INSTDIR\${APP_EXE}" "%1"'
  WriteRegStr HKCU "Software\Classes\.torrent\OpenWithProgids" "${APP_NAME}.torrent" ""
  ReadRegStr $0 HKCR ".torrent" ""
  ${If} $0 == ""
    WriteRegStr HKCU "Software\Classes\.torrent" "" "${APP_NAME}.torrent"
  ${EndIf}
SectionEnd

Section /o "Desktop shortcut" SecDesktop
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}"
SectionEnd

Section "Uninstall"
  ; Only remove registry entries that still point at this install.
  DeleteRegKey HKCU "${UNINSTALL_KEY}"
  DeleteRegKey HKCU "${APP_KEY}"

  DeleteRegKey HKCU "Software\Classes\${APP_NAME}.torrent"
  DeleteRegValue HKCU "Software\Classes\.torrent\OpenWithProgids" "${APP_NAME}.torrent"
  ReadRegStr $0 HKCR ".torrent" ""
  ${If} $0 == "${APP_NAME}.torrent"
    DeleteRegValue HKCU "Software\Classes\.torrent" ""
  ${EndIf}

  ReadRegStr $0 HKCU "Software\Classes\magnet\shell\open\command" ""
  StrCpy $1 '"$INSTDIR\${APP_EXE}" "%1"'
  ${If} $0 == $1
    DeleteRegKey HKCU "Software\Classes\magnet"
  ${EndIf}

  DeleteRegValue HKCU "Software\Microsoft\Windows\CurrentVersion\Run" "${APP_NAME}"

  Delete "$INSTDIR\Uninstall.exe"
  RMDir /r "$INSTDIR\data"
  RMDir "$INSTDIR"

  Delete "$DESKTOP\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk"
  Delete "$SMPROGRAMS\${APP_NAME}\Uninstall ${APP_NAME}.lnk"
  RMDir "$SMPROGRAMS\${APP_NAME}"
SectionEnd
