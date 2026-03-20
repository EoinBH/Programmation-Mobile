import UIKit

class GraphView: UIView {
    
    var glucoseRecords: [GlucoseRecord] = [] {
        didSet {
            selectedIndex = nil
            setNeedsDisplay()
        }
    }
    
    var selectedHours: Int = 3 {
        didSet {
            selectedIndex = nil
            setNeedsDisplay()
        }
    }
    
    var selectedUnit: GlucoseUnit = .mmolL {
        didSet {
            selectedIndex = nil
            setNeedsDisplay()
        }
    }
    
    var contentInsets = UIEdgeInsets(top: 56, left: 16, bottom: 34, right: 52)
    
    private let gridColor = UIColor.systemGray5
    private let normalZoneColor = UIColor.systemGreen.withAlphaComponent(0.08)
    private let warningZoneColor = UIColor.systemOrange.withAlphaComponent(0.10)
    private let urgentZoneColor = UIColor.systemRed.withAlphaComponent(0.10)
    
    private var displayedRecords: [GlucoseRecord] = []
    private var displayedPoints: [CGPoint] = []
    private var selectedIndex: Int?
    private let touchRadius: CGFloat = 24
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        
        drawCardBackground()
        
        let plotRect = bounds.inset(by: contentInsets)
        guard plotRect.width > 40, plotRect.height > 40 else { return }
        
        guard !glucoseRecords.isEmpty else {
            displayedRecords = []
            displayedPoints = []
            drawEmptyState(in: plotRect)
            return
        }
        
        let sorted = glucoseRecords.sorted { $0.systemTime < $1.systemTime }
        
        guard !sorted.isEmpty else {
            displayedRecords = []
            displayedPoints = []
            drawEmptyState(in: plotRect)
            return
        }
        
        displayedRecords = sorted
        
        let displayedValues = sorted.map { displayedValue(from: $0.value) }
        
        guard let minData = displayedValues.min(),
              let maxData = displayedValues.max(),
              let latestValue = displayedValues.last else { return }
        
        let low = displayedLowThreshold()
        let warning = displayedWarningThreshold()
        let urgent = displayedUrgentThreshold()
        
        let padding = selectedUnit == .mmolL ? 1.0 : 18.0
        let minYValue = min(minData, low) - padding
        let maxYValue = max(maxData, urgent) + padding
        let valueRange = max(maxYValue - minYValue, 1.0)
        
        func yPosition(for value: Double) -> CGFloat {
            let normalized = (value - minYValue) / valueRange
            return plotRect.maxY - CGFloat(normalized) * plotRect.height
        }
        
        func xPosition(for index: Int, total: Int) -> CGFloat {
            guard total > 1 else { return plotRect.maxX }
            return plotRect.minX + CGFloat(index) * (plotRect.width / CGFloat(total - 1))
        }
        
        drawZones(
            in: plotRect,
            yLow: yPosition(for: low),
            yWarning: yPosition(for: warning),
            yUrgent: yPosition(for: urgent)
        )
        
        drawHorizontalGrid(in: plotRect, ctx: ctx)
        
        drawThresholdLine(
            y: yPosition(for: low),
            in: plotRect,
            color: .systemRed,
            label: "Bas \(formatValue(low))"
        )
        
        drawThresholdLine(
            y: yPosition(for: warning),
            in: plotRect,
            color: .systemOrange,
            label: "Alerte \(formatValue(warning))"
        )
        
        drawThresholdLine(
            y: yPosition(for: urgent),
            in: plotRect,
            color: .systemRed,
            label: "Urgent \(formatValue(urgent))"
        )
        
        var points: [CGPoint] = []
        for (index, displayedValue) in displayedValues.enumerated() {
            let point = CGPoint(
                x: xPosition(for: index, total: displayedValues.count),
                y: yPosition(for: displayedValue)
            )
            points.append(point)
        }
        displayedPoints = points
        
        let currentLineColor = colorForValue(latestValue)
        
        drawTrendLine(points: points, color: currentLineColor)
        drawDots(points: points, color: currentLineColor)
        
        if let lastPoint = points.last {
            drawCurrentReadingMarker(at: lastPoint, color: currentLineColor)
        }
        
        drawCurrentValueHeader(value: latestValue, color: currentLineColor)
        drawBottomTicks(in: plotRect, hours: selectedHours)
        
