' SystemBoost - make-shortcuts.vbs
' Usage:  cscript //nologo make-shortcuts.vbs <target.bat> <desktop.lnk> <programs.lnk>
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")

target = WScript.Arguments(0)
desktop = WScript.Arguments(1)
programs = WScript.Arguments(2)

' Desktop shortcut
If fso.FileExists(target) Then
    Set sc = shell.CreateShortcut(desktop)
    sc.TargetPath = target
    sc.WorkingDirectory = fso.GetParentFolderName(target)
    sc.IconLocation = "shell32.dll,13"
    sc.Description = "SystemBoost - free space & speed up Windows"
    sc.Save
End If

' Start menu shortcut
If fso.FileExists(target) Then
    Set sc2 = shell.CreateShortcut(programs)
    sc2.TargetPath = target
    sc2.WorkingDirectory = fso.GetParentFolderName(target)
    sc2.IconLocation = "shell32.dll,13"
    sc2.Description = "SystemBoost - free space & speed up Windows"
    sc2.Save
End If
