**free
// ---------------- -------------------------------------------------
// PROD_DET : Programme de detail (Appelle son propre ecran PROD_DET_F)
// -----------------------------------------------------------------
ctl-opt dftactgrp(*no) actgrp(*caller) option(*srcstmt : *nodebugio) bnddir('MYBNDDIR');

// Declaration du fichier ecran SPECIFIQUE au detail
dcl-f PROD_DET_F workstn indds(WkInd);

// Inclusion des prototypes du Service Program (contient t_produit, PROD_get_by_code, PROD_save, etc
/copy qrpglesrc,srv_prod_h

// Interface d'entree (Parametres recus de la liste)
dcl-pi *n;
  p_Mode    char(1);
  p_Code    like(t_produit.code);
end-pi;

// Variable structure de donnees pour echanger avec le Service Program
dcl-ds unProduit likeds(t_produit);
dcl-ds unExistant likeds(t_produit);   // Produit deja en base (controle du code)

dcl-ds WkInd len(99);
  Exit      ind pos(3);
  Cancel    ind pos(12);
  Confirm   ind pos(10); // F10 : confirmer la suppression
  ProtCode  ind pos(40); // Proteger le champ Code
  ProtLib   ind pos(41); // Proteger le champ Libelle
  ModeSuppr ind pos(42); // Affiche le mode en rouge (suppression)
end-ds;

// --- INITIALISATION ---
Reset_Indic();
Clear_Fields();

// Chargement des donnees via le Service Program (sauf si creation pure)
if p_Mode <> '1';
  if PROD_get_by_code(p_Code : unProduit);
    D_ID      = unProduit.id;
    D_CODE    = unProduit.code;
    D_LIBELLE = unProduit.libelle;
  endif;
endif;

// - - - - - - - - - - - - - - - -
// PREPARATION ECRAN : Adapter les protections de l'ecran selon le Mode recu
// - - - - - - - - - - - - - - - -
select;
  when p_Mode = '1'; // Création
    D_MODE = 'CREATION';
  when p_Mode = '2'; // Modifier
    D_MODE = 'MODIFICATION';
    ProtCode = *on;  // Interdit de modifier la cle unique (Code)
  when p_Mode = '3'; // Dupliquer
    D_MODE = 'DUPLICATION';
    D_ID = 0;        // L'ID sera auto-genere, le code devra etre change par l'utilisateur
  when p_Mode = '4'; // Supprimer
    D_MODE = 'SUPPRESSION';
    ModeSuppr = *on;  // Mode affiche en rouge
    ProtCode  = *on;  // Tout est bloque en suppression : Code protégé
    ProtLib   = *on;  // Tout est bloque en suppression : Libellé protégé
    // Chargement d'un texte bas écran pour rappeler qu'il faut confirmer par F10
    D_MSG = 'F10 pour confirmer la suppression, F12 pour annuler.';
  when p_Mode = '5'; // Interroger
    D_MODE = 'INTERROGATION';
    ProtCode = *on;  // Tout est bloque en Interrogation
    ProtLib  = *on;
endsl;

// - - - - - - - - - - - - - - - -
// TRAITEMENT REPONSE UTILISATEUR : Boucle Ecran
// - - - - - - - - - - - - - - - -
dow not Exit and not Cancel;
  exfmt PR_DET;
  D_MSG = *blanks;                     // Le message disparait a l'Entree suivante

  if Exit or Cancel;
    leave;
  endif;

  // Validation des donnees via le Service Program
  select;
     // -- Création OU Modification OU Duplication
     when p_Mode = '1' or p_Mode = '3' or p_Mode = '2';
        unProduit.code = D_CODE;
        unProduit.libelle = D_LIBELLE;
        if D_CODE = *blanks;
          D_MSG = 'Le code est obligatoire.';
        // En creation ou duplication, le code ne doit pas deja exister
        elseif p_Mode <> '2' and PROD_get_by_code(D_CODE : unExistant);
          D_MSG = 'Le code ' + %trim(D_CODE) + ' existe deja.';
        elseif PROD_save(unProduit : p_Mode);
          leave;
        else;
          D_MSG = 'Enregistrement refuse par la base.';
        endif;

      when p_Mode = '4'; // Suppression
        If not confirm;
             D_MSG = 'Appuyez sur F10 pour confirmer la suppression.';
        ElseIf PROD_delete(D_CODE);
         leave;
        Else ;
        D_MSG = 'Suppression refusee par la base.';
      endif;


       when p_Mode = '5'; // Interrogation : rien a enregistrer
        leave;           // Entree ramene a la liste



  endsl;
enddo;

// - - - - - - - - - - - - -
// ** Important *** : *INLR à *ON
// - - - - - - - - - - - - -
 *inlr = *on;  // Fin complete : le prochain appel repart de valeurs initiales
return;

// --- PROCEDURES INTERNES ---
dcl-proc Reset_Indic;
  ProtCode = *off;
  ProtLib  = *off;
end-proc;

dcl-proc Clear_Fields;
  D_ID = 0;
  D_CODE = *blanks;
  D_LIBELLE = *blanks;
end-proc;
