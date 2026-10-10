# FUI-RestedXP

Habillage **RestedXP Guides** (RXP) **autonome** (sans EllesmereUI)
pour World of Warcraft **Forever** et **Midnight 12.1+** : thème, reskin de
la fenêtre de guide, flèche de navigation et route sur la carte, le tout
réglable dans sa propre fenêtre d'options (`/fuirxp`).

Auteur : **Fr33noX**. Le moteur de reskin de la fenêtre de guide (layouts,
flèches, animations) est adapté du module RestedXP de **LiteTweaks 1.46**
par Jo, avec son autorisation explicite. Si LiteTweaks est installé avec
son reskin RestedXP actif, FUI-RestedXP le signale au login par une
**popup à trois choix** (désactiver le reskin de LiteTweaks / celui de
cet addon / garder les deux) ; des liens cliquables équivalents restent
dans le chat.

Le **cadre de la flèche de RestedXP** peut lui aussi être tenu transparent
par quelque chose qui vit à côté : la nôtre est dessinée dedans, elle
disparaît donc avec lui. FUI-RestedXP le signale au login — une fois, sans
nommer personne et sans proposer de désactiver quoi que ce soit — et
`/fuirxp status` en affiche l'état (« arrow frame: ok »). Tant que le cadre
est ainsi tenu, les deux flèches ne peuvent pas coexister.

## Ce que fait l'addon

1. **Thème RXP « Fr33noX-UI »** : un thème RestedXP dont les couleurs
   (fonds, bords, pins de carte, tooltip) suivent **l'accent choisi sur la
   page Theme** : orange feu par défaut (repris d'EllesmereUI
   automatiquement s'il est installé), ou la *Custom Color* (*Follow
   Accent* off).
2. **Reskin de la fenêtre de guide** : panneaux sombres plats, bords fins
   accent, bannières teintées accent, flèche de navigation teintée. Le
   reskin est ré-appliqué après chaque repaint de RXP (hooks sur
   `UpdateVisuals` / `UpdateFrame` / `UpdateText`, debouncés à une fois par
   frame), et cède la place quand vous choisissez un autre thème RXP.
3. **Fenêtre d'options autonome** : pages Reskin / Map / Theme / Changelog,
   recherche globale sur les réglages, échelle de la fenêtre (curseur
   Échelle, 60–130 %), fenêtre redimensionnable — sans aucune dépendance
hors RestedXP Guides.

## Installation

1. Copiez le dossier `FUI-RestedXP` dans le dossier `Interface\AddOns`
   de votre client WoW (celui qui contient déjà le dossier `RXPGuides`).
2. Relancez le jeu ou faites `/reload`.
3. Sélectionnez le thème **"Fr33noX-UI by FUI-RestedXP"** dans
   `RXP Settings > Guide Window > Theme` — ou cliquez simplement
   **Activate in RestedXP** sur la page *Theme* des options (bouton qui
   fait la sélection pour vous). Un indicateur de statut y montre si le
   thème est bien actif.
   > La page *Theme* pilote **toutes** les couleurs de l'addon (thème RXP,
   reskin Classic, teinte de flèche) via une source unique : l'accent
   (*Follow Accent*, défaut) ou la *Custom Color*.
