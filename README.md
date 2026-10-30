# Gestion des produits : RPG ILE free-form sur IBM i

Application d'apprentissage réalisée sur le système public [PUB400.COM](https://pub400.com) : une liste
en sous-fichier et une fiche de détail, qui ne font aucun SQL elles-mêmes et appellent un programme de
service pour tout accès aux données.

Les membres de référence sont sur l'IBM i. Ce dépôt en est la copie, téléchargée avec VS Code et
l'extension Code for IBM i : un dossier par fichier source, un fichier par membre, l'extension donnant
le type de source.

| Fichier source | Membre | Rôle |
|---|---|---|
| `QDDSSRC` | `PROD_LST_F.DSPF` | Écran de la liste (sous-fichier) |
| `QDDSSRC` | `PROD_DET_F.DSPF` | Écran de la fiche |
| `QRPGLESRC` | `PROD_LIST.RPGLE` | Programme de la liste |
| `QRPGLESRC` | `PROD_DET.RPGLE` | Programme de la fiche (création, modification, duplication, suppression, interrogation) |
| `QRPGLESRC` | `SRV_PROD.SQLRPGLE` | Module du programme de service : les 5 procédures SQL |
| `QRPGLESRC` | `SRV_PROD_H.RPGLE` | Copybook : structure `t_produit` et prototypes |
| `QSRVSRC` | `SRV_PROD.BND` | Source de liage : exports et signature `SRV_PROD_V1` |

La table `PRODUIT` (`PR_ID`, `PR_CODE` unique, `PR_LIBELLE`) n'est pas dans ce dépôt.

## Compiler, dans cet ordre

`<BIBLIO>` est la bibliothèque qui contient les fichiers source, la table et les objets.

```
CRTDSPF    FILE(<BIBLIO>/PROD_LST_F) SRCFILE(<BIBLIO>/QDDSSRC) SRCMBR(PROD_LST_F)
CRTDSPF    FILE(<BIBLIO>/PROD_DET_F) SRCFILE(<BIBLIO>/QDDSSRC) SRCMBR(PROD_DET_F)
CRTSQLRPGI OBJ(<BIBLIO>/SRV_PROD) SRCFILE(<BIBLIO>/QRPGLESRC) SRCMBR(SRV_PROD) OBJTYPE(*MODULE) COMMIT(*NONE)
CRTSRVPGM  SRVPGM(<BIBLIO>/SRV_PROD) MODULE(<BIBLIO>/SRV_PROD) EXPORT(*SRCFILE) SRCFILE(<BIBLIO>/QSRVSRC) SRCMBR(SRV_PROD)
CRTBNDDIR  BNDDIR(<BIBLIO>/MYBNDDIR)
ADDBNDDIRE BNDDIR(<BIBLIO>/MYBNDDIR) OBJ((<BIBLIO>/SRV_PROD *SRVPGM))
CRTBNDRPG  PGM(<BIBLIO>/PROD_DET) SRCFILE(<BIBLIO>/QRPGLESRC) SRCMBR(PROD_DET)
CRTBNDRPG  PGM(<BIBLIO>/PROD_LIST) SRCFILE(<BIBLIO>/QRPGLESRC) SRCMBR(PROD_LIST)
```

- `COMMIT(*NONE)` : la table n'est pas journalisée.
- `EXPORT(*SRCFILE)` : la signature vient de la source de liage. L'action « Create Service Program »
  de VS Code (Ctrl+E) lance `EXPORT(*ALL)` et la recalcule : ne pas l'utiliser pour `SRV_PROD`.
- Un nouvel export s'ajoute **à la fin** de `SRV_PROD.BND`, jamais au milieu : les programmes liés
  appellent une procédure par sa position dans cette liste, pas par sa place dans le source.
- Vérifier le liage : `DSPPGM PGM(<BIBLIO>/PROD_LIST) DETAIL(*SRVPGM)` doit citer `SRV_PROD`.

Lancer : `CALL PROD_LIST`.
