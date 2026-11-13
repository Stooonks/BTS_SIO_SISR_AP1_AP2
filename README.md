# BTS SIO SISR – AP1 / AP2

Dépôt de documentation des ateliers professionnels (AP) réalisés en équipe sur l'infrastructure Proxmox de la section.

| Dossier | Contenu |
|---|---|
| [`AP1/`](AP1/AP1_Systeme_Information.md) | Conception et mise en place du système d'information : adressage, VLAN, pfSense, Active Directory, GLPI |
| [`AP2/`](AP2/AP2_Exploitation_Securite.md) | Exploitation et sécurité : supervision (Zabbix / Grafana), Wazuh, sauvegarde / PRA, RGPD |
| [`Veille_Portfolio/`](Veille_Portfolio/README.md) | Veille technologique et liens vers le portfolio |

## Équipe

| Étudiant | Rôle sur l'AP |
|---|---|
| Fahim | Schéma réseau |
| Xavier | VLAN sur pfSense ✅ |
| Loïc | VLAN sur pfSense ✅ |
| Yan | Groupes AD (BTS SIO1, SLAM, SISR) |
| Thibaut | Groupes AD (BTS SIO1, SLAM, SISR) |
| Minkaïl | à compléter |
| Josh | à compléter |

**Auteur de ce dépôt :** à compléter

## Règles du dépôt

- **Aucun mot de passe, clé API, token ou fichier de configuration brut** n'est versionné ici (voir [`.gitignore`](.gitignore)). Les identifiants sont conservés hors dépôt (gestionnaire de mots de passe de l'équipe).
- Les captures d'écran vont dans le dossier `captures/` de chaque AP et doivent être vérifiées (pas d'identifiants visibles) avant le commit.
- Les comptes utilisateurs utilisés dans les exemples sont fictifs.
