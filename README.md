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

## Why this architecture

| Term | Original meaning | Here |
|---|---|---|
| **SOA** (*Service-Oriented Architecture*) | Data access and business rules live in services, called through a contract | The `SRV_PROD` service program: 5 exported procedures, the `SRV_PROD_H` copybook as the contract; screen programs never touch a table |
| **MVVM** (*Model – View – ViewModel*) | The screen holds no logic; an intermediary prepares the data and reacts to user actions | *View* = the DDS display file; *ViewModel* = the RPG program behind the screen; *Model* = `SRV_PROD` and the table |

What it brings:

- **Change a screen without touching the SQL**, and the other way round.
- **Reuse**: the Orders module will be able to read products through `SRV_PROD`, without rewriting a line of SQL.
- **Open up**: the procedures of a service program can be exposed as web services (IBM i Integrated Web Services),
  without touching the screens.
- **Evolve without breaking**: the fixed signature lets new procedures be added, at the end of the binder source,
  without recompiling the existing programs.

Where the analogy stops: 5250 has no automatic data binding, the program fills the screen and reads the keys; and the
service is a bound call within the same job, not a network call.

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
