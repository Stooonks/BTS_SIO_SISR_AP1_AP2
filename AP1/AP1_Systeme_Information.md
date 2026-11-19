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

L'adressage de la maquette reprend le plan VLAN du cahier des charges RedOne (voir [CONTEXTE_RedOne.md](../CONTEXTE_RedOne.md#3-segmentation-réseau-vlan)). Le commutateur de niveau 3 **MUTLAB**, qui fait le routage inter-VLAN avec des ACL chez RedOne, est remplacé dans la maquette par **pfSense** (routage inter-VLAN + règles de pare-feu).

> [!NOTE]
> **Proposition à valider avec l'équipe** (Xavier et Loïc pour les VLAN déjà créés sur pfSense). Supprimer cet encadré une fois le plan validé et appliqué.

### 3.1 VLAN RedOne et correspondance dans la maquette

Les VLAN ID RedOne (10 à 400) chevauchent les plages réservées aux étudiants sur le Proxmox partagé (200 à 899). Dans la maquette, chaque VLAN RedOne est donc renuméroté dans la plage commune **100 – 199**, avec la règle **VLAN maquette = 100 + VLAN RedOne / 10**.

| VLAN RedOne | VLAN maquette | Service(s) | Réseau | Passerelle (pfSense) |
|---|---|---|---|---|
| 10 | 101 | Réseau & Système | `192.168.10.0/24` | `192.168.10.254` |
| 20 | 102 | Direction / DSI | `192.168.20.0/24` | `192.168.20.254` |
| 30 | 103 | RH / Compta / Juridique / Secrétariat | `192.168.30.0/24` | `192.168.30.254` |
| 40 | 104 | Communication / Rédaction | `192.168.40.0/24` | `192.168.40.254` |
| 50 | 105 | Développement | `192.168.50.0/24` | `192.168.50.254` |
| 60 | 106 | Commercial | `192.168.60.0/24` | `192.168.60.254` |
| 70 | 107 | Labo-Recherche | `192.168.70.0/24` | `192.168.70.254` |
| 100 | 110 | Accueil | `192.168.110.0/24` ⚠️ | `192.168.110.254` |
| 150 | 115 | Visiteurs | `192.168.150.0/24` | `192.168.150.254` |
| 200 | 120 | Démonstration | `192.168.200.0/24` | `192.168.200.254` |
| 300 | 130 | Serveurs | `172.16.0.0/17` | `172.16.127.254` |
| 400 | 140 | Sortie (vers le WAN) | `172.18.0.0/30` | `172.18.0.1` (pfSense) / `172.18.0.2` (routeur de sortie) |

⚠️ **Seul écart avec RedOne :** le réseau `192.168.100.0/24` du VLAN Accueil est déjà utilisé par le réseau d'administration de la salle (interface Proxmox). Dans la maquette, le VLAN Accueil passe donc en `192.168.110.0/24`.

### 3.2 Serveurs (VLAN Serveurs – `172.16.0.0/17`)

| Service | IP cible RedOne | IP actuelle (maquette) | VMID |
|---|---|---|---|
| pfSense (interface Serveurs) | `172.16.127.254` | `10.1.0.15` | 100 – 199 |
| Active Directory / DNS / DHCP | `172.16.0.1` | `192.168.100.2` ⚠️ | 100 – 199 |
| GLPI (VM 208 SRV-GLPI) | `172.16.0.50` | `192.168.100.208` | 208 |
| Wazuh | `172.16.0.4` | `10.1.0.4` | 100 – 199 |
| Zabbix / Grafana | `172.16.0.5` | `10.1.0.5` (ou `192.168.100.133`, à confirmer) | 100 – 199 |

Les serveurs migrent de l'**IP actuelle** vers l'**IP cible** au fur et à mesure. Le DHCP de chaque VLAN utilisateur est relayé par pfSense vers l'AD (*Services → DHCP Relay*) ou servi directement par pfSense.

> [!WARNING]
> **Incohérences relevées dans l'existant** (supprimer cet encadré une fois corrigé) :
> - pfSense est noté en `10.0.1.251` (section 2) et en `10.1.0.15` : vérifier s'il s'agit de deux interfaces (WAN / LAN).
> - `192.168.100.2` est attribuée à la fois à Proxmox et à l'AD : une seule machine peut avoir cette adresse.

### 3.3 Hors plan RedOne

| Réseau | Usage |
|---|---|
| `192.168.100.0/24` | Administration de la salle : interface web Proxmox (`192.168.100.2`) |
| `10.0.1.0/24` | Côté WAN de pfSense (`10.0.1.251`, à passer en statique) |

### 3.4 Plages réservées par étudiant (tests personnels)

