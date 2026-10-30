# RPG ILE Free-Form & Architecture SOA / MVVM

Découplage complet IHM et données

[English](README.md) · **Français**

Application d'apprentissage réalisée sur le système public [PUB400.COM](https://pub400.com), construite module par
module. Chaque module suit le même découpage : une liste en sous-fichier, une fiche de détail, et un programme de
service qui porte tout l'accès aux données. Les écrans et leurs programmes ne font aucun SQL eux-mêmes.

Les membres de référence sont sur l'IBM i. Ce dépôt en est la copie, téléchargée avec VS Code et l'extension
Code for IBM i : un dossier par fichier source, un fichier par membre, l'extension donnant le type de source.

## Modules

| Module | État | Programmes | Programme de service |
|---|---|---|---|
| Produits | fait | `PROD_LIST`, `PROD_DET` | `SRV_PROD` |
| Commandes | à venir | — | — |

## Pourquoi cette architecture

| Terme | Sens d'origine | Ici |
|---|---|---|
| **SOA** (*Service-Oriented Architecture*) | L'accès aux données et les règles métier vivent dans des services, appelés selon un contrat | Le programme de service `SRV_PROD` : 5 procédures exportées, le copybook `SRV_PROD_H` comme contrat ; les programmes d'écran ne touchent jamais une table |
| **MVVM** (*Model – View – ViewModel*) | L'écran ne contient aucune logique ; un intermédiaire prépare les données et réagit aux actions | *View* = l'écran DDS ; *ViewModel* = le programme RPG de l'écran ; *Model* = `SRV_PROD` et la table |

Ce que ça apporte :

- **Changer un écran sans toucher au SQL**, et l'inverse.
- **Réutiliser** : le module Commandes pourra lire les produits par `SRV_PROD`, sans réécrire une ligne de SQL.
- **Ouvrir** : les procédures d'un programme de service peuvent être exposées en service web (IBM i Integrated Web
  Services), sans toucher aux écrans.
- **Évoluer sans casser** : la signature fixe permet d'ajouter des procédures, à la fin de la source de liage, sans
  recompiler les programmes existants.

Où l'analogie s'arrête : il n'y a pas de liaison de données automatique en 5250, c'est le programme qui remplit
l'écran et lit les touches ; et le service est un appel lié, dans le même travail, pas un appel réseau.

## Module Produits

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

### Compiler, dans cet ordre

`<BIBLIO>` est la bibliothèque qui contient les fichiers source, la table et les objets. Les commandes longues sont
coupées ici pour la lecture : elles se saisissent sur une seule ligne, ou par l'invite (F4).

```
CRTDSPF    FILE(<BIBLIO>/PROD_LST_F) SRCFILE(<BIBLIO>/QDDSSRC) SRCMBR(PROD_LST_F)
CRTDSPF    FILE(<BIBLIO>/PROD_DET_F) SRCFILE(<BIBLIO>/QDDSSRC) SRCMBR(PROD_DET_F)
CRTSQLRPGI OBJ(<BIBLIO>/SRV_PROD) SRCFILE(<BIBLIO>/QRPGLESRC) SRCMBR(SRV_PROD)
           OBJTYPE(*MODULE) COMMIT(*NONE)
CRTSRVPGM  SRVPGM(<BIBLIO>/SRV_PROD) MODULE(<BIBLIO>/SRV_PROD)
           EXPORT(*SRCFILE) SRCFILE(<BIBLIO>/QSRVSRC) SRCMBR(SRV_PROD)
CRTBNDDIR  BNDDIR(<BIBLIO>/MYBNDDIR)
ADDBNDDIRE BNDDIR(<BIBLIO>/MYBNDDIR) OBJ((<BIBLIO>/SRV_PROD *SRVPGM))
CRTBNDRPG  PGM(<BIBLIO>/PROD_DET) SRCFILE(<BIBLIO>/QRPGLESRC) SRCMBR(PROD_DET)
CRTBNDRPG  PGM(<BIBLIO>/PROD_LIST) SRCFILE(<BIBLIO>/QRPGLESRC) SRCMBR(PROD_LIST)
```

Lancer : `CALL PROD_LIST`.

## Règles communes à tous les modules

- `COMMIT(*NONE)` tant que les tables ne sont pas journalisées.
- `EXPORT(*SRCFILE)` : la signature vient de la source de liage. L'action « Create Service Program » de VS Code
  (Ctrl+E) lance `EXPORT(*ALL)` et la recalcule : ne pas l'utiliser pour un programme de service.
- Un nouvel export s'ajoute **à la fin** de la source de liage, jamais au milieu : les programmes liés appellent une
  procédure par sa position dans cette liste, pas par sa place dans le source.
- Vérifier le liage : `DSPPGM PGM(<BIBLIO>/PROD_LIST) DETAIL(*SRVPGM)` doit citer `SRV_PROD`.
