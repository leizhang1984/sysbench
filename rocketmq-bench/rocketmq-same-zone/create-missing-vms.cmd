@echo off
setlocal EnableExtensions

set SUB=166157a8-9ce9-400b-91c7-1d42482b83d6
set RG=rocketmqnew1-rg
set IMG=resf:rockylinux-x86_64:9-base:latest
set SIZE=Standard_D4s_v6
set USER=azureadmin
set PASS=Zhanglei@123456

call az account set --subscription %SUB% >nul

call :ensure_vm broker-a-1 1
call :ensure_vm broker-b-0 2
call :ensure_vm broker-b-1 2
call :ensure_vm broker-c-0 3
call :ensure_vm broker-c-1 3

echo === VM create pass done ===
call az vm list -d -g %RG% --query "[].{name:name,power:powerState,ip:privateIps,zone:zones[0]}" -o table
exit /b 0

:ensure_vm
set VM=%~1
set ZONE=%~2
set NIC=%VM%-nic

call az vm show --only-show-errors -g %RG% -n %VM% -o none >nul 2>nul
if %errorlevel%==0 (
  echo exists %VM%
  exit /b 0
)

echo creating %VM% zone=%ZONE%
call az vm create --only-show-errors -g %RG% -n %VM% --image %IMG% --size %SIZE% --zone %ZONE% --nics %NIC% --admin-username %USER% --admin-password %PASS% --authentication-type password --security-type Standard --os-disk-name %VM%-osdisk -o none
if not %errorlevel%==0 (
  echo create failed %VM%
  exit /b 1
)

echo created %VM%
exit /b 0
