# Conformité RGPD de l'infrastructure RedOne

Ce document explique **en quoi l'infrastructure du site pilote respecte le RGPD** : pour chaque exigence du règlement, il indique ce qu'elle impose, ce qui a été mis en place, sur quelle machine, et comment le vérifier devant le jury.

Les mesures sont **appliquées dans l'infrastructure** depuis le 26/11/2026. Les scripts qui les ont mises en place sont dans [`AP2/rgpd/`](rgpd/). Le registre des traitements est aussi résumé dans l'AP2, [§ 6](AP2_Exploitation_Securite.md#6-rgpd).

---

## 1. Pourquoi le RGPD concerne cette infrastructure

Le RGPD (Règlement UE 2016/679) s'applique dès qu'une organisation traite des **données personnelles**, c'est-à-dire toute information qui permet d'identifier une personne : nom, identifiant, adresse IP, journal de connexion…

Chez RedOne, l'infrastructure en traite de deux sortes :

| Catégorie | Exemples dans l'infra | Niveau de risque |
|---|---|---|
| Données des **salariés** | comptes Active Directory, tickets et matériel GLPI, journaux de connexion (Wazuh, Loki), adresses IP (Zabbix, Prometheus, pare-feux) | Normal |
| Données de **santé** | effets indésirables remontés par les visiteurs médicaux, base BDPHARMA (`/srv/redone`) | **Élevé** : données sensibles (art. 9) |

Comme RedOne est un laboratoire pharmaceutique, la présence de données de santé impose un niveau de sécurité élevé (art. 32) et justifie l'essentiel des mesures ci-dessous.

> Dans la maquette, les données de santé et les comptes sont **fictifs** : aucune donnée réelle n'est traitée.

---

## 2. Vue d'ensemble

| Principe RGPD | Article | Ce qui a été fait (en bref) |
|---|---|---|
| Registre des traitements | art. 30 | Registre de la DSI rédigé : 7 traitements, finalité, base légale, durée, accès |
| Limitation de la conservation | art. 5.1.e | Purge automatique sur **tous** les outils : Wazuh 180 j, Zabbix 90/365 j, Loki et Prometheus 30 j, Veeam 14 j |
| Minimisation | art. 5.1.c | Le SIEM ne copie plus le contenu des fichiers de santé ; aucune donnée envoyée à des tiers par Grafana ; dernier utilisateur masqué sous Windows |
| Confidentialité, chiffrement | art. 32 | HTTPS sur Grafana et Zabbix ; BitLocker sur SRV-VEEAM ; dataset chiffré sur le TrueNAS ; SMB chiffré ; pare-feux partout |
| Contrôle d'accès | art. 32 | Mots de passe de 12 caractères (recommandation CNIL), verrouillage de compte, verrouillage de session à 15 min, comptes en lecture seule |
| Traçabilité | art. 32 | Wazuh, audit AD, journal d'audit Zabbix, journal des rejets des pare-feux |
| Information des personnes | art. 13 + Code du travail L1222-4 | Message avant chaque ouverture de session Windows et bannière SSH |
| Intégrité et disponibilité | art. 32.1.b-c | Sauvegardes 3-2-1 supervisées, 2ᵉ contrôleur de domaine, alertes |
| Localisation des données | chap. V (art. 44 et suivants) | Données et sauvegardes hébergées **en France** : aucun transfert hors UE |

---

## 3. Détail des mesures

### 3.1 Registre des traitements (art. 30)

**Ce que dit le RGPD :** l'organisation doit tenir la liste de ses traitements de données personnelles, avec leur finalité, leur base légale, les destinataires et la durée de conservation.

**Ce qui a été fait :** le registre des traitements gérés par la DSI est tenu dans l'AP2 ([§ 6.1](AP2_Exploitation_Securite.md#61-registre-des-traitements-de-la-dsi-art-30)). Il couvre l'Active Directory, GLPI, le SIEM Wazuh, les journaux Loki, la supervision Zabbix / Prometheus, les sauvegardes Veeam et les données de santé.

Chaque durée de conservation indiquée dans le registre est **réellement appliquée** par un réglage technique (voir § 3.2) : le registre ne décrit pas une intention, il décrit la configuration en place.

### 3.2 Limitation de la conservation (art. 5.1.e)

**Ce que dit le RGPD :** les données ne doivent pas être conservées plus longtemps que nécessaire. Un journal de sécurité gardé indéfiniment n'est pas conforme.

**Ce qui a été fait :** chaque outil qui stocke des journaux ou des données a une durée de conservation fixée et une **suppression automatique**.

| Outil | Données conservées | Durée | Mécanisme | Script |
|---|---|---|---|---|
| Wazuh (SRV-WAZUH) | alertes de sécurité | **180 jours** | politique ISM `redone-retention` de l'indexeur + purge quotidienne des fichiers d'alertes | `wazuh-rgpd.sh` |
| Zabbix (SRV-ZABBIX) | historique des mesures | **90 jours** | *housekeeping* | `zabbix-rgpd.py` |
| | tendances, événements, audit | **365 jours** | *housekeeping* | `zabbix-rgpd.py` |
| | sessions web | **30 jours** | *housekeeping* | `zabbix-rgpd.py` |
| Prometheus (SRV-SUPERVISION) | métriques | **30 jours** | `--storage.tsdb.retention.time=30d` | |
| Loki (SRV-SUPERVISION) | journaux Wazuh, ClamAV, Veeam | **30 jours** | `retention_period: 720h` | |
| Veeam (SRV-VEEAM et TrueNAS) | sauvegardes des serveurs | **14 jours** | rétention des tâches Veeam, copie miroir | |

**Justification des durées :**
- 180 jours pour la sécurité : temps nécessaire pour enquêter sur une intrusion découverte tardivement. C'est la durée retenue par la CNIL dans ses recommandations sur la journalisation (6 mois à 1 an).
- 30 à 90 jours pour l'exploitation : au-delà, les mesures détaillées ne servent plus. Seules les tendances agrégées sont gardées un an.
- 14 jours pour les sauvegardes : de quoi revenir en arrière après une attaque par rançongiciel découverte en quelques jours, sans garder indéfiniment des données supprimées en production.

### 3.3 Minimisation (art. 5.1.c)

**Ce que dit le RGPD :** ne collecter que les données strictement nécessaires à la finalité.

**Ce qui a été fait :**

| Mesure | Avant | Après | Où |
|---|---|---|---|
| Surveillance d'intégrité (FIM) des données de santé | Wazuh copiait le **contenu modifié** des fichiers dans ses alertes : des données de santé se retrouvaient dans le SIEM | `report_changes="no"` : seuls l'empreinte, les droits et l'auteur de la modification sont conservés. Les anciennes copies ont été supprimées | SRV-WAZUH |
| Écran de connexion Windows | affichait le nom du dernier utilisateur | nom masqué | GPO, tout le domaine |
| Grafana | envoyait des statistiques d'usage, vérifiait les mises à jour sur Internet, chargeait les avatars Gravatar | tout désactivé, ainsi que le partage externe de captures : **aucune donnée ne sort** vers des tiers | SRV-SUPERVISION |

### 3.4 Confidentialité et chiffrement (art. 32)

**Ce que dit le RGPD :** mettre en œuvre des mesures techniques appropriées, « notamment le chiffrement » (art. 32.1.a), pour protéger les données contre l'accès non autorisé.

**Chiffrement en transit :**
- **HTTPS** sur Grafana (`https://192.168.100.204:3000`) et Zabbix (`https://192.168.100.210/zabbix`, le HTTP est redirigé). TLS 1.2 minimum, cookies `Secure` et `SameSite=strict`, en-tête HSTS. Script : `https-rgpd.sh`.
- L'API Zabbix interrogée par Grafana passe elle aussi en HTTPS : les jetons d'accès ne circulent plus en clair.
- **Chiffrement SMB obligatoire** sur le partage `\\SRV-VEEAM\Sauvegardes` et sur le TrueNAS : les sauvegardes ne transitent jamais en clair sur le réseau.

**Chiffrement au repos :**
- **BitLocker XTS-AES 256** sur SRV-VEEAM, sur le disque système (protégé par la puce TPM) et sur le dépôt de sauvegardes `S:`. Les **clés de récupération sont enregistrées dans l'Active Directory** grâce à la GPO *RedOne - BitLocker* : en cas de panne, la DSI peut toujours déchiffrer. Scripts : `srv-veeam-bitlocker.ps1`, `ad-gpo-bitlocker.ps1`.
- **Dataset ZFS chiffré AES-256-GCM** sur le TrueNAS pour la 2ᵉ copie des sauvegardes (`Data/sauvegardes-veeam-chiffre`). L'ancienne copie non chiffrée a été supprimée. Script : `truenas-chiffrement.py`.

Conséquence : un disque de sauvegarde volé ou une VM copiée ne permet **pas** de lire les données.

**Réduction de la surface d'attaque :** pare-feux configurés sur toutes les machines (AP2 [§ 4.6](AP2_Exploitation_Securite.md#46-pare-feux-des-serveurs-et-postes-26112026)). Prometheus, Loki et l'API Wazuh ne sont plus joignables depuis le réseau.

### 3.5 Contrôle d'accès (art. 32)

**Ce que dit le RGPD :** seules les personnes habilitées doivent pouvoir accéder aux données.

| Mesure | Valeur | Référence | Script |
|---|---|---|---|
| Longueur minimale des mots de passe du domaine | **12 caractères** + complexité | Recommandation CNIL de 2022 (12 caractères avec 4 types de caractères) | `ad-rgpd.ps1` |
| Historique des mots de passe | 24 | | `ad-rgpd.ps1` |
| Verrouillage du compte | après **10 échecs**, pendant 15 min | Recommandation CNIL (limiter les essais) | `ad-rgpd.ps1` |
| Verrouillage de la session Windows | après **15 min** d'inactivité | Protège un poste laissé ouvert | `ad-rgpd.ps1` |
| Zabbix | compte invité désactivé, mots de passe de 12 caractères avec 4 types de caractères | | `zabbix-rgpd.py` |
| Grafana | pas d'inscription libre, pas d'accès anonyme | | `https-rgpd.sh` |
| Comptes de service | compte `grafana` de Zabbix **en lecture seule** ; compte `svc-sauvegarde` du TrueNAS limité au seul partage de copie | Principe du moindre privilège | |

Les mots de passe ne figurent **jamais** dans ce dépôt GitHub : ils sont conservés hors ligne par l'administrateur.

### 3.6 Traçabilité (art. 32)

**Ce que dit le RGPD :** pouvoir détecter et analyser un accès illégitime, et notifier une violation de données à la CNIL **sous 72 heures** (art. 33).

**Ce qui a été fait :**
- **Wazuh** centralise les connexions, les échecs d'authentification, les modifications de fichiers sensibles (FIM sur `/srv/redone`) et les détections antivirus.
- **Audit Active Directory** : connexions et modifications de comptes.
- **Journal d'audit Zabbix** : qui a modifié quoi dans la supervision (conservé 365 jours).
- **Journal des paquets rejetés** par les pare-feux.
- **Grafana** affiche ces événements en temps réel et lève des alertes, ce qui permet de détecter rapidement une violation et de respecter le délai de 72 heures.

### 3.7 Information des personnes (art. 13 et Code du travail L1222-4)

**Ce que dit le RGPD :** les personnes doivent être informées que leurs données sont collectées. Le Code du travail impose en plus d'informer les salariés de tout dispositif qui collecte des informations sur eux.

**Ce qui a été fait :**
- **Message affiché avant chaque ouverture de session Windows** (GPO *RedOne - Information des utilisateurs*). L'utilisateur doit cliquer sur OK pour continuer.
- **Bannière SSH** sur les 4 serveurs Linux (SRV-SUPERVISION, SRV-GLPI, SRV-WAZUH, SRV-ZABBIX). Script : `ssh-banniere.sh`.

Le message indique :
- que le système est à usage professionnel ;
- que les connexions et les actions sont journalisées ;
- les durées de conservation ;
- le contact du DPO (`dpo@redone.com`).

### 3.8 Intégrité et disponibilité (art. 32.1.b et c)

**Ce que dit le RGPD :** garantir « la disponibilité et la résilience constantes des systèmes » et pouvoir « rétablir la disponibilité des données […] dans des délais appropriés en cas d'incident ».

**Ce qui a été fait :**
- **Sauvegardes selon la règle 3-2-1** (AP2 [§ 5](AP2_Exploitation_Securite.md#5-sauvegarde-et-pra)) : données de production, dépôt Veeam sur SRV-VEEAM, copie chiffrée sur le TrueNAS.
- **Sauvegardes supervisées** : résultat, âge et espace disque remontés dans Zabbix et Grafana, avec une alerte si une sauvegarde manque.
- **Deuxième contrôleur de domaine** (SRV-AD2) : l'authentification reste disponible si SRV-AD tombe.
- **Supervision** Zabbix, Prometheus et Grafana, avec des alertes sur la disponibilité des machines.

### 3.9 Localisation des données (chapitre V)

**Ce que dit le RGPD :** un transfert de données hors de l'Union européenne n'est autorisé qu'avec des garanties (décision d'adéquation, clauses contractuelles types…).

**Constat sur l'existant :** RedOne répliquait ses sauvegardes **vers les États-Unis**. Pour des données de santé, c'est un transfert hors UE sensible : les données sont exposées aux lois américaines d'accès aux données, comme le *Cloud Act*.

**Ce qui a été fait :** la sauvegarde 3-2-1 du site pilote est **entièrement locale**, avec SRV-VEEAM et le TrueNAS **en France**. Aucun outil n'envoie de données vers un service extérieur : Grafana a été coupé d'Internet (§ 3.3) et aucun service en ligne n'est utilisé.

---

## 4. Comment le vérifier (démonstration au jury)

| Mesure | Vérification |
|---|---|
| Politique de mots de passe | Sur SRV-AD : `Get-ADDefaultDomainPasswordPolicy` → `MinPasswordLength : 12`, `LockoutThreshold : 10`, `PasswordHistoryCount : 24` |
| Message d'information Windows | Ouvrir une session sur n'importe quel poste du domaine : le message s'affiche avant le bureau |
| Bannière SSH | `ssh sysadmin@192.168.100.210` : la bannière s'affiche avant le mot de passe |
| HTTPS | Ouvrir `http://192.168.100.210/zabbix` : redirection automatique vers `https://` |
| BitLocker | Sur SRV-VEEAM : `manage-bde -status` → `C:` et `S:` en *XTS-AES 256* |
| Clés BitLocker dans l'AD | Sur SRV-AD, dans *Utilisateurs et ordinateurs AD* : ordinateur SRV-VEEAM, onglet *Récupération BitLocker* |
| Chiffrement SMB | Sur SRV-VEEAM : `Get-SmbShare Sauvegardes \| Select Name, EncryptData` → `True` |
| Dataset chiffré TrueNAS | Interface TrueNAS → *Datasets* : `sauvegardes-veeam-chiffre` porte le cadenas *Encrypted* |
| Rétention Wazuh | Dashboard Wazuh → *Index Management* → *Policies* : `redone-retention`, suppression à 180 j |
| Rétention Zabbix | Zabbix → *Administration* → *Housekeeping* : 90 j / 365 j / 30 j |
| FIM sans copie du contenu | Modifier un fichier de `/srv/redone` : l'alerte Wazuh indique le changement d'empreinte **sans** afficher le contenu |
| Verrouillage de session | Laisser un poste inactif 15 min : la session se verrouille |

---

## 5. Limites et recommandations

La maquette respecte les principes techniques du RGPD, mais certains points restent à traiter avant une mise en production :

| Écart | Recommandation |
|---|---|
| Les comptes de test ont un mot de passe commun de 9 caractères, antérieur à la nouvelle politique | Forcer le changement à la prochaine connexion |
| Certificats HTTPS auto-signés | Déployer une autorité de certification interne (AD CS) |
| Sauvegardes protégées par BitLocker, ZFS et SMB, mais pas chiffrées par Veeam lui-même | Activer le chiffrement des tâches Veeam (mot de passe au coffre-fort de la DSI) |
| Traitement de données de santé à grande échelle | Réaliser une **analyse d'impact (AIPD, art. 35)** et désigner formellement le DPO |
| Clés de chiffrement du TrueNAS conservées sur le TrueNAS | Exporter les clés et les ranger hors du NAS |

Le RGPD comporte aussi des obligations **organisationnelles** qui ne relèvent pas de l'infrastructure : charte informatique, contrats avec les sous-traitants (art. 28), procédure d'exercice des droits des personnes (accès, rectification, effacement), sensibilisation des salariés.

---

## 6. Scripts

| Script | Rôle | Machine |
|---|---|---|
| [`wazuh-rgpd.sh`](rgpd/wazuh-rgpd.sh) | Rétention 180 j, FIM sans copie du contenu | SRV-WAZUH |
| [`zabbix-rgpd.py`](rgpd/zabbix-rgpd.py) | *Housekeeping*, politique de mots de passe, compte invité | SRV-ZABBIX |
| [`https-rgpd.sh`](rgpd/https-rgpd.sh) | HTTPS Grafana et Zabbix, durcissement de Grafana | SRV-SUPERVISION, SRV-ZABBIX |
| [`ad-rgpd.ps1`](rgpd/ad-rgpd.ps1) | Mots de passe, verrouillage, message d'information, dernier utilisateur masqué | SRV-AD |
| [`ad-gpo-bitlocker.ps1`](rgpd/ad-gpo-bitlocker.ps1) | GPO de sauvegarde des clés BitLocker dans l'AD | SRV-AD |
| [`srv-veeam-bitlocker.ps1`](rgpd/srv-veeam-bitlocker.ps1) | Chiffrement BitLocker des disques | SRV-VEEAM |
| [`truenas-chiffrement.py`](rgpd/truenas-chiffrement.py) | Dataset chiffré, chiffrement SMB | TrueNAS |
| [`ssh-banniere.sh`](rgpd/ssh-banniere.sh) | Bannière d'information SSH | Serveurs Linux |
