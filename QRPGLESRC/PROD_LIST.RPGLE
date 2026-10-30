**free
// -----------------------------------------------------------------------------
// Nom du Programme : PROD_LST
// Role             : Gestion du Sous-Fichier Produit (Vue-Modele / Controleur)
// Architecture     : SOA / MVVM - Decouplage complet IHM et Donnees
// Version          : V1.0.0
// -----------------------------------------------------------------------------

// 1. DIRECTIVES DE CONTROLE (Standardisees pour l'environnement ILE moderne)
ctl-opt dftactgrp(*no)
        actgrp(*new)
        option(*srcstmt : *nodebugio)
        bnddir('MYBNDDIR'); // Liaison automatique avec le Service Program SRV_PROD

// 2. DECLARATIONS DES COMPOSANTS D'INTERFACE (VUES)
// Declaration du fichier ecran de liste avec renvoi des indicateurs dans une structure dediee
dcl-f PROD_LST_F workstn sfile(SFLREG:RRN) indds(WkInd);

// 3. INCLUSION DU CONTRAT D'INTERFACE (MODEL / SERVICES)
// Le copybook contient la structure "t_produit" et les prototypes du *SRVPGM
/copy qrpglesrc,srv_prod_h

// 4. VARIABLES GLOBALES DE GESTION DU SOUS-FICHIER
dcl-s RRN       zoned(4:0);               // relative Record Number du sous-fichier
dcl-s LastCode  like(t_produit.code);     // Sauvegarde du dernier Code lu (Pivot pagination)
dcl-s LastLib   like(t_produit.libelle);  // Sauvegarde du dernier Libelle lu (Pivot pagination)
dcl-s SavCode   like(W_CODE);            // Recherche par code appliquee au sous-fichier
dcl-s SavLib    like(W_LIB);             // Recherche par libelle appliquee au sous-fichier
dcl-s RRNOption like(RRN);               // Ligne de la derniere option traitee (0 = aucune)

// 5. STRUCTURE DE DONNEES DES INDICATEURS (Remplacement des pointeurs systeme *INxx)
dcl-ds WkInd len(99);
  Exit      ind pos(3);   // F3 : Quitter le programme
  Cancel    ind pos(12);  // F12 : Retour
  CreateF6  ind pos(6);   // F6 : Demande de creation produit
  SwitchF16 ind pos(16);  // F16 : Inverser le mode de recherche (Code <-> Alpha)
  PageDown  ind pos(25);  // Page suivante (PAGEDOWN)
  SflDsp    ind pos(31);  // Conditionne l'affichage des lignes du SFL (SFLREAD)
  SflDspCtl ind pos(32);  // Conditionne l'affichage du format de contrle
  SflClr    ind pos(33);  // Force la mise a blanc / RAZ du SFL
  SflEnd    ind pos(34);  // Gere l'affichage du "+ / MORE" en bas du SFL
  ModeAlpha ind pos(45);  // TRUE = Recherche Alphabetique, FALSE = Recherche par Code
  SflError  ind pos(49);  // TRUE = Active l'affichage du format de message d'erreur
end-ds;

// 6. PROTOTYPE DU PROGRAMME DE DETAIL (Appel dynamique IHM a IHM)
dcl-pr PROD_DET extpgm('PROD_DET');
  p_Mode    char(1) const;
  p_Code    like(t_produit.code) const;
end-pr;


// =============================================================================
// PROGRAMME PRINCIPAL (Boucle evenementielle)
// =============================================================================

// Initialisation par defaut : Recherche par Code (Ind 45 a OFF)
ModeAlpha = *off;

// Premier positionnement et chargement de la premiere page d'ecran
Action_InitialiserRecherche();

dow not Exit;
 // legende des touches (ligne 23)
    write FKEYS;