4. **Réglages** : `/fuirxp` ouvre la fenêtre d'options, avec les pages
   Reskin / Map / Theme / Changelog et un champ de recherche global.
   > La barre d'onglets du module ne montre que la page d'apparence du
   > **layout actif** (Timeline sélectionné → seul l'onglet Timeline ;
   > RestedXP d'origine ou moteur désactivé → aucun). Le changement de layout
   > ou le toggle « Reskin RestedXP » reconstruit la barre immédiatement.

## Commandes

- `/fuirxp` : ouvre la fenêtre d'options
- `/fuirxp status` : état de l'addon et couleur accent détectée
- `/fuirxp reset` : remettre les réglages par défaut

## Réinitialisation

Le bouton **Reset to Defaults** (page *Reskin*) restaure **toute** la
 configuration de l'addon :
 layout, style de flèche et ses couleurs, opacité de fenêtre, source de
 couleur du thème, numéros d'étapes, étapes listées, tailles, polices,
 unité de distance — et remet l'échelle de la fenêtre RXP à 100 %.
 Les réglages propres à RestedXP (position de fenêtre, guides suivis) ne
 sont pas touchés.

## Réglages (FUIRestedXPCache, éditable dans WTF)

- `rxpLayout` : le look de la fenêtre de guide —
  `FRAMELESS` (texte contourné
  sur le monde), `TIMELINE` (fenêtre à ligne numérotée), `COMPACT`
  (barre de titre « ‹ 2/189 › », icônes RXP par ligne, barre de
  progression), `ZYGOR` (style Zygor : onglet, objectifs sur bande rouge,
  barre verte), `BIT8` (quest log pixel-art : Silkscreen/VT323, scanlines
  CRT, boutons ◀ B / A ▶) ou `DEFAULT` (fenêtre de RXP intacte).
- **Dans tous les layouts** : clic gauche sur une étape en cours = la
  sauter (animation verte « Skipped »), clic droit = revenir à l'étape
  précédente (retour animé « Back ») ; molette = faire défiler la liste ;
  double-clic sur une étape listée = y aller. Chaque layout a sa propre
  page d'apparence dans la fenêtre d'options (polices, tailles, fondu,
  couleurs).
- `rxpArrowStyle` : la flèche de navigation, **l'ensemble complet** —
  `LAYOUT` (celle du layout), `CHEVRON`, `CARD`, `CLASSIC`
  (flèche 3D ombrée : verte face au point, jaune de côté, rouge dos),
  `ZYGOR` (flèche façon Zygor + temps restant), `RAIL` (tête d'aiguille
  pliée, moitié sombre = relief ; défaut du layout Rail) ou `RAILC` (la même
  idée dans un anneau, aiguille à deux facettes). Card se teinte par la
  distance (rouge > 100, jaune, vert < 30).
- `rxpMeters` : distance de la flèche en « m » (1 yd = 1 m dans WoW : seul
  le label change). Fonctionne avec la flèche du moteur (Custom Arrow on)
  **et** avec la flèche d'origine de RXP (Custom Arrow off — réécriture en
  direct du texte « 177yd » de RXP).
- `rxpBoxLock` (défaut : true) : **les icônes d'objectif collées à la fenêtre**.
  Les boîtes de cibles et d'objets de RestedXP restent sous la fenêtre de
  guide et la suivent dans tous les layouts. décoché, on les déplace au
  glisser gauche n'importe où sur l'écran et elles y restent — dans tous les
  layouts et d'une session à l'autre (position enregistrée en `rxpBoxFree`).
- `rxpArrowETA` (défaut : true) : le temps restant (« 1:23 » / « 45s », en
  jaune) sur **toutes** les flèches personnalisées (Chevron, Card, Classic,
  Zygor-style, Rail, Rail Compass). Off = la distance seule.
- Polices : la clé `uiFont` (page *Theme*, ligne **Default Font**, défaut :
  **Overpass**) est la police de toute l'interface de l'addon. Les looks
  (`rxpFlFont`/`rxpCpFont`/`rxpZgFont`/`rxpTlFont`...) suivent cette même
  police par défaut via le choix **FUI Global Font** (l'entrée renommée
  d'anciennes « EUI Global Font » ; une police choisie explicitement sur
  une page de look reste pinée). Le 8-Bit garde ses polices pixel
  (Silkscreen / VT323).
- `skinForceClassic` (défaut : true) : garde la **fenêtre guide classique**
  de RXP disponible. ⚠️ L'option **"Guide Window v2"** (Interface V2, Beta)
  de RXP **cache entièrement** la fenêtre classique (fenêtre, étapes,
  barre de défilement) : le reskin Classic comme les autres layouts n'ont
  alors plus rien à habiller ni à lire. Avec cette option, l'addon détecte
  v2, le désactive et affiche un message (un `/reload` achève la
  restauration) ; passez-la à false pour laisser v2 tourner.
- `rxpHideNums` : masque les numéros d'étapes et la ligne verticale
- `rxpUpcoming` : nombre d'étapes à venir listées — **0** les masque
  totalement (le header "Step X of Y" et le % restent)
