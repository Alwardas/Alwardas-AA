@echo off
echo Generating Dart gRPC code...
if not exist "frontend\lib\core\services\grpc" mkdir "frontend\lib\core\services\grpc"

REM Ensure consistent protoc_plugin version (matching pubspec.yaml)
call flutter pub global activate protoc_plugin 21.1.2

REM Add Pub Cache to PATH temporarily for this script
set PATH=%PATH%;C:\Users\saket\AppData\Local\Pub\Cache\bin

REM Generate
protoc --dart_out=grpc:frontend/lib/core/services/grpc -Iprotos protos/auth.proto

echo Done.
