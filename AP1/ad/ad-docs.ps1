$ErrorActionPreference = 'Stop'
$R = 'C:\Partages'
$enc = New-Object Text.UTF8Encoding $true
function Doc($rel, $text) { [IO.File]::WriteAllText((Join-Path $R $rel), $text.Trim() + "`r`n", $enc) }

Doc 'Commun\Charte informatique RedOne.txt' @"
CHARTE D'UTILISATION DU SYSTÈME D'INFORMATION - REDONE EUROPE
Version 1.0 - DSI

1. Les données de l'entreprise sont stratégiques : aucune copie sur un support personnel.
2. Le mot de passe est personnel : 12 caractères minimum, jamais communiqué, y compris à la DSI.
3. Le poste est verrouillé (Windows + L) à chaque absence.
4. Les documents de travail sont enregistrés sur le lecteur Z: (sauvegardé chaque nuit), jamais sur le bureau.
5. Tout incident (virus, perte de matériel, message suspect) est signalé immédiatement via GLPI :
   http://192.168.100.208  (connexion avec votre identifiant Windows, source « AD RedOne »).
6. L'accès au réseau Wi-Fi des salles de réunion est limité à Internet (VLAN Visiteurs).
"@

Doc 'Commun\Annuaire des services.csv' @"
Service;Responsable;Poste;Dossier Z:
Direction / DSI;Alma Roux;2001;Z:\Direction-DSI
Réseau & Système;Jade Laurent;1001;Z:\DSI-Technique
Exploitation serveurs;Alba Martinez;3001;Z:\DSI-Technique
RH / Compta / Juridique;Alba Leroy;3002;Z:\RH-Compta-Juridique
Communication / Rédaction;Rose Garcia;4001;Z:\Communication-Redaction
Développement;Adele David;5001;Z:\Developpement
Commercial;Iris Vincent;6001;Z:\Commercial
Labo-Recherche;Agathe Morel;7001;Z:\Labo-Recherche
Accueil;Anna Andre;1000;Z:\Accueil
Démonstration;Ambre Bonnet;2002;Z:\Demonstration
Visiteurs médicaux;Bintou Traore;-;Z:\Visiteurs-Medicaux
"@

Doc 'Commun\LISEZ-MOI - Organisation du lecteur Z.txt' @"
LECTEUR Z: - PARTAGES REDONE (\\REDONE\Partages)

