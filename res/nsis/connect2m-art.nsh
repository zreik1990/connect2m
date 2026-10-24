; connect2m installer artwork: pixel-sharp at every Windows display scale, and
; an animated icon on the welcome and finish pages.
; Copyright (c) 2026 Abdallah Zreik. Licensed under the GNU AGPL-3.0.
;
; art\side_<pct>.bmp        sidebar, rendered for 100/125/150/175/200 % scaling
; art\anim_<pct>_<nn>.bmp   24 animation frames of the sidebar's icon area
; art\header_<pct>.bmp      header of the inner pages
; (made by make_installer_art.py from vector drawings)
;
; Only the set matching the PC's display scale is extracted. The animation is a
; small picture control placed over the sidebar's icon area, swapped every
; 83 ms by an nsDialogs timer; everything else in the sidebar stays still.

!include "nsDialogs.nsh"
!include "WinMessages.nsh"

!define C2M_FRAMES 24
!define C2M_FRAME_MS 83
; Animated area in the 164x314 sidebar (must match make_installer_art.py).
!define C2M_RX0 8
!define C2M_RY0 44
!define C2M_RX1 156
!define C2M_RY1 176
!define C2M_LR_LOADFROMFILE 0x10

Var C2M_Pct
Var C2M_Prefix
Var C2M_Frame
Var C2M_Anim
Var C2M_AnimW
Var C2M_AnimH
Var C2M_SideBmp
Var C2M_FrameBmp

!macro C2M_ExtractScale PCT
  File "/oname=$PLUGINSDIR\art\side.bmp" "art\side_${PCT}.bmp"
  File "/oname=$PLUGINSDIR\art\header.bmp" "art\header_${PCT}.bmp"
  File "art\anim_${PCT}_*.bmp"
  StrCpy $C2M_Prefix "$PLUGINSDIR\art\anim_${PCT}_"
!macroend

; Pick the artwork for the system's display scale and extract it.
Function C2M_ExtractArt
  InitPluginsDir
  System::Call 'user32::GetDC(p 0)p.r1'
  System::Call 'gdi32::GetDeviceCaps(p r1, i 88)i.r0' ; LOGPIXELSX
  System::Call 'user32::ReleaseDC(p 0, p r1)'
  ${If} $0 <= 96
    StrCpy $C2M_Pct 100
  ${ElseIf} $0 <= 120
    StrCpy $C2M_Pct 125
  ${ElseIf} $0 <= 144
    StrCpy $C2M_Pct 150
  ${ElseIf} $0 <= 168
    StrCpy $C2M_Pct 175
  ${Else}
    StrCpy $C2M_Pct 200
  ${EndIf}
  SetOutPath "$PLUGINSDIR\art"
  ${Switch} $C2M_Pct
    ${Case} 100
      !insertmacro C2M_ExtractScale 100
      ${Break}
    ${Case} 125
      !insertmacro C2M_ExtractScale 125
      ${Break}
    ${Case} 150
      !insertmacro C2M_ExtractScale 150
      ${Break}
    ${Case} 175
      !insertmacro C2M_ExtractScale 175
      ${Break}
    ${Default}
      !insertmacro C2M_ExtractScale 200
      ${Break}
  ${EndSwitch}
  SetOutPath "$TEMP"
FunctionEnd

; Load a bitmap file at exactly W x H pixels into OUT.
!macro C2M_LoadBitmap FILE W H OUT
  System::Call 'user32::LoadImage(p 0, t "${FILE}", i 0, i ${W}, i ${H}, i ${C2M_LR_LOADFROMFILE})p.s'
  Pop ${OUT}
!macroend

; Inner pages: swap the header picture for the sharp one.
Function C2M_GuiInit
  GetDlgItem $0 $HWNDPARENT 1046
  ${IfThen} $0 = 0 ${|} Return ${|}
  System::Call '*(i, i, i, i)p.r1'
  System::Call 'user32::GetClientRect(p r0, p r1)'
  System::Call '*$1(i, i, i.r2, i.r3)'
  System::Free $1
  ${If} ${FileExists} "$PLUGINSDIR\art\header.bmp"
    !insertmacro C2M_LoadBitmap "$PLUGINSDIR\art\header.bmp" $2 $3 $4
    SendMessage $0 ${STM_SETIMAGE} ${IMAGE_BITMAP} $4 $5
  ${EndIf}
