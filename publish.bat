@echo off
cd /D G:\Data\Git\affaireconclue-source
echo Running Hugo build...
hugo
echo Uploading files via SCP...
scp -i "C:\Users\idris\.ssh\id_ed25519-affaireconclue" -r public samwise@192.168.50.61:~/caddy_setup/
echo Moving files on server via SSH...
ssh -i "C:\Users\idris\.ssh\id_ed25519-affaireconclue" samwise@192.168.50.61 "cd ~/caddy_setup && rm -rf site/* && mv public/* site/ && rmdir public"
echo Deployment complete.
pause