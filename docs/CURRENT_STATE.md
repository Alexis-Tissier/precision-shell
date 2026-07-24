# État actuel — Precision Shell V28

## Environnement

- Fedora Linux
- Niri
- Quickshell
- Configuration principale : `shell.qml`

## Raccourcis

- `Super+D` : ouvrir ou fermer le dashboard
- `F1` : masquer les widgets
- `F2` : afficher la palette centrale
- `F3` : afficher le panneau de droite
- `F4` : afficher tous les widgets
- `Alt+Tab` : sélecteur de fenêtres Precision
- `Super+S` : paramètres Fedora
- `Super+Shift+S` : paramètres Precision
- `Super+L` : verrouillage

## Fonctions présentes

- recherche d'applications
- applications épinglées
- météo
- volume
- luminosité
- Wi-Fi
- Bluetooth
- batterie
- lecteur musical MPRIS
- menu de session
- écran de verrouillage personnalisé
- dashboard Super+D

## Organisation

- `system-config/quickshell/precision-shell/` : interface Quickshell
- `system-config/niri/` : configuration Niri
- `system-config/bin/` : scripts Precision
- `system-config/applications/` : lanceurs d'applications
- `system-config/gtklock/precision/` : écran de verrouillage
- `scripts/` : synchronisation et maintenance

## Valeurs privées

Les chemins personnels et la ville météo sont remplacés dans le dépôt par :

- `__HOME__`
- `__WEATHER_LOCATION__`
- `__DEVICE_NAME__`

La configuration active de la machine conserve les vraies valeurs.

## Méthode de version

Le développement reste sur la branche `main`.

Chaque état stable reçoit :

- un commit `V29 - description`
- un tag `V29`
