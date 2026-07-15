# Precision Shell

Nom technique temporaire d’un environnement de bureau Linux minimaliste,
construit avec Quickshell et Qt Quick/QML.

## Vision

Créer une expérience quotidienne calme au repos et puissante à la demande,
inspirée par la précision et la retenue du design automobile classique.

Le projet ne cherche pas à décorer GNOME ou Niri avec plusieurs modules
indépendants. Il vise à construire une couche visible cohérente :

- home minimaliste ;
- palette universelle ;
- barre d’état ;
- bibliothèque d’applications ;
- réglages rapides ;
- notifications ;
- intégration future avec un compositeur Wayland.

## État actuel

Prototype visuel exécuté dans GNOME avec une `FloatingWindow` Quickshell.

### Raccourcis

- `F1` : home ;
- `F2` : palette ;
- `F3` : réglages rapides ;
- `F4` : vue complète ;
- `F11` : plein écran ;
- `Ctrl+Q` : quitter.

## Lancement

```bash
qs -c precision-prototype
