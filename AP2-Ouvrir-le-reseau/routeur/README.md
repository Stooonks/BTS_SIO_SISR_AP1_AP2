# Configuration du routeur R-REDONE (Cisco C1111-4P)

Fichiers de commandes IOS, appliqués dans l'ordre par la console (`cisco-cmd.ps1 -Fichier <fichier>`), commentés ligne par ligne. Explications complètes : [dossier de l'AP2](../README.md).

| Fichier | Contenu |
|---|---|
| [`00-etat-des-lieux-avant.txt`](00-etat-des-lieux-avant.txt) | Relevé de départ (`show version`, `show running-config`, `show ip ssh`) : aucun mot de passe, SSH désactivé |
| [`01-securisation.txt`](01-securisation.txt) | Comptes, SSH v2, ACL d'administration, blocage des attaques, bannière, journal des modifications |
| [`02-reseau-et-journaux.txt`](02-reseau-et-journaux.txt) | Adresse d'administration `192.168.100.212` (G0/0/0), journaux vers Wazuh, ports inutilisés éteints |
| [`03-snmpv3-zabbix.txt`](03-snmpv3-zabbix.txt) | Supervision Zabbix en SNMPv3 authPriv (clés insérées à l'envoi, jamais dans le dépôt) |
| [`04-ntp.txt`](04-ntp.txt) | Heure synchronisée (AD et pfSense) |
| [`05-visiteurs.txt`](05-visiteurs.txt) | Première version du réseau Visiteurs (VLAN 202), **remplacée** par 07 et 08 |
| [`06-compte-sauvegarde.txt`](06-compte-sauvegarde.txt) | Compte `svc-sauvegarde` par clé SSH (clé publique de SRV-VEEAM) |
| [`07-visiteurs-g001.txt`](07-visiteurs-g001.txt) | Réseau Visiteurs sur le port routé G0/0/1 (`10.2.3.0/24`) |
| [`08-visiteurs-switch.txt`](08-visiteurs-switch.txt) | Réseau Visiteurs sur les 4 prises du switch, VLAN 150 (`10.2.4.0/24`), journal des connexions |
| [`09-journaux-loki.txt`](09-journaux-loki.txt) | Journaux envoyés aussi à SRV-SUPERVISION (Loki, conservés 1 an) |
| [`running-config-final.txt`](running-config-final.txt) | Configuration finale (mots de passe chiffrés masqués), issue de la sauvegarde automatique |
| [`console-cisco.ps1`](console-cisco.ps1) | Terminal série interactif (remplace PuTTY), 9600 bauds |
| [`cisco-cmd.ps1`](cisco-cmd.ps1) | Envoi d'un fichier de commandes par la console, en attendant l'invite après chaque commande |
