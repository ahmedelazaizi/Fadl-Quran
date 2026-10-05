param([string]$name)
$adb = "D:\dev-cache\android-sdk\platform-tools\adb.exe"
& $adb -s emulator-5554 shell screencap -p /sdcard/s.png
& $adb -s emulator-5554 pull /sdcard/s.png "$PSScriptRoot\$name.png" 2>&1 | Out-Null
"$PSScriptRoot\$name.png"
