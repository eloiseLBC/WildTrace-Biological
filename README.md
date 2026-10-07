## Fonctionnalités V1

- Demande d'autorisation HealthKit.
- Sélection d'une plage de dates.
- Récupération des données Apple Health :
  - fréquence cardiaque,
  - HRV,
  - SpO2,
  - fréquence respiratoire,
  - sommeil,
  - pas,
  - calories,
  - distance,
  - entraînements.
- Génération d'un fichier raw JSON par jour.
- Génération optionnelle d'un résumé daily JSON.
- Upload vers Oracle Cloud via Pre-Authenticated Request.
- Historique local pour éviter de renvoyer les mêmes fichiers.

## Chemins Oracle produits

```text
collected/to_compute/biological_raw_YYYY-MM-DD.json
collected/computed/biological_daily_YYYY-MM-DD.json
```

** Flux de l'application
```
BiologicalSyncView
    ↓
BiologicalSyncViewModel
    ↓
BiologicalSyncService
    ↓
HealthKitService
    ↓
OracleStorageService
    ↓
SyncHistoryService
```

** Structure bucket visée
Les fichiers générés iront ici :
```
wildtrace-biological/
  collected/
    to_compute/
      biological_raw_2026-05-26.json

    computed/
      biological_daily_2026-05-26.json
```


## Localisation lors de la synchronisation

Le bouton existant capture une position ponctuelle de l’iPhone si la plage inclut aujourd’hui. Autorisation « pendant l’utilisation », précision maximale de 100 m, position datant de moins de 60 s et délai maximal de 30 s. Aucune collecte permanente ni application Watch.

Le raw conserve `location` (coordonnées, timestamp ISO 8601, précision et source). Le computed ajoute `city_country` et `location_metadata`. Le lieu correspond au clic, pas à une ville dominante. Une journée passée ne reçoit jamais la position actuelle. Les refus et échecs laissent la collecte biologique continuer ; un échec de géocodage conserve les coordonnées et produit `{}`. Aucun pays ou lieu aquatique n’est inventé.

Les fichiers d’aujourd’hui sont réenvoyés même avec l’option ignorer activée. Une journée passée n’est ignorée que si tous les exports demandés ont été envoyés. Une nouvelle capture remplace la référence du jour. Les uploads terminés survivent à une réinstallation ; les captures non envoyées ne sont pas conservées après fermeture.

Validation sur iPhone : autorisation accordée/refusée, localisation désactivée, précision approximative, plage historique seule, plage incluant aujourd’hui, nouvelle synchronisation le même jour, échec réseau et entraînement passant minuit. Les géocodages Apple peuvent produire des libellés différents d’OpenCage.
