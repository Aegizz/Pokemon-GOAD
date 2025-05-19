<div align="center">
  <h1><img alt="GOAD (Game Of Active Directory)" src="./docs/mkdocs/docs/img/logo_GOAD3.png"></h1>
  <br>
</div>

**GOAD (v3)**

:bookmark: Documentation : [https://orange-cyberdefense.github.io/GOAD/](https://orange-cyberdefense.github.io/GOAD/)

## Description
GOAD is a pentest active directory LAB project.
The purpose of this lab is to give pentesters a vulnerable Active directory environment ready to use to practice usual attack techniques.

> [!CAUTION]
> This lab is extremely vulnerable, do not reuse recipe to build your environment and do not deploy this environment on internet without isolation (this is a recommendation, use it as your own risk).<br>
> This repository was build for pentest practice.

![goad_screenshot](./docs/img/goad_screenshot.png)

## Licenses
This lab use free Windows VM only (180 days). After that delay enter a license on each server or rebuild all the lab (may be it's time for an update ;))

## Available labs

- POKE - Created by Aegizz. 3 Domains, 1 Server and a Forest Root. 

Important notes for configuration. 
 - Sometimes you'll need to manaully configure the NAT or DNS (Host-only) adapters. (Just enable them and set the primary DNS server to the pokemon.local IP). 
  - The other key issue is the networking, when deploying to a CTF environment since this runs on a Host-Only adapter + NAT, external users cannot access it. Either configure a Bridge Adapter for each VM post deployment via a script, or configure a JumpBox for users to access.
  - Only tested environment is virtualbox. I added configuration for vmware & ESXI (good luck!).




### GOAD Lab family and extensions overview
<div align="center">
<img alt="GOAD" width="800" src="./docs/img/diagram-GOADv3-full.png">
</div>

- [GOAD](https://orange-cyberdefense.github.io/GOAD/labs/GOAD/) : 5 vms, 2 forests, 3 domains (full goad lab)
<div align="center">
<img alt="GOAD" width="800" src="./docs/img/GOAD_schema.png">
</div>

- [GOAD-Light](https://orange-cyberdefense.github.io/GOAD/labs/GOAD-Light/) : 3 vms, 1 forest, 2 domains (smaller goad lab for those with a smaller pc)
<div align="center">
<img alt="GOAD Light" width="600" src="./docs/img/GOAD-Light_schema.png">
</div>

- [MINILAB](https://orange-cyberdefense.github.io/GOAD/labs/MINILAB/): 2 vms, 1 forest, 1 domain (basic lab with one DC (windows server 2019) and one Workstation (windows 10))

- [SCCM](https://orange-cyberdefense.github.io/GOAD/labs/SCCM/) : 4 vms, 1 forest, 1 domain, with microsoft configuration manager installed
<div align="center">
<img alt="SCCM" width="600" src="./docs/img/SCCMLAB_overview.png">
</div>

- [NHA](https://orange-cyberdefense.github.io/GOAD/labs/NHA/) : A challenge with 5 vms and 2 domains. no schema provided, you will have to find out how break it.


