@echo off
set "PROTOC=C:\protoc-25.1-win64\bin\protoc.exe"
set PATH=%PATH%;C:\Windows\System32;C:\Windows\System32\WindowsPowerShell\v1.0;C:\Users\Admin\.rustup\toolchains\stable-x86_64-pc-windows-msvc\bin
cd backend
cargo run
