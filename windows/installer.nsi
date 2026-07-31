; Void Music NSIS Installer Script
; This script creates an installer with proper uninstall cleanup

!define APPNAME "Void Music"
!define COMPANYNAME "SilentCode.CO"
!define DESCRIPTION "Void Music - An Open Source Free Music Player"
!define VERSIONMAJOR 3
!define VERSIONMINOR 0
!define VERSIONBUILD 4
!define HELPURL "https://github.com/siamislamtalha/Void-Build" ; "Support information" link
!define UPDATEURL "https://github.com/siamislamtalha/Void-Build/releases" ; "Product Updates" link
!define ABOUTURL "https://github.com/siamislamtalha/Void-Build" ; "Publisher" link
!define PUBLISHER "SilentCode.CO"
!define INSTDIR_REG_ROOT "HKLM" ; Default root registry key
!define INSTDIR_REG_KEY "Software\${APPNAME}" ; Default registry key
!define INSTDIR_REG_VALUENAME "Install_Dir" ; Default registry value name

!define MULTIUSER_EXECUTIONLEVEL Highest ; Request admin rights
!define MULTIUSER_INSTALLMODE_DEFAULT_ALLUSERS 1 ; Install for all users by default
!define MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_KEY "${INSTDIR_REG_KEY}"
!define MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_VALUENAME "${INSTDIR_REG_VALUENAME}"

!include "MultiUser.nsh"
!include "MUI2.nsh"

; Installer pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; Uninstaller pages
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Language
!insertmacro MUI_LANGUAGE "English"

; Installer attributes
Name "${APPNAME}"
OutFile "VoidMusic-Setup-${VERSIONMAJOR}.${VERSIONMINOR}.${VERSIONBUILD}.exe"
Unicode True
InstallDir "$PROGRAMFILES\${APPNAME}"
InstallDirRegKey "${INSTDIR_REG_ROOT}" "${INSTDIR_REG_KEY}" "${INSTDIR_REG_VALUENAME}"
RequestExecutionLevel admin

; Registry keys for uninstall
!define REG_UNINSTALL "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APPNAME}"

Section "Main Application" SecApp
    SetOutPath $INSTDIR
    File /r "build\windows\x64\runner\Release\*"
    
    ; Create uninstaller
    WriteUninstaller "$INSTDIR\uninstall.exe"
    
    ; Add uninstall information to registry
    WriteRegStr ${INSTDIR_REG_ROOT} "${INSTDIR_REG_KEY}" "${INSTDIR_REG_VALUENAME}" $INSTDIR
    WriteRegStr ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "DisplayName" "${APPNAME}"
    WriteRegStr ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "DisplayVersion" "${VERSIONMAJOR}.${VERSIONMINOR}.${VERSIONBUILD}"
    WriteRegStr ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "Publisher" "${PUBLISHER}"
    WriteRegStr ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "UninstallString" "$INSTDIR\uninstall.exe"
    WriteRegStr ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "QuietUninstallString" "$INSTDIR\uninstall.exe /S"
    WriteRegStr ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "HelpLink" "${HELPURL}"
    WriteRegStr ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "URLUpdateInfo" "${UPDATEURL}"
    WriteRegStr ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "URLInfoAbout" "${ABOUTURL}"
    WriteRegStr ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "InstallLocation" "$INSTDIR"
    WriteRegDWORD ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "NoModify" 1
    WriteRegDWORD ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}" "NoRepair" 1
    
    ; Copy cleanup script
    File "uninstall_cleanup.ps1"
SectionEnd

Section "Desktop Shortcut" SecShortcut
    CreateShortCut "$DESKTOP\${APPNAME}.lnk" "$INSTDIR\voidmusic.exe" "" "$INSTDIR\voidmusic.exe" 0
SectionEnd

Section "Start Menu Shortcut" SecStartMenu
    CreateDirectory "$SMPROGRAMS\${APPNAME}"
    CreateShortCut "$SMPROGRAMS\${APPNAME}\${APPNAME}.lnk" "$INSTDIR\voidmusic.exe" "" "$INSTDIR\voidmusic.exe" 0
    CreateShortCut "$SMPROGRAMS\${APPNAME}\Uninstall.lnk" "$INSTDIR\uninstall.exe"
SectionEnd

; Uninstaller section
Section "Uninstall"
    ; Run cleanup script
    ExecWait '"powershell.exe" -ExecutionPolicy Bypass -File "$INSTDIR\uninstall_cleanup.ps1" -InstallDir "$INSTDIR"'
    
    ; Delete files and directories
    RMDir /r "$INSTDIR"
    
    ; Delete shortcuts
    Delete "$DESKTOP\${APPNAME}.lnk"
    RMDir /r "$SMPROGRAMS\${APPNAME}"
    
    ; Remove registry keys
    DeleteRegKey ${INSTDIR_REG_ROOT} "${INSTDIR_REG_KEY}"
    DeleteRegKey ${INSTDIR_REG_ROOT} "${REG_UNINSTALL}"
SectionEnd

; Section descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
    !insertmacro MUI_DESCRIPTION_TEXT ${SecApp} "Main application files"
    !insertmacro MUI_DESCRIPTION_TEXT ${SecShortcut} "Create a shortcut on the desktop"
    !insertmacro MUI_DESCRIPTION_TEXT ${SecStartMenu} "Create a shortcut in the Start Menu"
!insertmacro MUI_FUNCTION_DESCRIPTION_END
