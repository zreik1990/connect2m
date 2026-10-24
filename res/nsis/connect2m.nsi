; connect2m Windows installer (NSIS 3, Modern UI 2, electron-builder style).
; Copyright (c) 2026 Abdallah Zreik. Licensed under the GNU AGPL-3.0, like the
; rest of connect2m (based on RustDesk).
;
; Build (from the repository root):
;   makensis /DAPP_VERSION=1.5.0 /DDIST_DIR=..\..\dist /DOUT_FILE=..\..\Output\connect2m-Setup-1.5.0.exe res\nsis\connect2m.nsi
; DIST_DIR is the folder holding connect2m.exe and its DLLs/data. Relative paths
; are resolved from this script's folder.
;
; Command line (same switches as electron-builder installers):
;   /S              silent install (defaults: all users, Program Files, shortcuts)
;   /D=C:\path      install folder (must be the last switch)
;   /NODESKTOP      skip the desktop shortcut
;   /RUN            start connect2m after a silent install
; Uninstaller: /S for a silent uninstall.

Unicode true
ManifestDPIAware true
ManifestSupportedOS all
RequestExecutionLevel admin
SetCompressor /SOLID lzma
SetCompressorDictSize 64

!ifndef APP_VERSION
  !define APP_VERSION "1.5.0"
!endif
!ifndef DIST_DIR
  !define DIST_DIR "..\..\dist"
!endif
!ifndef OUT_FILE
  !define OUT_FILE "connect2m-Setup-${APP_VERSION}.exe"
!endif

; Must match the app name compiled into the program (libs/hbb_common config
; APP_NAME): the app finds its install folder through this Uninstall key and
; names its service, executable and link protocol after it.
!define APP_NAME "connect2m"
!define APP_EXE "connect2m.exe"
!define PUBLISHER "Abdallah Zreik"
!define COPYRIGHT "Copyright (c) 2026 Abdallah Zreik. Licensed under the GNU AGPL-3.0."
!define UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
!define INSTALLER_KEY "Software\${APP_NAME}\Installer"

Name "${APP_NAME}"
Caption "${APP_NAME} ${APP_VERSION} Setup"
OutFile "${OUT_FILE}"
InstallDir "$PROGRAMFILES64\${APP_NAME}"
InstallDirRegKey HKLM "${UNINST_KEY}" "InstallLocation"
BrandingText "${APP_NAME} ${APP_VERSION}"
ShowInstDetails nevershow
ShowUninstDetails nevershow

VIProductVersion "${APP_VERSION}.0"
VIAddVersionKey /LANG=0 "ProductName" "${APP_NAME}"
VIAddVersionKey /LANG=0 "CompanyName" "${PUBLISHER}"
VIAddVersionKey /LANG=0 "LegalCopyright" "${COPYRIGHT}"
VIAddVersionKey /LANG=0 "FileDescription" "${APP_NAME} Setup"
VIAddVersionKey /LANG=0 "FileVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=0 "ProductVersion" "${APP_VERSION}"

!include "MUI2.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
!include "WinVer.nsh"

; ---- Look and feel -------------------------------------------------------
!define MUI_ICON "..\icon.ico"
!define MUI_UNICON "..\icon.ico"
!define MUI_WELCOMEFINISHPAGE_BITMAP "art\side_100.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "art\side_100.bmp"
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP "art\header_100.bmp"
!define MUI_HEADERIMAGE_UNBITMAP "art\header_100.bmp"
!define MUI_CUSTOMFUNCTION_GUIINIT C2M_GuiInit
!define MUI_ABORTWARNING
!define MUI_LANGDLL_ALLLANGUAGES
!define MUI_LANGDLL_REGISTRY_ROOT HKLM
!define MUI_LANGDLL_REGISTRY_KEY "${INSTALLER_KEY}"
!define MUI_LANGDLL_REGISTRY_VALUENAME "Language"

; ---- Installer pages -----------------------------------------------------
!define MUI_PAGE_CUSTOMFUNCTION_SHOW C2M_WelcomeShow
!define MUI_PAGE_CUSTOMFUNCTION_DESTROYED C2M_SidebarDestroyed
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "$(MUILicense)"
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE DirectoryLeave
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchApp
!define MUI_PAGE_CUSTOMFUNCTION_SHOW C2M_FinishShow
!define MUI_PAGE_CUSTOMFUNCTION_DESTROYED C2M_SidebarDestroyed
!insertmacro MUI_PAGE_FINISH

; ---- Uninstaller pages ---------------------------------------------------
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Arabic"
!insertmacro MUI_RESERVEFILE_LANGDLL

!include "connect2m-art.nsh"

LicenseLangString MUILicense ${LANG_ENGLISH} "license.txt"
LicenseLangString MUILicense ${LANG_ARABIC} "license.txt"

