**free
// Ce fichier contient les declarations des fonctions.
// On l'inclura (/copy) dans le Service Program ET dans
// les programmes utilisateurs (comme ton sous-fichier).

// Definition de la structure d'un produit (identique a la table)
dcl-ds t_produit qualified template;
  id       int(10);
  code     char(10);
  libelle  varchar(50);
end-ds;

// Prototypes des fonctions publiques
dcl-pr PROD_get_by_code ind extproc('PROD_get_by_code');
  p_code   like(t_produit.code) const;
  p_outDs  likeds(t_produit);
end-pr;

dcl-pr PROD_get_by_libelle ind extproc('PROD_get_by_libelle');
  p_libelle varchar(50) const;
  p_lastCode like(t_produit.code) const; // Pour la pagination
  p_outDs   likeds(t_produit);
end-pr;

 dcl-pr PROD_get_by_code_next ind extproc('PROD_get_by_code_next');
    p_code     like(t_produit.code) const;
    p_lastCode like(t_produit.code) const; // Pour la pagination
    p_outDs    likeds(t_produit);
  end-pr;


dcl-pr PROD_save ind extproc('PROD_save');
  p_dsProd  likeds(t_produit) const;
  p_mode    char(1) const; // '1'=Creation, '2'=Modif
end-pr;

dcl-pr PROD_delete ind extproc('PROD_delete');
  p_code   like(t_produit.code) const;
end-pr;
