import SwiftUI

struct BiologicalSyncView: View {
    
    @StateObject private var viewModel: BiologicalSyncViewModel
    
    init(viewModel: BiologicalSyncViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                oracleSection
                dateRangeSection
                optionsSection
                actionsSection
                logsSection
            }
            .navigationTitle("WildTrace Biological")
        }
    }
    
    private var oracleSection: some View {
        Section("Oracle Cloud") {
            HStack {
                Text("Bucket cible")
                Spacer()
                Text("wildtrace-biological")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Text("Configuration")
                Spacer()
                Text(AppConfig.oraclePARBaseURL.isEmpty ? "Manquante" : "Intégrée")
                    .foregroundStyle(AppConfig.oraclePARBaseURL.isEmpty ? .red : .green)
            }
            
            Text("L’URL Oracle PAR est définie directement dans AppConfig.swift. Aucun champ de saisie n’est nécessaire dans l’application.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
    
    private var dateRangeSection: some View {
        Section("Plage de synchronisation") {
            DatePicker(
                "Date début",
                selection: $viewModel.startDate,
                displayedComponents: .date
            )
            
            DatePicker(
                "Date fin",
                selection: $viewModel.endDate,
                displayedComponents: .date
            )
            
            Button("Aujourd’hui") {
                viewModel.selectToday()
            }
            
            Button("7 derniers jours") {
                viewModel.selectLastSevenDays()
            }
        }
    }
    
    private var optionsSection: some View {
        Section("Options") {
            Toggle(
                "Envoyer le résumé daily dans computed/",
                isOn: $viewModel.uploadDailyComputed
            )
            .onChange(of: viewModel.uploadDailyComputed) { _, _ in
                viewModel.saveSettings()
            }
            
            Toggle(
                "Ignorer les fichiers déjà synchronisés",
                isOn: $viewModel.skipAlreadySynced
            )
            .onChange(of: viewModel.skipAlreadySynced) { _, _ in
                viewModel.saveSettings()
            }
            
            Button("Réinitialiser l’historique local") {
                viewModel.clearLocalHistory()
            }
            .foregroundStyle(.red)
        }
    }
    
    private var actionsSection: some View {
        Section("Actions") {
            Button("Autoriser l’accès aux données Santé") {
                Task {
                    await viewModel.requestHealthAuthorization()
                }
            }
            
            Button {
                Task {
                    await viewModel.sync()
                }
            } label: {
                if viewModel.isSyncing {
                    HStack {
                        ProgressView()
                        Text("Synchronisation en cours…")
                    }
                } else {
                    Text("Synchroniser vers Oracle Cloud")
                }
            }
            .disabled(viewModel.isSyncing || !viewModel.canSync)
        }
    }
    
    private var logsSection: some View {
        Section("Logs") {
            if viewModel.logs.isEmpty {
                Text("Aucun log pour le moment.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.logs.indices.reversed(), id: \.self) { index in
                    Text(viewModel.logs[index])
                        .font(.footnote.monospaced())
                }
            }
        }
    }
}