LangString SecApp ${LANG_ENGLISH} "${APP_NAME} (required)"
LangString SecApp ${LANG_ARABIC} "${APP_NAME} (مطلوب)"
LangString SecDesktop ${LANG_ENGLISH} "Desktop shortcut"
LangString SecDesktop ${LANG_ARABIC} "اختصار على سطح المكتب"
LangString SecStartMenu ${LANG_ENGLISH} "Start menu shortcut"
LangString SecStartMenu ${LANG_ARABIC} "اختصار في قائمة ابدأ"
LangString Need64 ${LANG_ENGLISH} "${APP_NAME} requires 64-bit Windows 10 or newer."
LangString Need64 ${LANG_ARABIC} "يتطلب ${APP_NAME} نظام Windows 10 أو أحدث بإصدار 64 بت."
LangString MsiInstalled ${LANG_ENGLISH} "${APP_NAME} is already installed from the MSI package. Please uninstall it from Settings > Apps first, then run this setup again."
LangString MsiInstalled ${LANG_ARABIC} "تم تثبيت ${APP_NAME} مسبقاً من حزمة MSI. يرجى إزالته أولاً من الإعدادات > التطبيقات، ثم تشغيل برنامج الإعداد مرة أخرى."
LangString Stopping ${LANG_ENGLISH} "Stopping ${APP_NAME}..."
LangString Stopping ${LANG_ARABIC} "جارٍ إيقاف ${APP_NAME}..."
LangString Configuring ${LANG_ENGLISH} "Setting up the ${APP_NAME} service..."
LangString Configuring ${LANG_ARABIC} "جارٍ إعداد خدمة ${APP_NAME}..."

; ---- Helpers -------------------------------------------------------------

; Stop the service and every running copy before files are replaced or removed.
; `--before-uninstall` is the same hook the MSI package uses: it stops and
; deletes the service, ends app processes and removes the link handler and
; firewall rules. Fall back to plain commands if the old exe is missing.
!macro StopApp UN
  Function ${UN}StopApp
    ${If} ${FileExists} "$INSTDIR\${APP_EXE}"
      nsExec::Exec '"$INSTDIR\${APP_EXE}" --before-uninstall'
      Pop $0
    ${EndIf}
    nsExec::Exec 'sc stop ${APP_NAME}'
    Pop $0
    nsExec::Exec 'sc delete ${APP_NAME}'
    Pop $0
    nsExec::Exec 'taskkill /F /IM RuntimeBroker_${APP_NAME}.exe'
    Pop $0
    nsExec::Exec 'taskkill /F /IM ${APP_EXE}'
    Pop $0
    Sleep 1000
  FunctionEnd
!macroend
!insertmacro StopApp ""
!insertmacro StopApp "un."

Function LaunchApp
  ; The installer runs elevated; start the app as the signed-in user instead,
  ; through Explorer, so it does not inherit admin rights.
  Exec '"$WINDIR\explorer.exe" "$INSTDIR\${APP_EXE}"'
FunctionEnd

; Keep the program in its own "connect2m" folder, as electron-builder does, so
; the uninstaller never removes a folder the user picked for other things.
Function DirectoryLeave
  StrLen $0 "${APP_NAME}"
  IntOp $0 0 - $0
  StrCpy $1 "$INSTDIR" "" $0
  ${If} $1 != "${APP_NAME}"
    StrCpy $INSTDIR "$INSTDIR\${APP_NAME}"
  ${EndIf}
FunctionEnd

; ---- Sections ------------------------------------------------------------

Section "!$(SecApp)" SEC_APP
  SectionIn RO
  Call DirectoryLeave ; also covers /D= in silent installs
  DetailPrint "$(Stopping)"
  Call StopApp

  SetOutPath "$INSTDIR"
  SetOverwrite on
  ; Remove leftovers of the previous version's Flutter data so stale assets
  ; never mix with new ones; settings live in %AppData%, not here.
  RMDir /r "$INSTDIR\data"
  File /r "${DIST_DIR}\*.*"

  ; Optional overrides of the baked-in server settings:
  ;   connect2m-Setup.exe /SERVER=10.0.0.5 /KEY=abc...   (both accept /S too)
  ${GetParameters} $R8
  ClearErrors
  ${GetOptions} $R8 "/SERVER=" $R9
  ${IfNot} ${Errors}
    WriteINIStr "$INSTDIR\connect2m.ini" "connect2m" "server" "$R9"
  ${EndIf}
  ClearErrors
  ${GetOptions} $R8 "/KEY=" $R9
  ${IfNot} ${Errors}
    WriteINIStr "$INSTDIR\connect2m.ini" "connect2m" "key" "$R9"
  ${EndIf}

  WriteUninstaller "$INSTDIR\Uninstall ${APP_NAME}.exe"

  ; Add/Remove Programs entry. The app reads InstallLocation from this key to
  ; know it is installed and where (see get_install_info in windows.rs).
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${APP_NAME}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "${PUBLISHER}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" '"$INSTDIR\${APP_EXE}",0'
  WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\Uninstall ${APP_NAME}.exe"'
  WriteRegStr HKLM "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\Uninstall ${APP_NAME}.exe" /S'
  WriteRegStr HKLM "${UNINST_KEY}" "URLInfoAbout" "__CONNECT2M_SOURCE_URL__"
  WriteRegStr HKLM "${UNINST_KEY}" "Comments" "${COPYRIGHT}"
  WriteRegStr HKLM "${UNINST_KEY}" "Version" "${APP_VERSION}"
  WriteRegDWORD HKLM "${UNINST_KEY}" "EstimatedSize" "$0"
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1
  WriteRegStr HKLM "${INSTALLER_KEY}" "Type" "nsis"

  ; Service, firewall rules and connect2m:// link handler, done by the app
  ; itself exactly as for its MSI package.
  DetailPrint "$(Configuring)"
  nsExec::Exec '"$INSTDIR\${APP_EXE}" --after-install'
  Pop $0
