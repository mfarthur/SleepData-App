import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var sleepData: [String: [String: String]] = [:]

    var body: some View {
        ScrollView { // Adiciona ScrollView ao redor do VStack
            VStack {
                Text("Dados do Sono")
                    .font(.title)

                ForEach(sleepData.keys.sorted(), id: \.self) { dateString in
                    if let sleepDetails = sleepData[dateString] {
                        VStack(alignment: .leading) {
                            Text(dateString)
                                .font(.headline)

                            if let timeInBed = sleepDetails["Tempo na Cama"] {
                                Text("Tempo na Cama: \(timeInBed)")
                            }

                            if let timeAsleep = sleepDetails["Tempo Dormindo"] {
                                Text("Tempo Dormindo: \(timeAsleep)")
                            }

                            if let awakeDuration = sleepDetails["Tempo Acordado"] {
                                Text("Tempo Acordado: \(awakeDuration)")
                            }

                            if let deepSleepDuration = sleepDetails["Tempo de Sono Profundo"] {
                                Text("Tempo de Sono Profundo: \(deepSleepDuration)")
                            }

                            if let remSleepDuration = sleepDetails["Tempo de Sono REM"] {
                                Text("Tempo de Sono REM: \(remSleepDuration)")
                            }

                            Divider()
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .onAppear {
                authorizeHealthKit()
            }
        }
    }

    func authorizeHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit não está disponível neste dispositivo.")
            return
        }

        let healthStore = HKHealthStore()

        // Solicitar autorização para ler os dados de análise do sono.
        let readTypes = Set([
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ])

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { (success, error) in
            if success {
                print("Permissão concedida")
                retrieveSleepData(healthStore: healthStore)
            } else if let error = error {
                print("Falha na autorização: \(error.localizedDescription)")
            }
        }
    }

    func retrieveSleepData(healthStore: HKHealthStore) {
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<7 {
            let startDate = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

            // Buscar dados de análise do sono.
            let query = HKSampleQuery(sampleType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, results, error) in
                guard let samples = results as? [HKCategorySample], error == nil else {
                    print("Falha ao buscar os dados do sono: \(error?.localizedDescription ?? "")")
                    return
                }

                var sleepDetails: [String: String] = [:]
                var timeInBed: TimeInterval = 0
                var timeAsleep: TimeInterval = 0
                var awakeDuration: TimeInterval = 0

                for sample in samples {
                    switch sample.value {
                    case HKCategoryValueSleepAnalysis.inBed.rawValue:
                        timeInBed += sample.endDate.timeIntervalSince(sample.startDate)
                    case HKCategoryValueSleepAnalysis.asleep.rawValue:
                        timeAsleep += sample.endDate.timeIntervalSince(sample.startDate)
                    case HKCategoryValueSleepAnalysis.awake.rawValue:
                        awakeDuration += sample.endDate.timeIntervalSince(sample.startDate)
                    default:
                        break
                    }
                }

                // Calcular o tempo de sono profundo e sono REM como proporção do tempo total dormindo.
                let totalSleepDuration = timeAsleep + awakeDuration
                let deepSleepDuration = timeAsleep * 0.15 // Assumir que 15% do tempo dormindo é sono profundo.
                let remSleepDuration = timeAsleep * 0.20 // Assumir que 20% do tempo dormindo é sono REM.

                DispatchQueue.main.async {
                    let dateFormatter = DateFormatter()
                    dateFormatter.locale = Locale(identifier: "pt_BR")
                    dateFormatter.dateStyle = .short
                    let dateString = dateFormatter.string(from: startDate)

                    sleepDetails["Tempo na Cama"] = self.formatTime(timeInBed)
                    sleepDetails["Tempo Dormindo"] = self.formatTime(timeAsleep)
                    sleepDetails["Tempo Acordado"] = self.formatTime(awakeDuration)
                    sleepDetails["Tempo de Sono Profundo"] = self.formatTime(deepSleepDuration)
                    sleepDetails["Tempo de Sono REM"] = self.formatTime(remSleepDuration)

                    self.sleepData[dateString] = sleepDetails
                }
            }

            healthStore.execute(query)
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time / 3600)
        let minutes = Int((time.truncatingRemainder(dividingBy: 3600)) / 60)

        return String(format: "%02d:%02d", hours, minutes)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
