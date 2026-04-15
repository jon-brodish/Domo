import SwiftUI

struct HealthTrendSparkline: View {
    let points: [HealthTrendRecord]

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let values = points.map(\.score)
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 100
            let range = max(1, maxValue - minValue)

            Path { path in
                guard !points.isEmpty else { return }
                for index in points.indices {
                    let x = CGFloat(index) / CGFloat(max(points.count - 1, 1)) * width
                    let normalized = CGFloat(points[index].score - minValue) / CGFloat(range)
                    let y = height - (normalized * height)

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(
                LinearGradient(colors: [AppTheme.healthGood, AppTheme.healthExcellent], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
