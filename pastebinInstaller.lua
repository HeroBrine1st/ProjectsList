print("Downloading installer...")
os.execute("wget https://raw.githubusercontent.com/HeroBrine1st/UniversalInstaller/master/installer.lua /tmp/installer.lua -f -q")
print("Running:")
os.execute("/tmp/installer.lua")