- La **seule habillage personnalisé** est le **thème** (page *Theme*) :
  « Fr33noX-UI by FUI-RestedXP », dont les couleurs suivent l'accent
  (*Follow Accent*, défaut) ou la *Custom Color*. Tout le reste
  de la fenêtre est le moteur de reskin, inchangé. Quand ce thème est
  sélectionné dans RXP et que la flèche personnalisée est désactivée
  (ou layout RestedXP d'origine), la **flèche lisible du thème Blue** de
  RXP (fichier v2) est utilisée et teintée avec la même couleur (accent
  live ou custom) au lieu de la flèche sombre du jeu de textures DarkMode.
- `themeFollowAccent` : le thème suit l'accent (défaut : true)
- `themeR/G/B` : couleur custom quand `themeFollowAccent` est false

## Dépannage

- Le bouton **Activate in RestedXP** (page Theme) doit répondre
  "theme activated". S'il répond que RXP n'est pas chargé, ouvrez une fois
  les réglages de RestedXP (pour initialiser son profil), puis réessayez.
- Le thème apparaît dans le dropdown de RXP comme
  **"Fr33noX-UI by FUI-RestedXP"**. S'il manque : vérifiez que RXPGuides
  est bien installé dans la même instance de jeu que FUI-RestedXP.

## Version

**Dernière version : 1.1.0** — première publication de la **version
autonome** : aucune dépendance hors RestedXP Guides, fenêtre d'options
propre (Reskin / Map / Theme / Changelog, recherche globale, échelle
60–130 %, redimensionnable), commandes `/fuirxp`. Le contenu reprend la
1.1.0 : la **route sur la carte du monde** (page MAP, désactivée par défaut)
— une droite de vous vers l'objectif courant, dans la couleur d'accent,
avec au choix les six objectifs suivants enchaînés derrière — et **la même
route sur la minimap** ; les **superpositions du guide** (circuits de farm,
patrouilles, zones de recherche) avec leurs couleurs propres et une opacité
commune ; les **info-bulles sur les marqueurs** de la carte (étape,
distance, direction, ETA, quête) ; l'**ombre floue de la flèche** dans le
bloc Flèche (expansion et couleur, désactivée par défaut) ; la **ligne de
récupération de cadavre** ; l'avertissement quand le cadre de la flèche est
tenu transparent de l'extérieur ; et les correctifs : compteur d'objectif
affiché deux fois, et ETA au-delà d'une heure (« 1:01:01 » au lieu
de « 61:01 »). Le détail est dans l'onglet Changelog (`/fuirxp`).

## Compatibilité

- **RestedXP Guides** doit être installé (l'addon ne fait que l'habiller).
- Aucune autre dépendance : EllesmereUI n'est ni requis ni utilisé — s'il
  est présent, son accent est repris comme accent par défaut.
- Clients : Forever (16001) et Midnight (120000-120100).
- Le code ne touche jamais aux fichiers de RXP : tout passe par ses API
  publiques (`RegisterTheme`, global `RXPGuides_Themes`) et des hooks.

## Licence

Voir [LICENSE.txt](LICENSE.txt). Addon fourni « en l'état », tous droits
réservés (Fr33noX), avec attribution : moteur de reskin adapté de
LiteTweaks 1.46 par Jo, avec son autorisation explicite ; flèche de thème
reconstruite depuis l'art de RestedXP Guides ; polices tiers sous leurs
licences propres (OFL pour Silkscreen, VT323 et Overpass).

## Historique (série 3.4.x)

3.4.17 — la teinte de flèche suit à nouveau l'accent EUI en direct
(ré-enregistrement à l'API skin d'EUI perdu au changement de moteur), et se
ré-applique dès l'activation du thème.

3.4.16 — la flèche teintée par le thème utilise le fichier v2 (thème Blue,
lisible) au lieu de la flèche sombre de DarkMode.

3.4.15 — « Reskin RestedXP » est en tête de la page Reskin : quand il est
désactivé, les blocs Layout et Arrow disparaissent de la page. Le toggle
Guide Window prévient désormais qu'un /reload est nécessaire dans les deux
sens (la v2 de RXP détruit les scripts de la fenêtre classique).

