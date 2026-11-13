# AP1 – Conception et mise en place du système d'information

> **Auteur :** à compléter · **Équipe :** Fahim, Xavier, Thibaut, Yan, Minkaïl, Josh, Loïc
> **Lien du document d'équipe :** [Google Doc](https://docs.google.com/document/d/1uzg1LrKosBu0Vjc0rLZ8w45wVeWYX_9jS01Ql7LhjQs/edit?usp=sharing)

## Sommaire

1. [Contexte et objectifs](#1-contexte-et-objectifs)
2. [Infrastructure](#2-infrastructure)
3. [Plan d'adressage](#3-plan-dadressage)
4. [Répartition des tâches](#4-répartition-des-tâches)
5. [Mise en œuvre](#5-mise-en-œuvre)
6. [Tests et validation](#6-tests-et-validation)
7. [Gestion des secrets](#7-gestion-des-secrets)
8. [Bilan](#8-bilan)

---

## 1. Contexte et objectifs

**Contexte :** laboratoire pharmaceutique **RedOne**, siège Europe à Paris (voir [CONTEXTE_RedOne.md](../CONTEXTE_RedOne.md)). Le SI est segmenté en VLAN par service, avec des données stratégiques (aucune fuite ni perte tolérée). Le service Réseau & Système doit fournir l'infrastructure qui hébergera les applications de la flotte de visiteurs médicaux.

Mettre en place, en équipe, le socle du système d'information de RedOne sur un hyperviseur Proxmox partagé :

- segmentation réseau par VLAN, routée et filtrée par **pfSense** ;
- annuaire **Active Directory** avec les groupes de la section ;
- gestion de parc **GLPI** ;
- préparation des briques de supervision et de sécurité exploitées en AP2 (Zabbix / Grafana, Wazuh).

Chaque étudiant dispose d'une plage d'adresses, de VLAN ID et de VMID réservée pour éviter les conflits sur l'infrastructure commune.

## 2. Infrastructure

| Élément | Adresse | Remarque |
|---|---|---|
| Interface web Proxmox | `192.168.100.2` | Accès administrateur (realm `Linux`/PAM) |
| pfSense | `10.0.1.251` | **À passer en IP statique** (validé avec Fahim) |

Schéma réseau : `captures/schema_reseau.png` *(réalisé par Fahim, à ajouter)*

## 3. Plan d'adressage

### 3.1 Services communs

| Service | IP | VLAN ID | VMID Proxmox |
|---|---|---|---|
| Active Directory | `192.168.100.2` | 100 – 199 | 100 – 199 |
| GLPI | `192.168.100.50` | 100 – 199 | 100 – 199 |
| Wazuh | `10.1.0.4` | 100 – 199 | 100 – 199 |
| pfSense | `10.1.0.15` | 100 – 199 | 100 – 199 |
| Grafana / Zabbix | `10.1.0.5` | 100 – 199 | 100 – 199 |

> [!WARNING]
> **Incohérences à lever avant le rendu** (supprimer cet encadré une fois corrigé) :
> - pfSense apparaît en `10.0.1.251` (section 2) et en `10.1.0.15` (tableau ci-dessus) : préciser s'il s'agit de deux interfaces (WAN / LAN) ou d'une erreur.
> - Zabbix est noté en `192.168.100.133` dans les notes et en `10.1.0.5` dans le tableau.
> - `192.168.100.2` est attribuée à la fois à Proxmox et à l'AD : une seule machine peut avoir cette adresse.

### 3.2 Plages réservées par étudiant

| Étudiant | Réseaux internes | VLAN ID | VMID Proxmox |
|---|---|---|---|
| Fahim | `10.2.1.0/24` → `10.2.20.0/24` | 200 – 299 | 200 – 299 |
| Xavier | `10.2.21.0/24` → `10.2.40.0/24` | 300 – 399 | 300 – 399 |
| Thibaut | `10.2.41.0/24` → `10.2.60.0/24` | 400 – 499 | 400 – 499 |
| Yan | `10.2.61.0/24` → `10.2.80.0/24` | 500 – 599 | 500 – 599 |
| Minkaïl | `10.2.81.0/24` → `10.2.100.0/24` | 600 – 699 | 600 – 699 |
| Josh | `10.2.101.0/24` → `10.2.120.0/24` | 700 – 799 | 700 – 799 |
| Loïc | `10.2.121.0/24` → `10.2.140.0/24` | 800 – 899 | 800 – 899 |

Convention : le VLAN ID et le VMID d'une machine sont pris dans la plage de son propriétaire (ex. Thibaut : VLAN 410, VM 410).

## 4. Répartition des tâches

| Tâche | Responsable(s) | État |
|---|---|---|
| Création des groupes AD `BTS SIO1`, `SLAM`, `SISR` | Yan, Thibaut | ⏳ En cours |
| Schéma réseau | Fahim | ⏳ En cours |
| Création des VLAN sur pfSense | Xavier, Loïc | ✅ Terminé |
| IP statique pfSense | Fahim | ⏳ À faire |

## 5. Mise en œuvre

### 5.1 VLAN sur pfSense

1. *Interfaces → Assignments → VLANs → Add* : interface parente, VLAN tag (dans la plage réservée), description.
2. *Interfaces → Assignments* : affecter chaque VLAN à une interface, l'activer et lui donner une IP statique (passerelle du sous-réseau).
3. *Services → DHCP Server* : activer le DHCP par VLAN si nécessaire.
4. *Firewall → Rules* : créer les règles d'autorisation inter-VLAN.

Captures : `captures/pfsense_vlans.png`, `captures/pfsense_rules.png`

### 5.2 Active Directory – groupes de la section

```powershell
New-ADOrganizationalUnit -Name "BTS_SIO"
New-ADGroup -Name "BTS SIO1" -GroupScope Global -Path "OU=BTS_SIO,DC=domaine,DC=local"
New-ADGroup -Name "SLAM"     -GroupScope Global -Path "OU=BTS_SIO,DC=domaine,DC=local"
New-ADGroup -Name "SISR"     -GroupScope Global -Path "OU=BTS_SIO,DC=domaine,DC=local"
```

> Remplacer `DC=domaine,DC=local` par le nom réel du domaine.

### 5.3 Autoriser le ping sur les serveurs Windows

Par défaut, le pare-feu Windows bloque l'ICMP entrant. Pour les tests de connectivité :

```powershell
Get-NetFirewallRule -DisplayName "Diagnostics de réseau de base - Demande d'écho ICMP (ICMPv4-Entrant)" | Enable-NetFirewallRule
```

### 5.4 GLPI

*À compléter : installation, connexion à l'AD (LDAP), inventaire des postes.*

## 6. Tests et validation

| # | Test | Commande / méthode | Résultat attendu | Résultat obtenu | ✅/❌ |
|---|---|---|---|---|---|
| 1 | Accès à l'interface Proxmox | navigateur → `https://192.168.100.2:8006` | Page de connexion | | |
| 2 | Ping inter-VLAN via pfSense | `ping` depuis une VM de chaque VLAN | Réponse | | |
| 3 | Ping d'un serveur Windows | `ping <IP serveur>` | Réponse après activation de la règle ICMP | | |
| 4 | Groupes AD présents | `Get-ADGroup -Filter 'Name -like "*S*"'` | `BTS SIO1`, `SLAM`, `SISR` | | |
| 5 | Accès GLPI | navigateur → `http://192.168.100.50` | Page de connexion GLPI | | |
| 6 | IP statique pfSense | redémarrage pfSense puis vérification de l'IP | IP inchangée | | |

## 7. Gestion des secrets

Aucun identifiant n'est stocké dans ce dépôt. Les comptes d'administration (Proxmox, pfSense, Zabbix, AD) sont conservés dans le gestionnaire de mots de passe de l'équipe.

Bonnes pratiques appliquées :

- changement des mots de passe par défaut dès l'installation ;
- un compte nominatif par administrateur plutôt que le compte `root` partagé ;
- captures d'écran vérifiées avant commit.

## 8. Bilan

*À compléter : difficultés rencontrées, solutions, compétences mobilisées (bloc 1 / bloc 2 SISR).*
