@echo off
echo Generating Dart gRPC code...
if not exist "frontend\lib\core\services\grpc" mkdir "frontend\lib\core\services\grpc"

REM Temporarily add system, git, flutter, and pub paths for this script execution
set PATH=%PATH%;C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Program Files\Git\cmd;C:\src\flutter\bin;%LOCALAPPDATA%\Pub\Cache\bin

REM Ensure consistent protoc_plugin version (matching pubspec.yaml)
call flutter pub global activate protoc_plugin 21.1.2

REM Add Pub Cache to PATH temporarily for this script
set PATH=%PATH%;%LOCALAPPDATA%\Pub\Cache\bin

REM Generate
C:\protoc-25.1-win64\bin\protoc.exe --dart_out=grpc:frontend/lib/core/services/grpc -Iprotos protos/auth.proto

echo Done.