3.4.14 — la page Reskin regroupe les réglages de flèche dans leur propre
bloc « ARROW » (Custom Arrow, Arrow Style, Meters, Time to Waypoint).

3.4.13 — le statut du thème (« Color source ») se met à jour aussi quand
on bascule « Follow Accent ».

3.4.12 — boutons Activate / Deactivate côte à côte sur la page Theme, et
le statut du thème se rafraîchit dès le clic.

3.4.11 — bouton « Deactivate in RestedXP » sur la page Theme : rend la
fenêtre au thème d'origine de RXP (RXP Blue) sans ouvrir ses réglages.

3.4.10 — la flèche d'origine de RXP suit la couleur de la page Theme
(accent EUI live ou couleur custom) au lieu de rester noire.

3.4.9 — la barre d'onglets des options EUI ne montre plus que la page
d'apparence du layout actif (une seule à la fois).

3.4.8 — « Time to Waypoint » étendu à **toutes** les flèches
personnalisées (Chevron, Card, Classic 3D, Zygor-style).

3.4.7 — option « Time to Waypoint » pour afficher ou masquer le temps
restant de la flèche Zygor-style.

3.4.6 — le texte de distance/temps est de retour sur **toutes** les flèches
(le motif du 3.4.5 n'acceptait qu'une lettre d'unité et rejetait « yd »).

3.4.5 — réparation du temps restant (« 1:23 » / « 45s ») de la flèche
Zygor-style : le parseur du moteur accepte de nouveau les deux unités et le
label de flèche est réécrit dans les deux sens (yd ↔ m), sans boucle.

3.4.4 — « Meters (m) on the Arrow » fonctionne à nouveau quand
« Custom Arrow » est désactivé (réécriture en direct du texte de flèche de
RXP, sans conflit avec la carte du moteur).

## Fichiers

- `Core.lua` - DB, accent, détection du chargement de RXP, slash,
  polices embarquées (Overpass / Expressway)
- `Theme.lua` - thème RXP dérivé de l'accent (canaux officiels)
- `Skin.lua` - garde-fou Guide Window v2, réécriture d'unité de distance,
  activation/désactivation du thème, teinte de flèche
- `Reskin.lua` - moteur complet de reskin (adapté de LiteTweaks 1.46, voir
  ci-dessus) : cinq layouts
  maison (**Frameless**, **Timeline**, **Compact**, **Zygor-style**,
  **8-Bit**, **Rail**), animations de cartes
  (sauter/revenir), icônes RXP par ligne, barres de progression, boîtes
  Active Targets/Items, désactivation des annonces RXP, flèches de
  navigation universelles (dont TomTom et Zygor Stealth réelles), couleurs
  noms ennemis/objets
- `MapRoute.lua` - route sur la carte du monde : droite du joueur vers
  l'objectif courant du guide, puis les étapes suivantes enchaînées, le tout
  dans la couleur d'accent. Chaque étape est entourée d'un cercle (huit
  points sur la circonférence plus un au centre), des chevrons
  (`rxp-chevron.png`) parcourent le trait pour porter la direction, chaque
  segment porte un halo sombre et son épaisseur suit le zoom. Les coordonnées sont
  lues dans les données de RestedXP (jamais écrites) et le tracé est fait
  sur le canvas de la carte, donc il suit le zoom et le panoramique. Les
  traits ne prélevent que l'intérieur plat d'une texture blanche du jeu, donc
  son bord n'est jamais étiré sur la carte. Désactivée par défaut
  (page MAP des options)
- `Textures/` - les textures du moteur (chevron, flèches card /
  classic / zygor, check, back, prev, next, tri, flèche de thème HQ)
- `Options.lua` - fenêtre de réglages autonome (recherche, échelle,
  redimensionnement)
- `OptionsView.lua` / `Controls.lua` - moteur de la fenêtre : lignes
  (toggles, sliders à rail étirable, listes, couleurs) et widgets
- `FUIOptions.lua` - pages de réglages : Reskin, Map (route carte du
  monde + minimap), Theme (accent, police), Changelog, et une page
d'apparence par layout actif
- `About.lua` - page d'accueil de la fenêtre d'options
