!include MUI2.nsh

; generated file
outFile "Palmares-installer.exe"
  
; install in program files
installDir $PROGRAMFILES\Palmares

requestExecutionLevel admin

!define LANG_FRENCH "French"

; header customization
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "header.bmp"
!define MUI_WELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_UNWELCOMEFINISHPAGE_BITMAP "welcome.bmp"
!define MUI_ICON "ribas-icon.ico"
!define MUI_BGCOLOR "EEEEEE"

; displayed pages: choose directory, and file installation
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

; default section
section

  ; define the output path files
  setOutPath $INSTDIR
  file ..\package.json
  file ..\README.md
  file ..\index.html
  file /r ..\bin
  file /r ..\lib
  file /r ..\nls
  file /r ..\node_modules
  file /r ..\style
  file /r ..\template

  setOutPath $LOCALAPPDATA\palmares
  file /r ..\conf

  ; creates a shortcut within installation folder and on desktop
  createShortCut "$INSTDIR\Palmares.lnk" "$INSTDIR\bin\nw.exe" '"$INSTDIR"' "$INSTDIR\style\ribas-icon.ico"
  createShortCut "$DESKTOP\Palmares.lnk" "$INSTDIR\bin\nw.exe" '"$INSTDIR"' "$INSTDIR\style\ribas-icon.ico"

  ; populate indexedDB
  !define APP_DATA $LOCALAPPDATA\palmares\IndexedDB\file__0.indexeddb.leveldb
  ; upgrade case: replace existing data
  ; TODO unquote to replace. Use with caution ! 
  rmdir /r ${APP_DATA}
  
  IfFileExists ${APP_DATA}\*.* noop loadData

  loadData:
    createDirectory ${APP_DATA}
    setOutPath ${APP_DATA}
    file data\*.*
  noop:

  ; Write also the uninstaller
  writeUninstaller $INSTDIR\uninstall.exe

sectionEnd

; uninstallation pages: confirm and file deletion
!insertmacro MUI_UNPAGE_WELCOME
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Uninstall section
section "Uninstall"
 
  ; Always delete uninstaller first
  delete $INSTDIR\uninstall.exe
  delete $INSTDIR\package.json
  delete $INSTDIR\README.md
  delete $INSTDIR\index.html
  rmdir /r $INSTDIR\bin
  rmdir /r $INSTDIR\lib
  rmdir /r $INSTDIR\nls
  rmdir /r $INSTDIR\node_modules
  rmdir /r $INSTDIR\style
  rmdir /r $INSTDIR\template
  rmdir /r $LOCALAPPDATA\palmares\conf
  delete $INSTDIR\Palmares.lnk
  delete $DESKTOP\Palmares.lnk
 
sectionEnd

; language labels
!define MUI_TEXT_WELCOME_INFO_TITLE "Bienvenue dans l'installation de l'application $(^NameDA)."
!define MUI_TEXT_WELCOME_INFO_TEXT "Vous êtes sur le point d'installer $(^NameDA) sur votre ordinateur.$\r$\n$\r$\n$_CLICK"
!insertmacro MUI_LANGUAGE ${LANG_FRENCH}
Name "Palmarès"