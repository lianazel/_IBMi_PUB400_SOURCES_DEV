# RPG ILE Free-Form & SOA / MVVM Architecture

Full decoupling of user interface and data

**English** · [Français](README.fr.md)

A learning application built on the public system [PUB400.COM](https://pub400.com), one module at a time. Every
module follows the same split: a subfile list, a detail screen, and a service program that owns all data access.
The screens and their programs contain no SQL themselves.

The reference members live on the IBM i. This repository is a copy, downloaded with VS Code and the Code for IBM i
extension: one folder per source file, one file per member, the extension giving the source type. Source comments
and screen texts are in French.

## Modules

| Module | Status | Programs | Service program |
|---|---|---|---|
| Products | done | `PROD_LIST`, `PROD_DET` | `SRV_PROD` |
| Orders | planned | — | — |

## Products module

| Source file | Member | Role |
|---|---|---|
| `QDDSSRC` | `PROD_LST_F.DSPF` | List screen (subfile) |
| `QDDSSRC` | `PROD_DET_F.DSPF` | Detail screen |
| `QRPGLESRC` | `PROD_LIST.RPGLE` | List program |
| `QRPGLESRC` | `PROD_DET.RPGLE` | Detail program (create, change, copy, delete, display) |
| `QRPGLESRC` | `SRV_PROD.SQLRPGLE` | Service program module: the 5 SQL procedures |
| `QRPGLESRC` | `SRV_PROD_H.RPGLE` | Copybook: `t_produit` structure and prototypes |
| `QSRVSRC` | `SRV_PROD.BND` | Binder source: exports and signature `SRV_PROD_V1` |

The `PRODUIT` table (`PR_ID`, unique `PR_CODE`, `PR_LIBELLE`) is not in this repository.

### Build, in this order

`<LIB>` is the library that holds the source files, the table and the objects. Long commands are wrapped here for
reading: type them on a single line, or use the prompt (F4).

```
CRTDSPF    FILE(<LIB>/PROD_LST_F) SRCFILE(<LIB>/QDDSSRC) SRCMBR(PROD_LST_F)
CRTDSPF    FILE(<LIB>/PROD_DET_F) SRCFILE(<LIB>/QDDSSRC) SRCMBR(PROD_DET_F)
CRTSQLRPGI OBJ(<LIB>/SRV_PROD) SRCFILE(<LIB>/QRPGLESRC) SRCMBR(SRV_PROD)
           OBJTYPE(*MODULE) COMMIT(*NONE)
CRTSRVPGM  SRVPGM(<LIB>/SRV_PROD) MODULE(<LIB>/SRV_PROD)
           EXPORT(*SRCFILE) SRCFILE(<LIB>/QSRVSRC) SRCMBR(SRV_PROD)
CRTBNDDIR  BNDDIR(<LIB>/MYBNDDIR)
ADDBNDDIRE BNDDIR(<LIB>/MYBNDDIR) OBJ((<LIB>/SRV_PROD *SRVPGM))
CRTBNDRPG  PGM(<LIB>/PROD_DET) SRCFILE(<LIB>/QRPGLESRC) SRCMBR(PROD_DET)
CRTBNDRPG  PGM(<LIB>/PROD_LIST) SRCFILE(<LIB>/QRPGLESRC) SRCMBR(PROD_LIST)
```

Run: `CALL PROD_LIST`.

## Rules shared by all modules

- `COMMIT(*NONE)` as long as the tables are not journaled.
- `EXPORT(*SRCFILE)`: the signature comes from the binder source. The VS Code action "Create Service Program"
  (Ctrl+E) runs `EXPORT(*ALL)` and recomputes it: do not use it for a service program.
- A new export always goes **at the end** of the binder source, never in the middle: bound programs call a procedure
  by its position in that list, not by its place in the source.
- Check the binding: `DSPPGM PGM(<LIB>/PROD_LIST) DETAIL(*SRVPGM)` must list `SRV_PROD`.
