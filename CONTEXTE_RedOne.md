# Contexte – Laboratoire RedOne

> Synthèse du cahier des charges *« Description de l'entreprise RedOne et de ses besoins informatiques »* qui sert de contexte aux AP.

## 1. L'entreprise

- **RedOne** est un laboratoire pharmaceutique né en 2009 de la fusion entre **Galaxy** (groupe américain spécialisé dans les maladies virales) et **Swiss Bourdin** (conglomérat européen de médicaments plus conventionnels).
- Siège social à Philadelphie (États-Unis). Siège **RedOne Europe** à **Paris**.
- **540 visiteurs médicaux** : 480 en métropole (Corse comprise) et 60 en outre-mer, répartis en secteurs géographiques (Paris-Centre, Nord, Sud, Est, Ouest, DTOM Caraïbes-Amériques, DTOM Asie-Afrique).
- Après deux ans de réorganisation, l'entreprise veut **moderniser le suivi de l'activité de visite médicale**. La France sert de site pilote.

## 2. Système informatique existant (site de Paris)

| Élément | Description |
|---|---|
| Services présents | Direction, RH, comptabilité, commercial, juridique, communication, labo-recherche, DSI |
| Salle serveur | 6ᵉ étage, accès restreint (ascenseur à clé, badge, sas avec gardien 24 h/24) |
| Serveurs | DHCP, DNS, annuaire, intranet, messagerie, agenda partagé, applications métier (BDMED, BDPHARMA, licences…), PGI (RH, GRC) |
| Volumétrie | + de 350 postes, 45 serveurs physiques, + de 100 serveurs virtuels |
| Disponibilité | RAID, alimentations et liens redondants, Spanning-Tree, clustering |
| Sauvegarde | Réplication quotidienne des données vers les États-Unis par lien dédié |
| Messagerie | `nomUtilisateur@redone.com`, messagerie publique hébergée aux États-Unis |
| Routage inter-VLAN | Commutateur de niveau 3 **MUTLAB** avec ACL |

Les données sont **stratégiques** : aucune fuite ni destruction n'est tolérée.

## 3. Segmentation réseau (VLAN)

| VLAN | Service(s) | Réseau |
|---|---|---|
| 10 | Réseau & Système | `192.168.10.0/24` |
| 20 | Direction / DSI | `192.168.20.0/24` |
| 30 | RH / Compta / Juridique / Secrétariat administratif | `192.168.30.0/24` |
| 40 | Communication / Rédaction | `192.168.40.0/24` |
| 50 | Développement | `192.168.50.0/24` |
| 60 | Commercial | `192.168.60.0/24` |
| 70 | Labo-Recherche | `192.168.70.0/24` |
| 100 | Accueil | `192.168.100.0/24` |
| 150 | Visiteurs | `192.168.150.0/24` |
| 200 | Démonstration | `192.168.200.0/24` |
| 300 | Serveurs | `172.16.0.0/17` |
| 400 | Sortie | `172.18.0.0/30` |

**Règles de filtrage :**

- chaque VLAN (sauf Visiteurs) accède **uniquement** aux VLAN *Serveurs* et *Sortie*, tous protocoles ;
- le VLAN *Visiteurs* accède **uniquement** aux serveurs DNS et DHCP et à Internet.

**Wi-Fi :** chaque salle de réunion a une borne placée par défaut dans le VLAN *Visiteurs* (accès Internet seul). Elle peut être basculée sur un VLAN de l'étage à la demande.

## 4. Besoins exprimés

1. **Remontée d'informations terrain** des visiteurs (confiance des praticiens, lisibilité des notices, effets indésirables) vers le siège, notamment vers la rédaction et le labo-recherche.
2. **Gestion unifiée des frais** de déplacement : aujourd'hui, carte bancaire chez Galaxy et forfaits chez Swiss Bourdin.
3. **Accès plus direct aux données RH** pour les délégués régionaux et les responsables de secteur, à cause d'un fort turn-over.
4. **Uniformisation du parc** des visiteurs : aujourd'hui, indemnité d'équipement d'un côté et dotation de l'autre.

**Répartition des responsabilités :**

- **Développement (SLAM)** : applications de saisie des visites et de gestion des frais.
- **Réseau & Système (SISR)** : équipements, configuration réseau et ressources serveur pour héberger ces applications.

## 5. Axes d'évolution proposés

Une fois le socle prêt (réseau segmenté, salle serveur, virtualisation, services de base), chaque équipe peut mener un projet sur un ou plusieurs axes :

| Axe | Exemples d'outils | Traité dans |
|---|---|---|
| Infrastructure as Code | Terraform, Ansible | |
| Cybersécurité | Guides ANSSI, CIS, pare-feu, bastion, SIEM (Wazuh, ELK), pentest | [AP2](AP2/AP2_Exploitation_Securite.md#4-sécurité--wazuh) |
| Supervision et exploitation | Zabbix, Prometheus, Grafana | [AP2](AP2/AP2_Exploitation_Securite.md#3-supervision--zabbix--grafana) |
| Conteneurisation / DevOps | Docker, Kubernetes, GitLab CI, Jenkins | |
| Sauvegarde et PRA | Règle 3-2-1, PRA, tests de restauration | [AP2](AP2/AP2_Exploitation_Securite.md#5-sauvegarde-et-pra) |
| Identités et accès | Annuaire, MFA, droits par profil, VPN pour les nomades | [AP1](AP1/AP1_Systeme_Information.md#52-active-directory--groupes-de-la-section) |
| Cloud hybride | Azure, AWS, OVHcloud | |
| Gouvernance et conformité | EBIOS RM, ISO 27001, RGPD (données de santé) | [AP2](AP2/AP2_Exploitation_Securite.md#6-rgpd) |
