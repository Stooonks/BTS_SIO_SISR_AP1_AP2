-- Referentiel RedOne pour GLPI
SET NAMES utf8mb4;
UPDATE glpi_entities SET name='RedOne', completename='RedOne', comment='Laboratoire RedOne - Siège Europe (Paris)' WHERE id=0;

-- Lieux
INSERT INTO glpi_locations (name, completename, entities_id, is_recursive, level, locations_id, comment, date_creation, date_mod)
VALUES ('Paris - Siège', 'Paris - Siège', 0, 1, 1, 0, 'Siège RedOne Europe', NOW(), NOW());
SET @p = LAST_INSERT_ID();
INSERT INTO glpi_locations (name, completename, entities_id, is_recursive, level, locations_id, comment, date_creation, date_mod) VALUES
('6e étage - Salle serveur', 'Paris - Siège > 6e étage - Salle serveur', 0, 1, 2, @p, 'Accès restreint : badge, sas, gardien 24h/24', NOW(), NOW()),
('Salles de réunion', 'Paris - Siège > Salles de réunion', 0, 1, 2, @p, 'Wi-Fi VLAN Visiteurs par défaut', NOW(), NOW()),
('Salle Démonstration', 'Paris - Siège > Salle Démonstration', 0, 1, 2, @p, 'Accueil ANSM et partenaires scientifiques', NOW(), NOW()),
('Accueil', 'Paris - Siège > Accueil', 0, 1, 2, @p, NULL, NOW(), NOW());
INSERT INTO glpi_locations (name, completename, entities_id, is_recursive, level, locations_id, comment, date_creation, date_mod)
VALUES ('Terrain - Visiteurs médicaux', 'Terrain - Visiteurs médicaux', 0, 1, 1, 0, 'Postes nomades des 540 visiteurs médicaux', NOW(), NOW());

-- Groupes (services RedOne, alignés sur les VLAN)
INSERT INTO glpi_groups (name, completename, entities_id, is_recursive, level, groups_id, comment, is_requester, is_watcher, is_assign, is_task, is_notify, is_itemgroup, is_usergroup, is_manager, date_creation, date_mod) VALUES
('DSI', 'DSI', 0, 1, 1, 0, 'VLAN 20 - Direction des Services Informatiques', 1,1,1,1,1,1,1,1, NOW(), NOW());
SET @dsi = LAST_INSERT_ID();
INSERT INTO glpi_groups (name, completename, entities_id, is_recursive, level, groups_id, comment, is_requester, is_watcher, is_assign, is_task, is_notify, is_itemgroup, is_usergroup, is_manager, date_creation, date_mod) VALUES
('Réseau & Système', 'DSI > Réseau & Système', 0, 1, 2, @dsi, 'VLAN 10 - Support niveau 2, infrastructure', 1,1,1,1,1,1,1,1, NOW(), NOW()),
('Développement', 'DSI > Développement', 0, 1, 2, @dsi, 'VLAN 50 - Applications flotte visite', 1,1,1,1,1,1,1,1, NOW(), NOW()),
('Direction', 'Direction', 0, 1, 1, 0, 'VLAN 20', 1,1,0,0,1,1,1,1, NOW(), NOW()),
('RH / Compta / Juridique', 'RH / Compta / Juridique', 0, 1, 1, 0, 'VLAN 30', 1,1,0,0,1,1,1,1, NOW(), NOW()),
('Communication / Rédaction', 'Communication / Rédaction', 0, 1, 1, 0, 'VLAN 40', 1,1,0,0,1,1,1,1, NOW(), NOW()),
('Commercial', 'Commercial', 0, 1, 1, 0, 'VLAN 60', 1,1,0,0,1,1,1,1, NOW(), NOW()),
('Labo-Recherche', 'Labo-Recherche', 0, 1, 1, 0, 'VLAN 70', 1,1,0,0,1,1,1,1, NOW(), NOW()),
('Visiteurs médicaux', 'Visiteurs médicaux', 0, 1, 1, 0, '540 délégués terrain (480 métropole, 60 DTOM)', 1,1,0,0,1,1,1,1, NOW(), NOW());

-- Catégories ITIL
DROP PROCEDURE IF EXISTS add_cat;
DELIMITER //
CREATE PROCEDURE add_cat(IN pname VARCHAR(255), IN cname VARCHAR(255))
BEGIN
  DECLARE pid INT DEFAULT 0;
  SELECT id INTO pid FROM glpi_itilcategories WHERE name=pname AND level=1 LIMIT 1;
  IF pid IS NULL OR pid = 0 THEN
    INSERT INTO glpi_itilcategories (name, completename, entities_id, is_recursive, level, itilcategories_id, date_creation, date_mod)
    VALUES (pname, pname, 0, 1, 1, 0, NOW(), NOW());
    SET pid = LAST_INSERT_ID();
  END IF;
  INSERT INTO glpi_itilcategories (name, completename, entities_id, is_recursive, level, itilcategories_id, date_creation, date_mod)
  VALUES (cname, CONCAT(pname, ' > ', cname), 0, 1, 2, pid, NOW(), NOW());
END //
DELIMITER ;
CALL add_cat('Matériel', 'Poste de travail');
CALL add_cat('Matériel', 'Ordinateur portable visiteur');
CALL add_cat('Matériel', 'Imprimante');
CALL add_cat('Matériel', 'Serveur');
CALL add_cat('Réseau', 'Accès réseau / VLAN');
CALL add_cat('Réseau', 'Wi-Fi salles de réunion');
CALL add_cat('Réseau', 'VPN nomade');
CALL add_cat('Logiciel', 'Application métier (BDMED, BDPHARMA)');
CALL add_cat('Logiciel', 'Messagerie');
CALL add_cat('Logiciel', 'Saisie des visites / frais');
CALL add_cat('Comptes et accès', 'Création de compte AD');
CALL add_cat('Comptes et accès', 'Réinitialisation de mot de passe');
CALL add_cat('Comptes et accès', 'Droits sur un dossier partagé');
CALL add_cat('Sécurité', 'Alerte antivirus (ClamAV)');
CALL add_cat('Sécurité', 'Alerte supervision / SIEM');
CALL add_cat('Sécurité', 'Suspicion de fuite de données');
DROP PROCEDURE add_cat;

SELECT 'lieux', COUNT(*) FROM glpi_locations UNION ALL SELECT 'groupes', COUNT(*) FROM glpi_groups UNION ALL SELECT 'categories', COUNT(*) FROM glpi_itilcategories;