FunctionEnd

; $0 = the page's sidebar picture control. Shows the sharp sidebar and starts
; the animation over its icon area.
Function C2M_SidebarShow
  Pop $0
  ${IfThen} $0 = 0 ${|} Return ${|}
  ${IfNot} ${FileExists} "$PLUGINSDIR\art\side.bmp"
    Return
  ${EndIf}
  System::Call '*(i, i, i, i)p.r1'
  System::Call 'user32::GetClientRect(p r0, p r1)'
  System::Call '*$1(i, i, i.r2, i.r3)'
  System::Free $1
  ${IfThen} $2 = 0 ${|} Return ${|}

  !insertmacro C2M_LoadBitmap "$PLUGINSDIR\art\side.bmp" $2 $3 $C2M_SideBmp
  SendMessage $0 ${STM_SETIMAGE} ${IMAGE_BITMAP} $C2M_SideBmp $5

  ; Let the animation sit above the sidebar without being painted over.
  System::Call 'user32::GetWindowLong(p r0, i -16)i.r6'
  IntOp $6 $6 | 0x04000000 ; WS_CLIPSIBLINGS
  System::Call 'user32::SetWindowLong(p r0, i -16, i r6)'

  ; Animated area, scaled to the control's real size.
  IntOp $6 ${C2M_RX0} * $2
  IntOp $6 $6 / 164
  IntOp $7 ${C2M_RY0} * $3
  IntOp $7 $7 / 314
  IntOp $8 ${C2M_RX1} * $2
  IntOp $8 $8 / 164
  IntOp $C2M_AnimW $8 - $6
  IntOp $8 ${C2M_RY1} * $3
  IntOp $8 $8 / 314
  IntOp $C2M_AnimH $8 - $7

  nsDialogs::CreateControl STATIC ${WS_CHILD}|${WS_VISIBLE}|${SS_BITMAP} 0 $6 $7 $C2M_AnimW $C2M_AnimH ""
  Pop $C2M_Anim
  System::Call 'user32::SetWindowPos(p $C2M_Anim, p 0, i 0, i 0, i 0, i 0, i 0x13)'

  StrCpy $C2M_Frame 0
  StrCpy $C2M_FrameBmp 0
  Call C2M_Tick
  GetFunctionAddress $0 C2M_Tick
  nsDialogs::CreateTimer $0 ${C2M_FRAME_MS}
FunctionEnd

Function C2M_Tick
  ${IfThen} $C2M_Anim = 0 ${|} Return ${|}
  IntFmt $0 "%02d" $C2M_Frame
  !insertmacro C2M_LoadBitmap "$C2M_Prefix$0.bmp" $C2M_AnimW $C2M_AnimH $1
  ${If} $1 <> 0
    SendMessage $C2M_Anim ${STM_SETIMAGE} ${IMAGE_BITMAP} $1 $2
    ${If} $C2M_FrameBmp <> 0
      System::Call 'gdi32::DeleteObject(p $C2M_FrameBmp)'
    ${EndIf}
    StrCpy $C2M_FrameBmp $1
  ${EndIf}
  IntOp $C2M_Frame $C2M_Frame + 1
  ${If} $C2M_Frame >= ${C2M_FRAMES}
    StrCpy $C2M_Frame 0
  ${EndIf}
FunctionEnd

Function C2M_SidebarDestroyed
  GetFunctionAddress $0 C2M_Tick
  nsDialogs::KillTimer $0
  StrCpy $C2M_Anim 0
  ${If} $C2M_FrameBmp <> 0
    System::Call 'gdi32::DeleteObject(p $C2M_FrameBmp)'
    StrCpy $C2M_FrameBmp 0
  ${EndIf}
  ${If} $C2M_SideBmp <> 0
    System::Call 'gdi32::DeleteObject(p $C2M_SideBmp)'
    StrCpy $C2M_SideBmp 0
  ${EndIf}
FunctionEnd

Function C2M_WelcomeShow
  Push $mui.WelcomePage.Image
  Call C2M_SidebarShow
FunctionEnd

Function C2M_FinishShow
  Push $mui.FinishPage.Image
  Call C2M_SidebarShow
FunctionEnd
