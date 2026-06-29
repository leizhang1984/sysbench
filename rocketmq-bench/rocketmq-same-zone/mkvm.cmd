@echo off
setlocal
set SUB=166157a8-9ce9-400b-91c7-1d42482b83d6
set RG=rocketmqnew1-rg
set IMG=resf:rockylinux-x86_64:9-base:latest
set SIZE=Standard_D4s_v6
set USER=azureadmin
set PASS=
set VM=%~1
set ZONE=%~2
echo [%DATE% %TIME%] creating %VM% zone=%ZONE%
az vm create --subscription %SUB% --only-show-errors -g %RG% -n %VM% --image %IMG% --size %SIZE% --zone %ZONE% --nics %VM%-nic --admin-username %USER% --admin-password %PASS% --authentication-type password --security-type Standard --os-disk-name %VM%-osdisk -o json
echo [%DATE% %TIME%] exit=%errorlevel% for %VM%