// ecriture du format de contrle du sous-fichier
    write W_CTL;

  // Si une erreur d'option a ete levee au tour precedent, on affiche la ligne de message
  if SflError;
    write MSGRCD;
  endif;

  // Affichage combine et attente d'une action de l'utilisateur
  exfmt W_CTL;

  // On eteint l'indicateur d'erreur des que l'utilisateur appuie sur une touche
  SflError = *off;

  if Exit;
    leave; // Sortie de la boucle principale
  endif;

  // Aiguillage selon la touche de fonction interceptee
  select;
    when CreateF6;
      // Appel du detail en mode Creation ('1'), sans cle de produit
      PROD_DET('1' : *blanks);
      // Reinitialisation de la liste pour voir apparaitre le nouveau produit
      Action_InitialiserRecherche();

    when PageDown;
            // Le systeme rend la main quand on depasse les lignes chargees
            if not SflEnd;
              Action_ChargerPageSuivante();
            endif;

    when SwitchF16;
      // Inversion de l'etat logique de l'interrupteur (Bascule l'affichage d'en-tete)
      ModeAlpha = not ModeAlpha;
      // Nettoyage des filtres de saisie precedents
      W_CODE = *blanks;
      W_LIB = *blanks;
      // Repositionnement complet au debut du nouvel index choisi
      Action_InitialiserRecherche();

      // Gestion d'une demande de positionnement en recherche par Code OU en recherche ALPHA
      when (not ModeAlpha and W_CODE <> SavCode)
            or (ModeAlpha and W_LIB <> SavLib);
            // Nouvelle valeur de recherche : on repositionne le sous-fichier
            Action_InitialiserRecherche();

    other;
      // Traitement des options saisies dans les lignes du SFL (2, 3, 4)
      if Action_TraiterSfl() and RRNOption > 0;
        // Si le traitement s'est bien passe (aucune option invalide)
        // Et que l'utilisateur a scrolle vers le bas (Page+ declenche par l'OS)

        // Rechargement (la liste reflete les modifications de PROD_DET),
        // puis retour sur la ligne de la derniere option traitee
         Action_InitialiserRecherche();
         Action_Repositionner(RRNOption);
        endif;

        endsl;
enddo;

// Clture propre du programme et liberation du groupe d'activation (*NEW)
*inlr = *on;
return;


// =============================================================================
// PROCEDURES INTERNES (Encapsulation de la logique applicative)
// =============================================================================

// -----------------------------------------------------------------------------
// Action_InitialiserRecherche : Remet a zero le SFL et prepare le positionnement
// -----------------------------------------------------------------------------
dcl-proc Action_InitialiserRecherche;
  // etape A : Commande de vidage (Clear) du sous-fichier
  SflDsp    = *off;
  SflDspCtl = *off;
  SflClr    = *on;
  write W_CTL;

  // etape B : Reactivation des contrles
  SflClr    = *off;
  SflDspCtl = *on;
  RRN = 0;
  SflEnd = *off;

  // etape C : Reinitialisation des pivots de pagination
  LastCode = *blanks;
  LastLib  = *blanks;
  SavCode = W_CODE;   // Memorise la recherche qui vient d'etre appliquee
  SavLib  = W_LIB;

  // etape D : Chargement du tout premier bloc de 15 lignes
  Action_ChargerPageSuivante();
end-proc;


// -----------------------------------------------------------------------------
// Action_ChargerPageSuivante : Gere la pagination dynamique decouplee (Page+)
// -----------------------------------------------------------------------------
dcl-proc Action_ChargerPageSuivante;
  dcl-ds monProduit likeds(t_produit); // Structure d'echange locale
  dcl-s Compteur int(10) inz(0);
  dcl-s Trouve ind;
  dcl-s PremierRRN like(RRN);    // avec les autres dcl-s de la procedure

   PremierRRN = RRN + 1;          // juste avant le dow
  // Boucle de chargement limitee a la taille d'une page ecran (15 lignes)
  dow Compteur < 15 and RRN < 9999;

    // =========================================================================
    // TRAITEMENT DU MODE DE RECHERCHE PAR CODE (Cle primaire)
    // =========================================================================
    if not ModeAlpha;
      // Au premier tour (RRN=0) et si l'utilisateur a saisi un filtre dans W_CODE
      if RRN = 0 and W_CODE <> *blanks;
        Trouve = PROD_get_by_code_next(W_CODE : *blanks : monProduit);
      else;
        // Pour les lignes suivantes, on repart du dernier code affiche pour paginer
        Trouve = PROD_get_by_code_next(*blanks : LastCode : monProduit);
      endif;

    // =========================================================================
    // TRAITEMENT DU MODE DE RECHERCHE ALPHABETIQUE (Index Libelle)
    // =========================================================================
    else;
      // Au premier tour (RRN=0) et si l'utilisateur a saisi un filtre dans W_LIB
      if RRN = 0 and W_LIB <> *blanks;
        Trouve = PROD_get_by_libelle(W_LIB : *blanks : monProduit);
      else;
        // Pour les lignes suivantes, on s'appuie sur la cle pivot LastCode
        Trouve = PROD_get_by_libelle(*blanks : LastCode : monProduit);
      endif;
    endif;

    // Si le Service Program ne trouve plus rien (Fin de fichier SQL / SQLCODE=100)
    if not Trouve;
      SflEnd = *on; // On allume le temoin de fin : bloque le "Page+" a l'ecran
      leave;
    endif;

    // Memorisation des pivots indispensables pour le prochain enregistrement
    LastCode = monProduit.code;
    LastLib  = monProduit.libelle;

    // Incrementation et ecriture physique dans l'IHM
    Compteur += 1;
    RRN += 1;

    // Remplissage des variables du format d'enregistrement de l'ecran DDS
    S_OPT      = *blanks;
    PR_CODE    = monProduit.code;
    PR_LIBELLE = monProduit.libelle;

    write SFLREG; // Ajout physique de la ligne dans le sous-fichier
  enddo;

  if RRN >= PremierRRN;          // apres le enddo
      W_RRN = PremierRRN;          // page a afficher (SFLRCDNBR)
  endif;

  // Si on a charge au moins une ligne, on autorise l'affichage du SFL
  if RRN > 0;
    SflDsp = *on;
  endif;
