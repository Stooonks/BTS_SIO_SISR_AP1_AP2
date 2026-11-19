SET NAMES utf8mb4;
-- Annuaire LDAP Active Directory RedOne (inactif tant que le compte de service n'est pas renseigné)
INSERT INTO glpi_authldaps (name, host, port, basedn, rootdn, `condition`, login_field, sync_field,
  group_field, group_condition, group_search_type, group_member_field,
  email1_field, realname_field, firstname_field, phone_field, mobile_field, title_field,
  use_dn, use_bind, is_default, is_active, pagesize, can_support_pagesize, ldap_maxlimit, timeout,
  inventory_domain, comment, date_creation, date_mod)
VALUES ('AD RedOne', '10.2.1.10', 389, 'DC=RedOne,DC=local', 'CN=svc-glpi,CN=Users,DC=RedOne,DC=local',
  '(&(objectClass=user)(objectCategory=person)(!(userAccountControl:1.2.840.113556.1.4.803:=2)))',
  'samaccountname', 'objectguid',
  'memberof', '(&(objectClass=group))', 0, NULL,
  'mail', 'sn', 'givenname', 'telephonenumber', 'mobile', 'title',
  1, 1, 1, 0, 1000, 1, 0, 10,
  'RedOne.local', 'Contrôleur de domaine RedOne.RedOne.local (VM 105). Renseigner le mot de passe du compte de service svc-glpi puis activer.', NOW(), NOW());

-- Attribution automatique : groupe technique par catégorie
UPDATE glpi_itilcategories c JOIN glpi_groups g ON g.name='Réseau & Système'
  SET c.groups_id = g.id
  WHERE c.completename LIKE 'Matériel%' OR c.completename LIKE 'Réseau%' OR c.completename LIKE 'Comptes et accès%' OR c.completename LIKE 'Sécurité%'
     OR c.completename IN ('Logiciel', 'Logiciel > Messagerie', 'Logiciel > Application métier (BDMED, BDPHARMA)');
UPDATE glpi_itilcategories c JOIN glpi_groups g ON g.name='Développement'
  SET c.groups_id = g.id WHERE c.completename = 'Logiciel > Saisie des visites / frais';
-- Technicien référent par défaut sur les catégories Réseau et Sécurité
UPDATE glpi_itilcategories c JOIN glpi_users u ON u.name='tech.reseau'
  SET c.users_id = u.id WHERE c.completename LIKE 'Réseau%' OR c.completename LIKE 'Sécurité%';

SELECT completename, (SELECT name FROM glpi_groups WHERE id=c.groups_id) groupe FROM glpi_itilcategories c ORDER BY completename;