SectionEnd

Section "$(SecStartMenu)" SEC_STARTMENU
  SetShellVarContext all
  CreateDirectory "$SMPROGRAMS\${APP_NAME}"
  CreateShortCut "$SMPROGRAMS\${APP_NAME}\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
  WriteRegStr HKLM "${INSTALLER_KEY}" "StartMenuShortcut" "1"
SectionEnd

Section "$(SecDesktop)" SEC_DESKTOP
  SetShellVarContext all
  CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${APP_EXE}" "" "$INSTDIR\${APP_EXE}" 0
  WriteRegStr HKLM "${INSTALLER_KEY}" "DesktopShortcut" "1"
SectionEnd

LangString DescApp ${LANG_ENGLISH} "The connect2m app and its background service, so this computer can receive remote support."
LangString DescApp ${LANG_ARABIC} "تطبيق connect2m وخدمته في الخلفية، ليتمكن هذا الجهاز من تلقي الدعم عن بُعد."
LangString DescStartMenu ${LANG_ENGLISH} "Add connect2m to the Start menu."
LangString DescStartMenu ${LANG_ARABIC} "إضافة connect2m إلى قائمة ابدأ."
LangString DescDesktop ${LANG_ENGLISH} "Put a connect2m icon on the desktop for all users."
LangString DescDesktop ${LANG_ARABIC} "وضع أيقونة connect2m على سطح المكتب لجميع المستخدمين."

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_APP} $(DescApp)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_STARTMENU} $(DescStartMenu)
  !insertmacro MUI_DESCRIPTION_TEXT ${SEC_DESKTOP} $(DescDesktop)
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ---- Installer callbacks -------------------------------------------------

Function .onInit
  SetRegView 64
  ${IfNot} ${RunningX64}
  ${OrIfNot} ${AtLeastWin10}
    MessageBox MB_ICONSTOP|MB_OK "$(Need64)" /SD IDOK
    Abort
  ${EndIf}

  ; The MSI keeps its own registry layout; the app refuses to mix the two.
  ReadRegDWORD $0 HKLM "${UNINST_KEY}" "WindowsInstaller"
  ${If} $0 == 1
    MessageBox MB_ICONEXCLAMATION|MB_OK "$(MsiInstalled)" /SD IDOK
    Abort
  ${EndIf}

  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/NODESKTOP" $R1
  ${IfNot} ${Errors}
    SectionSetFlags ${SEC_DESKTOP} 0
  ${EndIf}

  Call C2M_ExtractArt
  !insertmacro MUI_LANGDLL_DISPLAY
FunctionEnd

Function .onInstSuccess
  ${If} ${Silent}
    ${GetParameters} $R0
    ClearErrors
    ${GetOptions} $R0 "/RUN" $R1
    ${IfNot} ${Errors}
      Call LaunchApp
    ${EndIf}
  ${EndIf}
FunctionEnd

; ---- Uninstaller ---------------------------------------------------------

Function un.onInit
  SetRegView 64
  !insertmacro MUI_UNGETLANGUAGE
FunctionEnd

Section "Uninstall"
  SetRegView 64
  Call un.StopApp

  SetShellVarContext all
  Delete "$DESKTOP\${APP_NAME}.lnk"
  RMDir /r "$SMPROGRAMS\${APP_NAME}"
  Delete "$SMPROGRAMS\Startup\${APP_NAME} Tray.lnk"

  ; Remove what --after-install registered, in case the exe was already gone.
  DeleteRegKey HKCR ".${APP_NAME}"
  DeleteRegKey HKCR "${APP_NAME}"
  nsExec::Exec 'netsh advfirewall firewall delete rule name="${APP_NAME} Service"'
  Pop $0

  ; Remove the program folder only. User settings and the device ID stay in
  ; %AppData%\${APP_NAME} so a reinstall keeps the same ID.
  ${If} ${FileExists} "$INSTDIR\Uninstall ${APP_NAME}.exe"
    RMDir /r /REBOOTOK "$INSTDIR"
  ${EndIf}

  DeleteRegKey HKLM "${UNINST_KEY}"
  DeleteRegKey HKLM "Software\${APP_NAME}"
SectionEnd
