**free
ctl-opt nomain option(*srcstmt : *nodebugio);

/copy qrpglesrc,srv_prod_h

// -----------------------------------------------------------------
// Trouver un produit par son Code
// -----------------------------------------------------------------
dcl-proc PROD_get_by_code export;
  dcl-pi *n ind;
    p_code   like(t_produit.code) const;
    p_outDs  likeds(t_produit);
  end-pi;

  exec sql
    SELECT PR_ID, PR_CODE, PR_LIBELLE
    INTO :p_outDs.id, :p_outDs.code, :p_outDs.libelle
    FROM PRODUIT
    WHERE PR_CODE = :p_code;

  return (SQLCODE = 0); // Retourne *ON si trouve
end-proc;

// -----------------------------------------------------------------
// Trouver le produit suivant par Libelle (Gestion Pagination / Generique)
// -----------------------------------------------------------------
dcl-proc PROD_get_by_libelle export;
  dcl-pi *n ind;
    p_libelle  varchar(50) const;
    p_lastCode like(t_produit.code) const;
    p_outDs    likeds(t_produit);
  end-pi;

  // Si premier chargement (lastCode vide) : commence par p_libelle
  // Si page suivante : prend le superieur strict pour la pagination
  if p_lastCode = *blanks;
    exec sql
      SELECT PR_ID, PR_CODE, PR_LIBELLE
      INTO :p_outDs.id, :p_outDs.code, :p_outDs.libelle
      FROM PRODUIT
      WHERE UPPER(PR_LIBELLE) >= UPPER(:p_libelle)
      ORDER BY UPPER(PR_LIBELLE), PR_CODE
      FETCH FIRST 1 ROW ONLY;
  else;
    exec sql
      SELECT PR_ID, PR_CODE, PR_LIBELLE
      INTO :p_outDs.id, :p_outDs.code, :p_outDs.libelle
      FROM PRODUIT
      WHERE (UPPER(PR_LIBELLE)>(SELECT UPPER(PR_LIBELLE) FROM PRODUIT WHERE PR_CODE = :p_lastCode))
         OR (UPPER(PR_LIBELLE)=(SELECT UPPER(PR_LIBELLE) FROM PRODUIT WHERE PR_CODE = :p_lastCode)
         AND PR_CODE > :p_lastCode)
      ORDER BY UPPER(PR_LIBELLE), PR_CODE
      FETCH FIRST 1 ROW ONLY;
  endif;

  return (SQLCODE = 0);
end-proc;

 // -----------------------------------------------------------------
  // Trouver le produit suivant par Code (Pagination)
  // -----------------------------------------------------------------
  dcl-proc PROD_get_by_code_next export;
    dcl-pi *n ind;
      p_code     like(t_produit.code) const;
      p_lastCode like(t_produit.code) const;
      p_outDs    likeds(t_produit);
    end-pi;

    // Premier chargement (lastCode vide) : premier code >= p_code
    // Page suivante : code strictement superieur au dernier affiche
    if p_lastCode = *blanks;
      exec sql
        SELECT PR_ID, PR_CODE, PR_LIBELLE
        INTO :p_outDs.id, :p_outDs.code, :p_outDs.libelle
        FROM PRODUIT
        WHERE PR_CODE >= :p_code
        ORDER BY PR_CODE
        FETCH FIRST 1 ROW ONLY;
    else;
      exec sql
        SELECT PR_ID, PR_CODE, PR_LIBELLE
        INTO :p_outDs.id, :p_outDs.code, :p_outDs.libelle
        FROM PRODUIT
        WHERE PR_CODE > :p_lastCode
        ORDER BY PR_CODE
        FETCH FIRST 1 ROW ONLY;
    endif;

    return (SQLCODE = 0);
  end-proc;

// -----------------------------------------------------------------
// Sauvegarder (Creer ou Modifier)
// -----------------------------------------------------------------
dcl-proc PROD_save export;
  dcl-pi *n ind;
    p_dsProd  likeds(t_produit) const;
    p_mode    char(1) const;
  end-pi;

  if p_mode = '1' or p_mode = '3'; // Creation ou Duplication
    exec sql
      INSERT INTO PRODUIT (PR_CODE, PR_LIBELLE)
      VALUES(:p_dsProd.code, :p_dsProd.libelle);
  else; // Modification
    exec sql
      UPDATE PRODUIT
      SET PR_LIBELLE = :p_dsProd.libelle
      WHERE PR_CODE = :p_dsProd.code;
  endif;

  return (SQLCODE = 0);
end-proc;

// -----------------------------------------------------------------
// Supprimer un produit
// -----------------------------------------------------------------
dcl-proc PROD_delete export;
  dcl-pi *n ind;
    p_code   like(t_produit.code) const;
  end-pi;

  exec sql
    DELETE FROM PRODUIT WHERE PR_CODE = :p_code;

  return (SQLCODE = 0);
end-proc;
