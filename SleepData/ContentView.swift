import SwiftUI
import HealthKit

struct ContentView: View {
    @State private var sleepData: [Date: [String: TimeInterval]] = [:]

    var body: some View {
        VStack {
            Text("Sleep Data")
                .font(.title)

            ForEach(sleepData.keys.sorted(by: >).prefix(5), id: \.self) { date in
                VStack {
                    Text(dateFormatter.string(from: date))
                        .font(.headline)

                    if let metrics = sleepData[date] {
                        ForEach(metrics.keys.sorted(), id: \.self) { metric in
                            HStack {
                                Text(metric)
                                Spacer()
                                if let time = metrics[metric] {
                                    Text(formatTime(time))
                                } else {
                                    Text("N/A")
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .onAppear {
            authorizeHealthKit()
        }
    }

    func authorizeHealthKit() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device.")
            return
        }

        let healthStore = HKHealthStore()

        let readTypes = Set([HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!])

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { (success, error) in
            if success {
                print("Permission granted")
                retrieveSleepData(healthStore: healthStore)
            } else if let error = error {
                print("Authorization failed: \(error.localizedDescription)")
            }
        }
    }

    func retrieveSleepData(healthStore: HKHealthStore) {
        let calendar = Calendar.current
        let now = Date()

        for dayOffset in 0..<5 { // Only fetch data for the last 5 days
            let startDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -dayOffset, to: now)!)
            let endDate = calendar.date(byAdding: .day, value: 1, to: startDate)!

            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

            let query = HKSampleQuery(sampleType: HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { (query, results, error) in
                guard let samples = results as? [HKCategorySample], error == nil else {
                    print("Failed to retrieve sleep data: \(error?.localizedDescription ?? "")")
                    return
                }

                var sleepMetrics: [String: TimeInterval] = ["Acordado": 0, "REM": 0, "Essencial": 0, "Profundo": 0]

                for sample in samples {
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)
                    if sample.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue {
                        sleepMetrics["Tempo Dormindo"] = (sleepMetrics["Tempo Dormindo"] ?? 0) + duration
                    } else if sample.value == HKCategoryValueSleepAnalysis.awake.rawValue {
                        sleepMetrics["Acordado"] = (sleepMetrics["Acordado"] ?? 0) + duration
                    } else if sample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue {
                        sleepMetrics["Essencial"] = (sleepMetrics["Essencial"] ?? 0) + duration
                    } else if sample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue {
                        sleepMetrics["Profundo"] = (sleepMetrics["Profundo"] ?? 0) + duration
                    } else if sample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
                        sleepMetrics["REM"] = (sleepMetrics["REM"] ?? 0) + duration
                    }
                }

                DispatchQueue.main.async {
                    self.sleepData[startDate] = sleepMetrics
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

    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
