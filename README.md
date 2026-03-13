# RollABrainrot

Projet Roblox type tycoon/collection autour des brainrots, avec architecture Rojo et scripts organises entre `ServerStorage`, `ReplicatedStorage`, `StarterPlayer` et `ServerScriptService`.

## Mecaniques principales

- Roll de brainrots avec raretes, mutations et systeme de skip.
- Gestion de base par slots avec cash passif par seconde.
- Auras, Aura Spin et systemes d'amelioration de brainrots.
- Fusion de brainrots avec timer, retour machine et preview resultat.
- Rebirth, shop, tools et progression joueur.
- Mutations de map serveur avec lighting dedie.
- Mode `AdminAbuse Disco` avec map speciale, musique playlist, disco ball, NPC danseurs et sky drops.

## Commandes admin IG

Le projet utilise Cmdr. Les commandes actuellement exposees dans le dossier `Cmdr/Commands` sont :

- `AdminAbuse <Mode> <Scope>` : modes dispo `Normal`, `Disco` ; scope `Local` ou `Global`.
- `SetMapMutation <Mutation> <Scope>` : mutations de map dispo `Normal`, `BubbleGum`, `Freeze`, `Solar`, `Spectral`, `Volcan`.
- `LuckServer <LuckBuff> [Time]` : applique un buff de luck global.
- `AddBrainrot <BrainrotName> <Mutation> [Slots] [Player]` : ajoute un brainrot.
- `RemoveBrainrot <Position> [Player]` : supprime un brainrot d'un slot.
- `MoveBrainrot <FromPosition> <ToPosition> [Player]` : deplace ou swap un brainrot.
- `SetMutation <Position> <Mutation> [Player]` : change la mutation d'un brainrot.
- `Brainrot <Position> <AurasNames> [Types] [Player]` : gere les auras d'un brainrot.
- `PrintBrainrot <Position> [Player]` : affiche l'etat detaille d'un brainrot.
- `ClearAuraSpin [Player]` : vide l'Aura Spin d'un joueur.
- `ReturnMachine <Position> [Player]` : retire un brainrot d'une machine.
- `SetFuseTime <Seconds> [Player]` : change le temps restant de fusion.
- `AddCurrency <Currency> <Amount> [Player]` : ajoute ou retire une currency.
- `SetCurrency <Currency> <Amount> [Player]` : fixe une currency a une valeur precise.

## Config partagée

Les principaux parametres de gameplay et de runtime sont centralises dans :

- `src/ReplicatedStorage/Shared/Config/GameConfig.luau`
- `src/ReplicatedStorage/Shared/Config/PlayerSettingsConfig.luau`

Ca permet de modifier plus vite les positions de map, les parametres disco, les prompts, les timeouts, la musique et quelques limites data sans reouvrir chaque script.

## Dev

Build du place file :

```bash
rojo build -o "RollABrainrot.rbxlx"
```

Sync avec Roblox Studio :

```bash
rojo serve
```

Le projet est prevu pour un workflow VS Code + Rojo.
