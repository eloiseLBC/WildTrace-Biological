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