end-proc;


// -----------------------------------------------------------------------------
// Action_TraiterSfl : Analyse les choix de l'utilisateur (READC) et distribue
// -----------------------------------------------------------------------------
dcl-proc Action_TraiterSfl;
  dcl-pi *n ind;
end-pi; // Retourne TRUE si tout est OK, FALSE si erreur d'option

  dcl-s OptionValide ind inz(*on);
  RRNOption = 0;


  // L'instruction READC lit uniquement les lignes modifiees par l'utilisateur
  readc SFLREG;

  dow not %eof;
    if S_OPT <> *blanks;

      // VALIDATION DU CONTROLEUR : Verification de la validite de l'option
      if S_OPT <> '2' and S_OPT <> '3' and S_OPT <> '4' and S_OPT <> '5';
        SflError = *on;       // Declenche l'apparition du format d'erreur en bas d'ecran
        *in49    = *on;       // Allume la video inverse (DSPATR(RI)) sur le champ S_OPT
        OptionValide = *off;  // Bloque la pagination pour forcer la correction
        update SFLREG;        // Modifie visuellement la ligne a l'ecran
      else;
        // L'option est correcte -> On eteint l'indicateur de video inverse pour cette ligne
        *in49 = *off;

        // Routage de l'action vers le programme de detail approprie
        select;
          when S_OPT = '2';

          PROD_DET('2' : PR_CODE); // Modification
          when S_OPT = '3';
          PROD_DET('3' : PR_CODE); // Duplication
          when S_OPT = '4';
          PROD_DET('4' : PR_CODE); // Suppression
          when S_OPT = '5';
          PROD_DET('5' : PR_CODE); // Interrogation
        endsl;

        // Mémorisation du dernier enregistrement du ss fichier traité
        RRNOption = RRN;

        // RAZ de l'option apres execution reussie
        S_OPT = ' ';
        update SFLREG;
      endif;

    endif;

    // Lecture de la ligne modifiee suivante
    readc SFLREG;
  enddo;

  return OptionValide;
end-proc;

 // -----------------------------------------------------------------------------
  // Action_Repositionner : charge les pages utiles et affiche la ligne demandee
  // -----------------------------------------------------------------------------
  dcl-proc Action_Repositionner;
    dcl-pi *n;
      p_RRN like(RRN) const;
    end-pi;

    // Charger page apres page jusqu'a la ligne demandee, ou jusqu'a la fin du fichier
    dow RRN < p_RRN and not SflEnd;
      Action_ChargerPageSuivante();
    enddo;

    // Page de la ligne, curseur dessus (SFLRCDNBR(CURSOR))
    if RRN >= p_RRN;
      W_RRN = p_RRN;
    elseif RRN > 0;
      W_RRN = RRN;     // liste plus courte (ligne supprimee) : derniere ligne
    endif;
  end-proc;