        if let selectedIndex,
           selectedIndex >= 0,
           selectedIndex < displayedPoints.count,
           selectedIndex < displayedRecords.count {
            let point = displayedPoints[selectedIndex]
            let record = displayedRecords[selectedIndex]
            let displayedValue = displayedValue(from: record.value)
            
            drawSelectedPoint(at: point, color: colorForValue(displayedValue))
            drawTooltip(
                at: point,
                value: displayedValue,
                dateText: formattedDisplayDate(from: record.displayTime)
            )
        }
    }
    
    // MARK: - Touch handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouch(touches)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        handleTouch(touches)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        // garder la sélection visible
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        selectedIndex = nil
        setNeedsDisplay()
    }
    
    private func handleTouch(_ touches: Set<UITouch>) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        guard !displayedPoints.isEmpty else { return }
        
        var nearestIndex: Int?
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        
        for (index, point) in displayedPoints.enumerated() {
            let dx = point.x - location.x
            let dy = point.y - location.y
            let distance = sqrt(dx * dx + dy * dy)
            
            if distance < nearestDistance {
                nearestDistance = distance
                nearestIndex = index
            }
        }
        
        if let nearestIndex, nearestDistance <= touchRadius {
            selectedIndex = nearestIndex
        } else {
            selectedIndex = nil
        }
        
        setNeedsDisplay()
    }
    
    // MARK: - Background
    
    private func drawCardBackground() {
        let cardPath = UIBezierPath(roundedRect: bounds, cornerRadius: 18)
        UIColor.white.setFill()
        cardPath.fill()
        
        layer.cornerRadius = 18
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.withAlphaComponent(0.08).cgColor
        layer.shadowOpacity = 1
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 10
    }
    
    private func drawEmptyState(in rect: CGRect) {
        let text = "Aucune donnée"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 15, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        let size = text.size(withAttributes: attributes)
        let origin = CGPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        )
        text.draw(at: origin, withAttributes: attributes)
    }
    
    // MARK: - Zones
    
    private func drawZones(in rect: CGRect, yLow: CGFloat, yWarning: CGFloat, yUrgent: CGFloat) {
        let normalRect = CGRect(
            x: rect.minX,
            y: yWarning,
            width: rect.width,
            height: yLow - yWarning
        )
        normalZoneColor.setFill()
        UIBezierPath(rect: normalRect).fill()
        
        let warningRect = CGRect(
            x: rect.minX,
            y: yUrgent,
            width: rect.width,
            height: yWarning - yUrgent
        )
        warningZoneColor.setFill()
        UIBezierPath(rect: warningRect).fill()
        
        let urgentRect = CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: yUrgent - rect.minY
        )
        urgentZoneColor.setFill()
        UIBezierPath(rect: urgentRect).fill()
    }
    
    // MARK: - Grid
    
    private func drawHorizontalGrid(in rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.setStrokeColor(gridColor.cgColor)
        ctx.setLineWidth(0.8)
        
        let rows = 5
        for i in 0...rows {
            let y = rect.minY + CGFloat(i) * rect.height / CGFloat(rows)
            ctx.move(to: CGPoint(x: rect.minX, y: y))
            ctx.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }
    
    // MARK: - Thresholds
    
    private func drawThresholdLine(y: CGFloat, in rect: CGRect, color: UIColor, label: String) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addLine(to: CGPoint(x: rect.maxX, y: y))
        path.lineWidth = 1.3
        
        color.withAlphaComponent(0.9).setStroke()
        path.stroke()
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: color
        ]
        
        let labelSize = label.size(withAttributes: attributes)
        let labelPoint = CGPoint(
            x: rect.maxX + 6,
            y: y - labelSize.height / 2
        )
        label.draw(at: labelPoint, withAttributes: attributes)
    }
    
    // MARK: - Header
    
    private func drawCurrentValueHeader(value: Double, color: UIColor) {
        let title = "Glycémie actuelle (\(selectedHours)h)"
        let unitText = selectedUnit == .mmolL ? "mmol/L" : "mg/dL"
        let valueText = "\(formatValue(value)) \(unitText)"
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .bold),
            .foregroundColor: color
        ]
        
        title.draw(at: CGPoint(x: 16, y: 12), withAttributes: titleAttributes)
        valueText.draw(at: CGPoint(x: 16, y: 26), withAttributes: valueAttributes)
    }
    
    // MARK: - Graph
    
    private func drawTrendLine(points: [CGPoint], color: UIColor) {
        guard points.count > 1 else { return }
        
        let path = UIBezierPath()
        path.lineWidth = 2.5
        path.lineJoinStyle = .round
        path.lineCapStyle = .round
        
        path.move(to: points[0])
        
        for i in 1..<points.count {
            let previous = points[i - 1]
            let current = points[i]
            let mid = CGPoint(
                x: (previous.x + current.x) / 2,
                y: (previous.y + current.y) / 2
            )
            path.addQuadCurve(to: mid, controlPoint: previous)
            path.addQuadCurve(to: current, controlPoint: current)
        }
        
        color.setStroke()
        path.stroke()
    }
    
    private func drawDots(points: [CGPoint], color: UIColor) {
        for point in points.dropLast() {
            let dotRect = CGRect(x: point.x - 2.5, y: point.y - 2.5, width: 5, height: 5)
            let dotPath = UIBezierPath(ovalIn: dotRect)
            color.setFill()
            dotPath.fill()
        }
    }
    
    private func drawCurrentReadingMarker(at point: CGPoint, color: UIColor) {
        let outerRect = CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16)
        let outerPath = UIBezierPath(ovalIn: outerRect)
        UIColor.white.setFill()
        outerPath.fill()
        
        color.setStroke()
        outerPath.lineWidth = 2.5
        outerPath.stroke()
    }
    
    private func drawSelectedPoint(at point: CGPoint, color: UIColor) {
        let outerRect = CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)
        let innerRect = CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)
        
        let outerPath = UIBezierPath(ovalIn: outerRect)
        UIColor.white.setFill()
        outerPath.fill()
        color.setStroke()
        outerPath.lineWidth = 2.5
        outerPath.stroke()
        
        let innerPath = UIBezierPath(ovalIn: innerRect)
        color.setFill()
        innerPath.fill()
    }
    
    // MARK: - Tooltip
    
    private func drawTooltip(at point: CGPoint, value: Double, dateText: String) {
        let unitText = selectedUnit == .mmolL ? "mmol/L" : "mg/dL"
        let valueText = "\(formatValue(value)) \(unitText)"
        let fullText = "\(dateText)\n\(valueText)"
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph
        ]
        
        let attributed = NSAttributedString(string: fullText, attributes: attributes)
        let textBounds = attributed.boundingRect(
            with: CGSize(width: 140, height: 60),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        let bubbleWidth = max(110, ceil(textBounds.width) + 20)
        let bubbleHeight = ceil(textBounds.height) + 16
        
        var bubbleX = point.x - bubbleWidth / 2
        var bubbleY = point.y - bubbleHeight - 18
        
        bubbleX = max(8, min(bubbleX, bounds.width - bubbleWidth - 8))
        if bubbleY < 8 {
            bubbleY = point.y + 18
        }
        
        let bubbleRect = CGRect(x: bubbleX, y: bubbleY, width: bubbleWidth, height: bubbleHeight)
        let bubblePath = UIBezierPath(roundedRect: bubbleRect, cornerRadius: 12)
        
        UIColor.black.withAlphaComponent(0.82).setFill()
        bubblePath.fill()
        
        let textRect = bubbleRect.insetBy(dx: 10, dy: 8)
        attributed.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }
    
    // MARK: - Bottom labels
    
    private func drawBottomTicks(in rect: CGRect, hours: Int) {
        let labels = [
            "-\(hours)h",
            "-\(hours * 2 / 3)h",
            "-\(hours / 3)h",
            "Maint."
        ]
        
        let positions: [CGFloat] = [
            rect.minX,
            rect.minX + rect.width * 0.33,
            rect.minX + rect.width * 0.66,
            rect.maxX
        ]
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: UIColor.secondaryLabel
        ]
        
        for (index, label) in labels.enumerated() {
            let size = label.size(withAttributes: attributes)
            let x: CGFloat
            
            if index == 0 {
                x = positions[index]
            } else if index == labels.count - 1 {
                x = positions[index] - size.width
            } else {
                x = positions[index] - size.width / 2
            }
            
            let point = CGPoint(x: x, y: rect.maxY + 8)
            label.draw(at: point, withAttributes: attributes)
        }
    }
    
    // MARK: - Helpers
    
    private func displayedValue(from rawValue: Double) -> Double {
        switch selectedUnit {
        case .mmolL:
            return rawValue / 18.0
        case .mgdL:
            return rawValue
        }
    }
    
    private func displayedLowThreshold() -> Double {
        switch selectedUnit {
        case .mmolL:
            return 3.9
        case .mgdL:
            return 70
        }
    }
    
    private func displayedWarningThreshold() -> Double {
        switch selectedUnit {
        case .mmolL:
            return 10.0
        case .mgdL:
            return 180
        }
    }
    
    private func displayedUrgentThreshold() -> Double {
        switch selectedUnit {
        case .mmolL:
            return 13.9
        case .mgdL:
            return 250
        }
    }
    
    private func colorForValue(_ value: Double) -> UIColor {
        let low = displayedLowThreshold()
        let warning = displayedWarningThreshold()
        let urgent = displayedUrgentThreshold()
        
        if value >= urgent {
            return .systemRed
        } else if value >= warning {
            return .systemOrange
        } else if value < low {
            return .systemRed
        } else {
            return .systemGreen
        }
    }
    
    private func formatValue(_ value: Double) -> String {
        switch selectedUnit {
        case .mmolL:
            return String(format: "%.1f", value)
        case .mgdL:
            return String(format: "%.0f", value)
        }
    }
    
    private func formattedDisplayDate(from raw: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: raw) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "fr_FR")
            formatter.dateFormat = "dd/MM HH:mm"
            return formatter.string(from: date)
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        
        if let date = formatter.date(from: raw) {
            let output = DateFormatter()
            output.locale = Locale(identifier: "fr_FR")
            output.dateFormat = "dd/MM HH:mm"
            return output.string(from: date)
        }
        
        return raw
    }
}
