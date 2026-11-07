import SwiftUI

/// Simulated monitor: values come from the course; traces illustrate the pulse rhythm.
struct PatientMonitorView: View {
    let heartRate: Int
    let oxygenSaturation: Int
    let systolic: Int
    let diastolic: Int
    let respiratoryRate: Int
    let temperature: Double

    private let ecgColor = Color(red: 0.68, green: 0.94, blue: 0.24)
    private let plethColor = Color(red: 0.57, green: 0.91, blue: 0.96)
    private let pressureColor = Color(red: 1, green: 0.65, blue: 0.18)
    private var meanPressure: Int {
        Int(((Double(systolic) + 2 * Double(diastolic)) / 3).rounded())
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("PATIENT MONITOR")
                Spacer()
                Text("SIMULATION")
            }
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundStyle(.gray)

            channel(label: "II", metric: "HR", unit: "bpm", value: heartRate,
                    color: ecgColor, isECG: true)
            channel(label: "Pleth", metric: "SpO₂", unit: "%", value: oxygenSaturation,
                    color: plethColor, isECG: false)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("NIBP")
                    Text("mmHg").font(.system(size: 12))
                    Spacer()
                    Text("MAP ≈ \(meanPressure)").font(.system(size: 12))
                }
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                HStack(alignment: .firstTextBaseline, spacing: 20) {
                    Text("\(systolic)/\(diastolic)")
                    Text("(\(meanPressure))")
                }
                .font(.system(size: 72, weight: .regular, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .foregroundStyle(pressureColor)

            HStack {
                Text("RR  \(respiratoryRate) /min")
                Spacer()
                Text(String(format: "TEMP  %.1f °C", temperature))
            }
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .foregroundStyle(.white.opacity(0.8))
        }
        .padding(18)
        .frame(width: 640, height: 404)
        .background(.black)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
    }

    private func channel(label: String, metric: String, unit: String, value: Int,
                         color: Color, isECG: Bool) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, design: .monospaced))
                MonitorTrace(heartRate: heartRate, isECG: isECG)
                    .stroke(color, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                    .frame(height: 68)
                    .clipped()
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(metric)
                    Spacer()
                    Text(unit).font(.system(size: 12))
                }
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                Text("\(value)")
                    .font(.system(size: 86, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 155)
        }
        .foregroundStyle(color)
        .frame(height: 108)
    }
}

/// Schematic traces, not measured ECG or plethysmography signals.
private struct MonitorTrace: Shape {
    let heartRate: Int
    let isECG: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let beats = Double(max(0, min(heartRate, 300))) / 60 * 4
        for sample in 0...480 {
            let x = Double(sample) / 480
            let phase = (x * beats).truncatingRemainder(dividingBy: 1)
            let amplitude: Double
            if heartRate <= 0 {
                amplitude = 0
            } else if isECG {
                amplitude = 0.12 * pulse(phase, center: 0.16, width: 0.035)
                    - 0.15 * pulse(phase, center: 0.30, width: 0.012)
                    + 0.94 * pulse(phase, center: 0.34, width: 0.013)
                    - 0.22 * pulse(phase, center: 0.38, width: 0.016)
                    + 0.23 * pulse(phase, center: 0.62, width: 0.07)
            } else {
                amplitude = 0.75 * pulse(phase, center: 0.27, width: 0.10)
                    + 0.20 * pulse(phase, center: 0.52, width: 0.065)
            }
            let point = CGPoint(x: rect.minX + x * rect.width,
                                y: rect.minY + (0.78 - amplitude * 0.65) * rect.height)
            if sample == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func pulse(_ phase: Double, center: Double, width: Double) -> Double {
        exp(-pow((phase - center) / width, 2) / 2)
    }
}

struct PatientMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        PatientMonitorView(heartRate: 80, oxygenSaturation: 99, systolic: 123,
                           diastolic: 82, respiratoryRate: 16, temperature: 36.8)
    }
}
