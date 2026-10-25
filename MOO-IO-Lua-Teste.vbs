' Opt-in launcher for testing the LOCAL Lua server. Original MOO-IO.vbs stays Node.
Option Explicit
Dim sh, fso, folder, cmd
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
folder = fso.GetParentFolderName(WScript.ScriptFullName)
sh.Environment("PROCESS")("MOO_IO_LOCAL_SERVER_RUNTIME") = "lua"
cmd = "wscript.exe //nologo " & Chr(34) & folder & "\MOO-IO.vbs" & Chr(34)
sh.Run cmd, 1, False
