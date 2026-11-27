# Plan de reprise d'activité (PRA) – site pilote RedOne

Ce document dit **qui fait quoi, dans quel ordre**, quand un élément de l'infrastructure tombe. Il s'appuie sur la sauvegarde décrite dans l'AP2, [§ 5](../AP1-Superviser-et-securiser/README.md) : Veeam Agent vers SRV-VEEAM, puis copie chiffrée sur le TrueNAS.

| Version | Date | Auteur | Objet |
|---|---|---|---|
| 1.0 | 26/11/2026 | DSI RedOne (pôle Réseau & Système) | Première version, après le test de restauration du 26/11/2026 |

---

## 1. Objectifs de reprise

| Service | Machine(s) | Criticité | RTO visé (durée d'interruption maximale) | RPO (perte de données maximale) |
|---|---|---|---|---|
| Authentification, DNS, DHCP | SRV-AD, SRV-AD2 | **Vitale** : sans elle, personne ne travaille | **0** grâce au 2ᵉ contrôleur ; 2 h pour reconstruire le contrôleur perdu | 24 h |
| Partage de fichiers `\\REDONE\Partages` (lecteur Z:) | SRV-AD | **Haute** : données métier et de santé | 1 h (fichiers) ; 4 h (serveur complet) | 24 h |
| Sauvegarde | SRV-VEEAM, TrueNAS | Haute : protège tout le reste | 4 h | sans objet |
| Support et parc | SRV-GLPI | Moyenne | 1 jour ouvré | 24 h |
| Supervision et sécurité | SRV-SUPERVISION, SRV-ZABBIX, SRV-WAZUH | Moyenne : le SI fonctionne sans, mais « en aveugle » | 1 jour ouvré | historique perdu acceptable |

> **Mesuré le 26/11/2026** : la restauration d'un fichier du partage a pris **2 min 24 s** (AP2, [§ 5.7](../AP1-Superviser-et-securiser/README.md)).

---

## 2. Rôles

| Rôle | Qui | Responsabilité |
|---|---|---|
| **Responsable du PRA** | Responsable de la DSI | Déclenche le PRA, décide des priorités, informe la direction |
| **Opérateur** | Administrateur Réseau & Système d'astreinte | Applique les procédures de ce document, tient le journal de l'incident |
| **Support** | Techniciens (GLPI) | Informe les utilisateurs, ouvre et met à jour le ticket d'incident |
| **DPO** | `dpo@redone.com` | Si des données personnelles sont touchées : évalue la violation et la notifie à la CNIL **sous 72 h** (art. 33 RGPD) |

**Avant toute action :** ouvrir un ticket GLPI de catégorie *Incident majeur* et noter l'heure de début. Toutes les heures du journal servent à calculer le RTO réel.

---

## 3. Détection

Une panne est normalement repérée par la supervision avant les utilisateurs :

| Signal | Où le voir |
|---|---|
| Machine qui ne répond plus au ping, agent indisponible | Grafana, dashboard *RedOne – Zabbix* : panneaux « Ping » et « Agent Zabbix » |
| Sauvegarde en échec ou absente depuis plus de 26 h | Grafana, section « 💾 Sauvegardes Veeam » ; problème Zabbix |
| Attaque (force brute, fichier modifié, virus) | Dashboard Wazuh ; la **réponse active** bloque déjà l'IP de l'attaquant pendant 10 min |
| Signalement d'un utilisateur | Ticket GLPI |

---

## 4. Ordre de redémarrage

En cas de panne générale (salle serveur, hôte Proxmox), redémarrer **dans cet ordre**, et attendre que chaque étape réponde avant de passer à la suivante :

| Ordre | Élément | Vérification avant de continuer |
|---|---|---|
| 1 | Hôte Proxmox `192.168.100.2` et stockage | Interface web accessible, stockage `Raid5-VMs` en ligne |
| 2 | pfSense (VM 100) | `ping 10.2.1.1` depuis un serveur |
| 3 | **SRV-AD** (VM 105) puis **SRV-AD2** (VM 206) | `nslookup srv-ad.redone.local` répond ; `dcdiag /q` sans erreur |
| 4 | TrueNAS (VM 205) | partage `copie-veeam` accessible |
| 5 | SRV-VEEAM (VM 211) | partage `\\SRV-VEEAM\Sauvegardes` accessible ; `S:` déverrouillé (BitLocker, automatique) |
| 6 | SRV-GLPI (VM 208) | `https://192.168.100.208` affiche la connexion |
| 7 | SRV-WAZUH, SRV-ZABBIX, SRV-SUPERVISION (VM 209, 210, 204) | dashboards accessibles, tous les agents « Active » |
| 8 | Postes de travail | ouverture de session d'un utilisateur test, lecteur Z: monté |

Les contrôleurs de domaine passent **avant** tout le reste : les autres serveurs en dépendent pour le DNS et l'authentification.

---

## 5. Scénarios et procédures

### Scénario A – Fichier ou dossier supprimé, écrasé ou chiffré

*Exemple : un utilisateur supprime un document du lecteur Z:.* **RTO : quelques minutes.**

1. Demander à l'utilisateur le chemin exact et la dernière date où le fichier était correct.
2. Sur **SRV-AD**, menu Démarrer → **Veeam** → **File Level Restore**.
3. Choisir la sauvegarde *Sauvegarde SRV-AD*, puis le **point de restauration antérieur** au problème → **Ouvrir**.
4. Dans le **Backup Browser**, aller jusqu'au fichier, faire un clic droit → **Restore** :
   - **Overwrite** remplace le fichier actuel ;
   - **Keep** restaure à côté, sous un autre nom, si l'utilisateur a fait des modifications depuis.
5. Vérifier avec l'utilisateur, puis **fermer le Backup Browser**, ce qui démonte la sauvegarde.
6. Clore le ticket en notant le RTO.

*Testé avec succès le 26/11/2026.*

### Scénario B – Perte d'un contrôleur de domaine (SRV-AD ou SRV-AD2)

**Effet immédiat : aucun.** L'autre contrôleur assure l'authentification et le DNS, car les serveurs et les postes ont les deux DNS (`10.2.1.10` et `10.2.1.9`).

1. Vérifier sur le contrôleur restant que tout fonctionne : `dcdiag /q`, et `nslookup redone.local`.
2. **Si la VM est réparable** (disque intact) : la redémarrer depuis Proxmox, puis contrôler la réplication avec `repadmin /replsummary`.
3. **Sinon, restaurer la machine complète** depuis Veeam :
   1. Créer une VM de remplacement dans Proxmox, avec le même nombre de disques et une taille au moins égale.
   2. La démarrer sur le **support de récupération Veeam** (ISO créé depuis *Veeam Agent → Create Recovery Media*).
   3. Choisir **Bare Metal Recovery** → dossier réseau `\\SRV-VEEAM\Sauvegardes` → dernier point de restauration.
   4. Restaurer, redémarrer, puis vérifier la réplication (`repadmin /replsummary`) et les partages.
4. **Si la restauration est impossible** et que le contrôleur perdu détenait les rôles FSMO : transférer de force les rôles sur le contrôleur restant (`ntdsutil` → `roles` → `seize`), nettoyer les métadonnées du contrôleur perdu, puis installer un nouveau contrôleur.
5. Vérifier que les sauvegardes Veeam du contrôleur reconstruit repartent bien (Grafana).

> ⚠️ Ne jamais restaurer un contrôleur de domaine à partir d'une copie de VM (snapshot) pendant que l'autre tourne : cela provoque une désynchronisation (*USN rollback*). Veeam, lui, effectue une restauration compatible Active Directory.

### Scénario C – Perte du serveur de sauvegarde SRV-VEEAM

Les serveurs de production fonctionnent. Seule la protection est perdue. **RTO : 4 h.**

1. Réinstaller une VM Windows Server, la joindre au domaine sous le nom **SRV-VEEAM** (`10.2.1.53`).
2. Ajouter un disque de 300 Go (`S:`), le chiffrer avec BitLocker ([`srv-veeam-bitlocker.ps1`](../AP1-Superviser-et-securiser/scripts/sauvegarde/srv-veeam-bitlocker.ps1)).
3. Recréer le partage `Sauvegardes` (chiffrement SMB, droits pour `REDONE$`, `SRV-AD2$` et les admins du domaine).
4. **Recopier les sauvegardes depuis le TrueNAS** : `robocopy \\truenas.redone.local\copie-veeam S:\Sauvegardes /E`.
5. Recréer la tâche de copie nocturne ([`srv-veeam-copie-truenas.ps1`](../AP1-Superviser-et-securiser/scripts/sauvegarde/srv-veeam-copie-truenas.ps1)).
6. Lancer une sauvegarde manuelle depuis chaque contrôleur et vérifier son succès dans Grafana.

### Scénario D – Perte d'un serveur Linux (GLPI, Wazuh, Zabbix, supervision)

**RTO : 1 jour ouvré.** Ces serveurs sont reconstruits à partir des **scripts du dépôt Git**, qui décrivent toute leur configuration :

| Serveur | Reconstruction | Données à récupérer |
|---|---|---|
| SRV-GLPI | installation Debian, puis [`install.sh`](../AP1-Superviser-et-securiser/scripts/glpi/install.sh), [`config.sql`](../AP1-Superviser-et-securiser/scripts/glpi/config.sql) et [`referentiel.sql`](../AP1-Superviser-et-securiser/scripts/glpi/referentiel.sql) | **base GLPI** : dernier dump produit par [`glpi-backup.sh`](../AP1-Superviser-et-securiser/scripts/glpi/glpi-backup.sh) |
| SRV-ZABBIX | installation Zabbix 7.0 LTS, puis [`zabbix-config.py`](../AP1-Superviser-et-securiser/scripts/supervision/zabbix-config.py) (hôtes, modèles, déclencheurs) | historique : perte acceptable |
| SRV-SUPERVISION | Prometheus, Loki, Alloy, Grafana, puis les fichiers de [`AP2/supervision/`](../AP1-Superviser-et-securiser/scripts/supervision/) | tableaux de bord : regénérés par les scripts |
| SRV-WAZUH | installation Wazuh 4.x, puis les scripts de [`AP2/securite/`](../AP1-Superviser-et-securiser/scripts/securite/) et [`AP2/rgpd/`](../AP1-Superviser-et-securiser/scripts/) ; **réenrôler les agents** | alertes : perte acceptable, rétention de 180 j |

Dans tous les cas, appliquer ensuite le pare-feu ([`linux-firewall.sh`](../AP1-Superviser-et-securiser/scripts/securite/linux-firewall.sh)) et la bannière SSH ([`ssh-banniere.sh`](../AP1-Superviser-et-securiser/scripts/securite/ssh-banniere.sh)).

### Scénario E – Attaque par rançongiciel

1. **Isoler** : couper la carte réseau des machines touchées dans Proxmox (*Hardware → Network Device → Disconnect*). **Ne pas les éteindre**, pour garder les traces en mémoire.
2. **Identifier** l'étendue et l'heure de début dans Wazuh (FIM, alertes antivirus, connexions anormales).
3. **Prévenir le DPO** : des données de santé sont peut-être touchées, avec une notification CNIL sous 72 h.
4. **Vérifier les sauvegardes** : choisir un point de restauration **antérieur** au début de l'attaque. La copie TrueNAS est sur un dataset séparé, avec un compte dédié inconnu des serveurs de production : elle sert de dernier recours si le dépôt SRV-VEEAM est lui aussi chiffré.
5. **Restaurer** les machines touchées (scénario B, restauration complète) ou les fichiers (scénario A).
6. **Changer les mots de passe** des comptes administrateurs et de service avant de reconnecter les machines au réseau.
7. Reconnecter, surveiller de près pendant 48 h, puis rédiger un retour d'expérience.

### Scénario F – Perte totale de la salle serveur (incendie, inondation)

**Non couvert à ce jour** : SRV-VEEAM et le TrueNAS sont dans la même salle que les serveurs de production. Recommandation : une 3ᵉ copie **hors site**, chiffrée, hébergée **dans l'Union européenne** pour respecter le RGPD. Par exemple un stockage objet S3 d'un hébergeur français, ou le TrueNAS d'un autre site RedOne.

---

## 6. Retour à la normale

Avant de clore l'incident :

- [ ] Toutes les machines répondent dans Grafana (ping et agent Zabbix au vert).
- [ ] Tous les agents Wazuh sont « Active ».
- [ ] Une sauvegarde Veeam **réussie** a eu lieu après la reprise, pour chaque contrôleur de domaine.
- [ ] La copie TrueNAS de la nuit suivante est « COPIE OK ».
- [ ] Les utilisateurs ont été informés de la fin de l'incident.
- [ ] Le ticket GLPI est clos avec le journal horodaté et le **RTO réel**.
- [ ] Le retour d'expérience est rédigé, et ce document est corrigé si une étape était fausse ou manquante.

---

## 7. Tests du PRA

Un PRA non testé ne vaut rien. Il est rejoué **au moins une fois par an**, et après chaque changement important de l'infrastructure.

| Date | Scénario | Résultat | RTO mesuré |
|---|---|---|---|
| 26/11/2026 | A – restauration d'un fichier du partage | ✅ fichier restauré intact (taille, date, contenu) | 2 min 24 s |
| *à planifier* | B – restauration complète d'un contrôleur de domaine dans une VM de test isolée | | |
| *à planifier* | C – reconstruction du dépôt depuis le TrueNAS | | |