Vous ne voyez que les dossiers auxquels vous avez droit (énumération basée sur l'accès).
- Commun : lecture / écriture pour tous les employés.
- Dossier de votre service : lecture / écriture pour votre service uniquement.
- La Direction-DSI consulte l'ensemble des dossiers en lecture.
- Visiteurs-Medicaux\Notes-de-frais : consultées par la Comptabilité.
- Visiteurs-Medicaux\Remontees-terrain : consultées par la Rédaction et le Labo-Recherche.
Toute demande d'accès supplémentaire passe par un ticket GLPI (catégorie « Comptes et accès > Droits sur un dossier partagé »).
"@

Doc 'Direction-DSI\Comité de direction - compte rendu novembre.txt' @"
COMITÉ DE DIRECTION REDONE EUROPE - Compte rendu (document interne)
Ordre du jour :
- Modernisation du suivi de l'activité de visite médicale (France pilote).
- Unification de la gestion des frais Galaxy / Swiss Bourdin.
- Déploiement GLPI (support) et Wazuh (sécurité) par la DSI.
Décision : application unique de saisie des visites et des frais, livrée par le service Développement.
"@

Doc 'DSI-Technique\Plan d adressage RedOne.txt' @"
PLAN D'ADRESSAGE - VLAN REDONE
VLAN 10  Réseau & Système        192.168.10.0/24
VLAN 20  Direction / DSI         192.168.20.0/24
VLAN 30  RH / Compta / Juridique 192.168.30.0/24
VLAN 40  Communication           192.168.40.0/24
VLAN 50  Développement           192.168.50.0/24
VLAN 60  Commercial              192.168.60.0/24
VLAN 70  Labo-Recherche          192.168.70.0/24
VLAN 100 Accueil                 192.168.100.0/24
VLAN 150 Visiteurs (Wi-Fi)       192.168.150.0/24 - Internet + DNS/DHCP uniquement
VLAN 200 Démonstration           192.168.200.0/24
VLAN 300 Serveurs                172.16.0.0/17
VLAN 400 Sortie                  172.18.0.0/30
Serveurs : SRV-AD 10.2.1.10 | SRV-GLPI 10.2.1.50 | SRV-WAZUH 10.2.1.51 | SRV-SUPERVISION 10.2.1.3
"@

Doc 'DSI-Technique\Procédure - réinitialiser un mot de passe.txt' @"
PROCÉDURE SUPPORT - RÉINITIALISATION DE MOT DE PASSE
Droit délégué au groupe GG_Reseau-Systeme sur les OU des services (réinitialisation et déverrouillage).
1. Vérifier l'identité de l'utilisateur (rappel sur son poste interne).
2. Console « Utilisateurs et ordinateurs Active Directory » > clic droit sur le compte > Réinitialiser le mot de passe.
3. Cocher « L'utilisateur doit changer le mot de passe à la prochaine ouverture de session ».
4. Tracer l'intervention dans le ticket GLPI correspondant.
"@

Doc 'RH-Compta-Juridique\Procédure arrivée d un collaborateur.txt' @"
PROCÉDURE D'ARRIVÉE (onboarding)
1. RH : fiche d'arrivée (nom, service, date, responsable) transmise à la DSI via GLPI.
2. DSI : création du compte AD dans l'OU du service et ajout au groupe GG_<Service>.
3. DSI : remise du poste / portable (inventorié dans GLPI).
4. Responsable : présentation de la charte informatique (Z:\Commun).
"@

Doc 'RH-Compta-Juridique\Barème frais de déplacement 2026.csv' @"
Poste;Plafond;Justificatif
Repas midi;20,00 €;Ticket
Repas soir;25,00 €;Ticket
Nuitée Paris;140,00 €;Facture
Nuitée province;95,00 €;Facture
Indemnité kilométrique (5 CV);0,636 €/km;Relevé
Frais de représentation;sur validation du responsable de secteur;Facture
"@

Doc 'Visiteurs-Medicaux\Notes-de-frais\Modèle note de frais.csv' @"
Date;Visiteur;Secteur;Nature;Montant TTC;Justificatif
2026-11-18;Bintou Traore;Sud;Repas midi;18,50;Ticket n°4521
2026-11-18;Bintou Traore;Sud;Indemnité kilométrique (142 km);90,31;Relevé
2026-11-19;Ousmane Sissoko;Paris-Centre;Nuitée province;92,00;Facture H-778
"@

Doc 'Visiteurs-Medicaux\Remontees-terrain\Remontées praticiens - semaine 47.txt' @"
REMONTÉES TERRAIN - SEMAINE 47 (données fictives de démonstration)
- Pharmacie, secteur Sud : notice du produit B jugée peu lisible (police trop petite) -> Rédaction.
- Médecin généraliste, Paris-Centre : question sur une interaction médicamenteuse -> Labo-Recherche.
- Infirmière libérale : demande de documentation patient simplifiée -> Communication.
"@

Doc 'Visiteurs-Medicaux\Planning des visites.csv' @"
Semaine;Visiteur;Secteur;Praticiens visés;Objectif
47;Bintou Traore;Sud;12;Présentation nouvelle notice
47;Ousmane Sissoko;Paris-Centre;9;Suivi prescriptions trimestre
48;Bintou Traore;Sud;10;Retour d'expérience patients
"@

Doc 'Commercial\Objectifs secteurs 2026.csv' @"
Secteur;Visiteurs;Objectif visites / mois;Réalisé octobre
Paris-Centre;95;3800;3615
Nord;80;3200;3350
Sud;90;3600;3410
Est;75;3000;2980
Ouest;70;2800;2760
DTOM Caraïbes-Amériques;30;900;870
DTOM Asie-Afrique;30;900;815
"@

Doc 'Communication-Redaction\Notices - corrections à prévoir.txt' @"
NOTICES À REVOIR (suite aux remontées terrain)
- Produit B : agrandir la police de la section « Posologie ».
- Produit D : ajouter un pictogramme « conduite déconseillée ».
Source : Z:\Visiteurs-Medicaux\Remontees-terrain
"@

Doc 'Labo-Recherche\Protocole évaluation complémentaire.txt' @"
PROTOCOLE D'ÉVALUATION COMPLÉMENTAIRE (document interne - confidentiel)
Déclencheur : remontées terrain signalant une interaction possible.
Étapes : revue bibliographique, analyse des déclarations, avis du comité scientifique.
Accès restreint : Labo-Recherche (écriture), Direction (lecture).
"@

Doc 'Developpement\Cahier des charges - application visites et frais.txt' @"
APPLICATION « SUIVI DES VISITES ET DES FRAIS » - Expression des besoins
- Saisie des visites par le visiteur médical (praticien, date, produits présentés, remarques).
- Saisie des frais avec justificatif photographié, barème unique (Z:\RH-Compta-Juridique).
- Validation par le délégué régional puis par la Comptabilité.
- Hébergement sur l'infrastructure fournie par le service Réseau & Système (VLAN Serveurs).
"@

Doc 'Accueil\Registre des visiteurs - modèle.csv' @"
Date;Heure arrivée;Nom;Société;Personne visitée;Badge remis;Heure départ
2026-11-19;09:15;M. Dupont;ANSM;Alma Roux;V-012;11:40
"@

Doc 'Demonstration\Réservation salle Démonstration.csv' @"
Date;Créneau;Organisme;Responsable RedOne;Matériel
2026-11-25;09h-12h;ANSM;Agathe Morel;Paillasse 2, vidéoprojecteur
2026-11-27;14h-17h;Partenaire scientifique;Inaya Girard;Paillasse 1
"@

"== Documents déposés"
Get-ChildItem $R -Recurse -File | ForEach-Object { $_.FullName.Replace("$R\", 'Z:\') }