Ces plages servent aux VM de test de chaque étudiant, en dehors de l'infrastructure RedOne commune.

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

1. *Interfaces → Assignments → VLANs → Add* : interface parente, tag = **VLAN maquette** (tableau 3.1), description = nom du service RedOne (ex. `V101_RESEAU_SYSTEME`).
2. *Interfaces → Assignments* : affecter chaque VLAN à une interface, l'activer et lui donner l'IP de passerelle du tableau 3.1.
3. *Services → DHCP Server* (ou *DHCP Relay* vers l'AD) : un pool par VLAN utilisateur.
4. *Firewall → Aliases* : créer `NET_SERVEURS` (`172.16.0.0/17`), `SRV_DNS_DHCP` (IP de l'AD) et `RFC1918` (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`).
5. *Firewall → Rules* : appliquer les règles RedOne ci-dessous.

#### Règles de filtrage RedOne (remplacent les ACL du commutateur MUTLAB)

| Interface | # | Action | Source | Destination | Port | Rôle |
|---|---|---|---|---|---|---|
| VLAN 101 à 120 (sauf 115) | 1 | Pass | réseau du VLAN | `NET_SERVEURS` | tous | Accès aux serveurs |
| VLAN 101 à 120 (sauf 115) | 2 | Pass | réseau du VLAN | ! `RFC1918` | tous | Sortie Internet (VLAN Sortie) |
| VLAN 101 à 120 (sauf 115) | 3 | Block | réseau du VLAN | tous | tous | Pas d'accès aux autres VLAN |
| VLAN 115 Visiteurs | 1 | Pass | réseau du VLAN | `SRV_DNS_DHCP` | 53 TCP/UDP, 67-68 UDP | DNS et DHCP uniquement |
| VLAN 115 Visiteurs | 2 | Pass | réseau du VLAN | ! `RFC1918` | tous | Internet uniquement |
| VLAN 115 Visiteurs | 3 | Block | réseau du VLAN | tous | tous | Isolement complet |
| VLAN 130 Serveurs | 1 | Pass | `NET_SERVEURS` | tous | tous | Réponses et mises à jour |

> pfSense lit les règles de haut en bas et applique la première qui correspond : l'ordre est important.

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

### 5.4 GLPI – gestion de parc et du support

GLPI répond au besoin RedOne d'**uniformiser le suivi** : tickets d'incidents et de demandes, inventaire du parc (postes du siège et portables des visiteurs médicaux) et rattachement des équipements aux services.

#### Machine virtuelle

| Paramètre | Valeur |
|---|---|
| VM Proxmox | **208 – SRV-GLPI** (plage VMID 200–299), tags `ap1`, `glpi`, `redone` |
| Système | Debian 13 (image cloud, déploiement cloud-init) |
| Ressources | 2 vCPU, 4 Go RAM, 32 Go (stockage `Raid5-VMs`) |
| Réseau | `vmbr0`, IP fixe `192.168.100.208/24`, passerelle `192.168.100.1` |
| Accès | `http://192.168.100.208` – SSH par clé uniquement (compte `sysadmin`, pas de mot de passe) |

> Le VLAN 200 (`vmbr2`) n'étant pas routé depuis le poste d'administration au moment de l'installation, la VM est placée sur le réseau d'administration de la salle. Cible RedOne : VLAN Serveurs, `172.16.0.50` (tableau 3.2).

#### Pile logicielle

| Composant | Version |
|---|---|
| GLPI | 12.0.2 |
| Apache | 2.4 (racine web limitée à `/var/www/glpi/public`, `mod_rewrite`) |
| PHP | 8.4 (`mod_php`, extensions mysql, intl, ldap, gd, curl, zip, bz2, bcmath, opcache, apcu) |
| MariaDB | 11.8 (base `glpi` en `utf8mb4`, utilisateur dédié limité à cette base, fuseaux horaires chargés) |
| node_exporter | supervision par Prometheus (port 9100, voir AP2) |

#### Sécurisation appliquée

| Mesure | Détail |
|---|---|
| Racine web restreinte | Seul `public/` est exposé : config, données et journaux ne sont pas accessibles par HTTP (vérifié : HTTP 404) |
| Arborescence séparée | Configuration dans `/etc/glpi`, données dans `/var/lib/glpi`, journaux dans `/var/log/glpi` (propriétaire `www-data`, droits 750) ; code en lecture seule (propriétaire `root`) |
| Assistant d'installation supprimé | `install/install.php` supprimé après installation (vérifié : HTTP 404) |
| Comptes par défaut neutralisés | `glpi`, `tech`, `normal`, `post-only` : mot de passe aléatoire **et** compte désactivé |
| Comptes nominatifs | `admin.redone` (Super-Admin, groupe DSI), `tech.reseau` (Technicien, groupe Réseau & Système), `visiteur.demo` (Self-Service, groupe Visiteurs médicaux) – mots de passe forts générés, conservés hors dépôt |
| Base de données | Mot de passe aléatoire de 24 caractères, utilisateur limité à la base `glpi` |
| Cookies de session | `HttpOnly` et `SameSite=Lax` |
| Apache | `ServerTokens Prod`, `ServerSignature Off` (la version n'est pas divulguée) |
| Tâches automatiques | Cron système toutes les minutes (`/etc/cron.d/glpi`) |

#### Référentiel RedOne chargé

| Élément | Contenu |
|---|---|
| Entité | **RedOne** (siège Europe, Paris) |
| Lieux | Paris - Siège › 6e étage - Salle serveur, Salles de réunion, Salle Démonstration, Accueil ; Terrain - Visiteurs médicaux |
| Groupes | DSI › Réseau & Système, Développement ; Direction ; RH / Compta / Juridique ; Communication / Rédaction ; Commercial ; Labo-Recherche ; Visiteurs médicaux (alignés sur les VLAN) |
| Catégories de tickets (16) | Matériel (poste, portable visiteur, imprimante, serveur) ; Réseau (accès / VLAN, Wi-Fi, VPN nomade) ; Logiciel (BDMED / BDPHARMA, messagerie, saisie des visites / frais) ; Comptes et accès (compte AD, mot de passe, droits) ; Sécurité (alerte antivirus, alerte supervision / SIEM, suspicion de fuite) |
| Inventaire | Inventaire natif activé (réception des agents GLPI) |

#### Suite prévue

- **Agent GLPI** sur les postes et serveurs (paquet officiel `glpi-agent`, serveur `http://192.168.100.208/`) pour remonter l'inventaire automatiquement.
- **Annuaire LDAP** : liaison avec l'AD RedOne (*Configuration → Authentification → Annuaires LDAP*) pour importer les comptes et les groupes.
- **Collecteur mail** : création de tickets par mail.

Captures : `captures/glpi_01_connexion.jpg`, `captures/glpi_02_accueil.png`, `captures/glpi_03_categories.png`, `captures/glpi_04_groupes.png`, `captures/glpi_05_ticket.png`

## 6. Tests et validation

| # | Test | Commande / méthode | Résultat attendu | Résultat obtenu | ✅/❌ |
|---|---|---|---|---|---|
| 1 | Accès à l'interface Proxmox | navigateur → `https://192.168.100.2:8006` | Page de connexion | | |
| 2 | VLAN utilisateur → Serveurs | `ping 172.16.0.1` depuis une VM du VLAN 101 | Réponse | | |
| 3 | VLAN utilisateur → autre VLAN | `ping 192.168.30.254` depuis une VM du VLAN 106 | Pas de réponse (bloqué) | | |
| 4 | VLAN utilisateur → Internet | `ping 1.1.1.1` depuis une VM du VLAN 102 | Réponse | | |
| 5 | Visiteurs → DNS | `nslookup redone.local 172.16.0.1` depuis le VLAN 115 | Résolution OK | | |
| 6 | Visiteurs → autre serveur | `ping 172.16.0.50` (GLPI) depuis le VLAN 115 | Pas de réponse (bloqué) | | |
| 7 | Visiteurs → Internet | navigateur → site public | Page affichée | | |
| 8 | Ping d'un serveur Windows | `ping <IP serveur>` | Réponse après activation de la règle ICMP | | |
| 9 | Groupes AD présents | `Get-ADGroup -Filter 'Name -like "*S*"'` | `BTS SIO1`, `SLAM`, `SISR` | | |
| 10 | Accès GLPI | navigateur → `http://192.168.100.208` | Page de connexion GLPI | HTTP 200, page « Connexion à votre compte » | ✅ |
| 10b | Assistant d'installation inaccessible | `http://192.168.100.208/install/install.php` | 404 | 404 | ✅ |
| 10c | Comptes par défaut | connexion avec `glpi` | Refusée (compte désactivé) | | |
| 11 | IP statique pfSense | redémarrage pfSense puis vérification de l'IP | IP inchangée | | |

## 7. Gestion des secrets

Aucun identifiant n'est stocké dans ce dépôt. Les comptes d'administration (Proxmox, pfSense, Zabbix, AD) sont conservés dans le gestionnaire de mots de passe de l'équipe.

Bonnes pratiques appliquées :

- changement des mots de passe par défaut dès l'installation ;
- un compte nominatif par administrateur plutôt que le compte `root` partagé ;
- captures d'écran vérifiées avant commit.

## 8. Bilan

*À compléter : difficultés rencontrées, solutions, compétences mobilisées (bloc 1 / bloc 2 SISR).*
