import Charts
import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Query private var allAppointments: [Appointment]
    @State private var period: StatsPeriod = .weekly

    private var windowedAppointments: [Appointment] {
        StatisticsHelper.appointments(allAppointments, in: StatisticsHelper.window(for: period))
    }

    var body: some View {
        Form {
            if allAppointments.isEmpty {
                ContentUnavailableView(
                    "예약 데이터가 없습니다",
                    systemImage: "chart.bar",
                    description: Text("예약이 등록되면 통계가 표시됩니다.")
                )
            } else {
                Section {
                    Picker("기간", selection: $period) {
                        ForEach(StatsPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    PeriodCountChart(counts: StatisticsHelper.periodCounts(windowedAppointments, period: period))
                } header: {
                    Text("기간별 예약 건수")
                } footer: {
                    Text("아직 오지 않은 예약도 포함됩니다.")
                }

                Section("서비스 유형별 비중") {
                    if windowedAppointments.isEmpty {
                        emptyPeriodText
                    } else {
                        ServiceShareChart(shares: StatisticsHelper.serviceShares(windowedAppointments))
                    }
                }

                Section("요일·시간대 분포") {
                    if windowedAppointments.isEmpty {
                        emptyPeriodText
                    } else {
                        WeekdayHourHeatmap(cells: StatisticsHelper.weekdayHourGrid(windowedAppointments))
                    }
                }

                Section("단골 고객 순위") {
                    let customers = StatisticsHelper.topCustomers(windowedAppointments)
                    if customers.isEmpty {
                        emptyPeriodText
                    } else {
                        ForEach(Array(customers.enumerated()), id: \.element.id) { index, customer in
                            if let dog = customer.dog {
                                NavigationLink {
                                    DogDetailView(dog: dog)
                                } label: {
                                    TopCustomerRow(rank: index + 1, customer: customer)
                                }
                            } else {
                                TopCustomerRow(rank: index + 1, customer: customer)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("예약 통계")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyPeriodText: some View {
        Text("해당 기간에 예약이 없습니다.")
            .foregroundStyle(.secondary)
    }
}

private struct PeriodCountChart: View {
    let counts: [PeriodCount]

    var body: some View {
        Chart(counts) { item in
            BarMark(
                x: .value("기간", item.label),
                y: .value("건수", item.count)
            )
            .foregroundStyle(item.isCurrent ? Color.accentColor : Color.accentColor.opacity(0.4))
            .cornerRadius(4)
            .annotation(position: .top) {
                if item.count > 0 {
                    Text("\(item.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartXScale(domain: counts.map(\.label))
        .frame(height: 180)
        .padding(.vertical, 4)
    }
}

private struct ServiceShareChart: View {
    let shares: [ServiceShare]

    var body: some View {
        Chart(shares) { share in
            SectorMark(
                angle: .value("건수", share.count),
                innerRadius: .ratio(0.6),
                angularInset: 1.5
            )
            .foregroundStyle(serviceColor(for: share.service))
            .cornerRadius(3)
        }
        .chartLegend(.hidden)
        .frame(height: 180)
        .padding(.vertical, 4)

        ForEach(shares) { share in
            HStack {
                Text(share.service.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(serviceColor(for: share.service))
                    .clipShape(Capsule())
                Spacer()
                Text("\(share.count)건 (\(Int((share.ratio * 100).rounded()))%)")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func serviceColor(for service: ServiceType) -> Color {
        let index = ServiceType.allCases.firstIndex(of: service) ?? 0
        return Appointment.pastelColors[index % Appointment.pastelColors.count]
    }
}

private struct WeekdayHourHeatmap: View {
    let cells: [WeekdayHourCell]

    private var maxCount: Int {
        max(cells.map(\.count).max() ?? 1, 1)
    }

    var body: some View {
        Chart(cells) { cell in
            RectangleMark(
                x: .value("시간", "\(cell.hour)"),
                y: .value("요일", cell.weekdaySymbol)
            )
            .foregroundStyle(Color.accentColor.opacity(opacity(for: cell.count)))
        }
        .chartXScale(domain: (TimeSlotHelper.workStartHour..<TimeSlotHelper.workEndHour).map { "\($0)" })
        .chartYScale(domain: StatisticsHelper.workdaySymbols)
        .chartXAxisLabel("시", alignment: .trailing)
        .frame(height: 180)
        .padding(.vertical, 4)
    }

    private func opacity(for count: Int) -> Double {
        guard count > 0 else { return 0.06 }
        return 0.2 + 0.8 * Double(count) / Double(maxCount)
    }
}

private struct TopCustomerRow: View {
    let rank: Int
    let customer: TopCustomer

    var body: some View {
        HStack {
            Text("\(rank)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(customer.displayName)
                if customer.isUpcomingOnly {
                    Text("예약 예정")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(customer.lastVisit, format: .dateTime.year().month().day())
                        .environment(\.locale, Locale(identifier: "ko_KR"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(customer.count)회")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        StatisticsView()
    }
    .modelContainer(for: [Appointment.self, Dog.self, DayOff.self], inMemory: true)
}
