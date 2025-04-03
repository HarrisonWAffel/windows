#  This tool is super useful but it needs to be installed as the final step in
#  the bootstrapping process since it takes a while get set up ( > 10 mins)
Write-Host "Installing SQL Server Management UI, the SQL server can still be used during this operation. This is will take a while."
cd ~
Write-Host "Downloading instllation exe"
wget "https://aka.ms/ssmsfullsetup" -usebasicparsing -outfile smss-install.exe
Write-Host "Download complete, starting install"
./smss-install.exe /passive
Write-Host "Installation complete"