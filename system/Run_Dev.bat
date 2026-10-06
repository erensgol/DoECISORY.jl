@echo off

REM Set working directory to project root
cd /d "%~dp0.."

powershell.exe -ExecutionPolicy Bypass -File "%~dp0Rev_Dev.ps1"

PAUSE 