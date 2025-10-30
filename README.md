# TwinCAT/BSD & TwinCAT/Linux Scripts
*(French text below)*
Here are some useful scripts for Beckhoff's TC/BSD and TC/LUR operating systems to help install and configure TwinCAT functions.
The scripts are designed with French customers in mind. Feel free to fork this to tailor to your use.
It is assumed for each script to be executed in `/home/Administrator` :

**For TC/BSD :**

    cd
    doas chmod +x <name of script>.sh
    doas sh <name of script>.sh

**For TC/LUR :**

    cd
    sudo chmod +x <name of script>.bash
    sudo bash <name of script>.bash

## Roadmap

### TwinCAT/BSD
- [x] TF1200 and Sway Installation and configuration script
	- [x] Standalone
	- [x] With TF2000 TwinCAT HMI 1.12
	- [x] With TF2000 TwinCAT HMI 1.14
	- [x] With TF1810 PLC HMI Web 
- [x] TF6250 Modbus/TCP Installation and configuration script
- [x] eGalax Touchscreen support script
- [ ] ... Possibly more to come (including offline versions)

### TwinCAT/LUR
- [x] Beckhoff IPC configuration script (with apt authentication and TwinCAT XAR installation)
- [x] TF1200 and Sway Installation and configuration script
	- [x] Standalone
	- [x] With TF2000 TwinCAT HMI 1.14
	- [x] With TF1810 PLC HMI Web
- [x] TF6250 Modbus/TCP Installation and configuration script
- [x] Static IP Setter script
- [x] Automount removable devices script
- [x] DEB Packages download script
	- [x] Offline DEB packages install script
- [ ] Docker installation script with TwinCAT XAR container deployment 
- [ ] ... Possibly more to come (including offline versions)

These are not official Beckhoff material.

---
Voici plusieurs scripts utiles pour les systèmes d'exploitation de Beckhoff TC/BSD et TC/LUR pour l'installation et la configuration de fonctions TwinCAT.
Il est supposé que chaque script est exécuté dans le dossier `/home/Administrator` :

**Pour TC/BSD :**

    cd
    doas chmod +x <nom du script>.sh
    doas sh <nom du script>.sh

**Pour TC/LUR :**

    cd
    sudo chmod +x <nom du script>.bash
    sudo bash <nom du script>.bash

## Feuille de route

### TwinCAT/BSD
- [x] Script d'installation et de configuration pour TF1200 et Sway
	- [x] Seuls
	- [x] Avec TF2000 TwinCAT HMI 1.12
	- [x] Avec TF2000 TwinCAT HMI 1.14
	- [x] Avec TF1810 PLC HMI Web 
- [x] Script d'installation et de configuration pour TF6250 Modbus/TCP
- [x] Script d'activation du support pour écran tactile eGalax
- [ ] ... Potentiellement davantage à venir (y compris des versions hors-ligne)

### TwinCAT/LUR
- [x] Script de configuration de l'IPC Beckhoff (authentification pour apt, installation de TwinCAT XAR, clavier en français, heure de Paris)
- [x] Script d'installation et de configuration pour TF1200 et Sway
	- [x] Seuls
	- [x] Avec TF2000 TwinCAT HMI 1.14
	- [x] Avec TF1810 PLC HMI Web
- [x] Script d'installation et de configuration pour TF6250 Modbus/TCP
- [x] Script d'affectation d'une adresse IP fixe
- [x] Script d'activation du montage automatique des périphériques amovibles
- [x] Script de téléchargement de paquets au format DEB
	- [x] Script d'installation hors-ligne de paquets DEB
- [ ] Script pour l'installation de Docker et le déploiement d'un conteneur TwinCAT XAR 
- [ ] ... Potentiellement davantage à venir (y compris des versions hors-ligne)

Il ne s'agit pas de scripts ou documents officiels de Beckhoff.

