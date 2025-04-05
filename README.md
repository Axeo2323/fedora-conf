# fedora-config
My fedora config (from Fedora Workstation). Configure & Update Fedora

**Works only for Fedora Workstation with GNOME desktop environment.**



## File :

 **config-fedora.sh** : Script

 **gnome.list** : file to add or remove gnome extensions

 **packages.list** : file to add or remove rpm packages

 **flatpak.list** : file to add or remove flatpaks


 
## Usage :

All files need to be in the same directory !!
*If you want to activate MacBook driver, uncomment the coppr repository in config-fedora.sh and packages in packages.list*

Execute with sudo the script :

    ./config-fedora.sh

This can be executed multiple times in a row. If steps are already configured, they will not be configured again. In fact, the script can be used to :
- Perform the initial system configuration
- Update the system configuration
- Carry out package updates

It is possible to perform only a check for updates (listing the packages and flatpaks to be updated without applying any changes) using the check option :

    ./config-fedora.sh check
  
It is possible to get an overview of the available updates in the 'testing' repositories using the testing option :

    ./config-fedora.sh testing

 
