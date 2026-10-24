//
//  ASMRRouteOverlayRenderer.swift
//  ASMRWalkRouteOverlay
//

import Foundation

enum ASMRRouteOverlayTimingMode: Int, Codable, CaseIterable, Sendable {
    case clipDuration
    case routeTimestamps
}

struct ASMRRouteOverlayRenderPlan: Codable, Equatable, Sendable {
    struct Point: Codable, Equatable, Sendable {
        let x: Double
        let y: Double
    }

    let routePoints: [Point]
    let visibleRoutePoints: [Point]
    let currentPosition: Point?
    let startPosition: Point?
    let endPosition: Point?
    let style: ASMRRouteOverlayStyle

    var isEmpty: Bool {
        routePoints.isEmpty
    }

    static let empty = ASMRRouteOverlayRenderPlan(
        routePoints: [],
        visibleRoutePoints: [],
        currentPosition: nil,
        startPosition: nil,
        endPosition: nil,
        style: .default
    )

    static func make(
        from routePackage: ASMRRoutePackageInput,
        renderTimeSeconds: TimeInterval,
        effectStartSeconds: TimeInterval = 0,
        effectDurationSeconds: TimeInterval? = nil,
        timingMode: ASMRRouteOverlayTimingMode = .clipDuration,
        maximumRoutePointCount: Int = 2_048,
        style: ASMRRouteOverlayStyle = .default,
        showCurrentPosition: Bool = true,
        showStartEndMarkers: Bool = true
    ) -> ASMRRouteOverlayRenderPlan {
        let timedPoints = simplified(
            normalizedTimedPoints(from: routePackage),
            maximumPointCount: maximumRoutePointCount
        )

        guard let firstPoint = timedPoints.first else {
            return ASMRRouteOverlayRenderPlan(
                routePoints: [],
                visibleRoutePoints: [],
                currentPosition: nil,
                startPosition: nil,
                endPosition: nil,
                style: style
            )
        }

        let routeDuration = max(
            0,
            timedPoints.last?.seconds ?? routePackage.manifest.durationSeconds
        )
        let elapsedSeconds = routeElapsedSeconds(
            renderTimeSeconds: renderTimeSeconds,
            effectStartSeconds: effectStartSeconds,
            effectDurationSeconds: effectDurationSeconds,
            routeDurationSeconds: routeDuration,
            timingMode: timingMode
        )
        let visibleRoutePoints = visiblePoints(from: timedPoints, elapsedSeconds: elapsedSeconds)
        let currentPosition = showCurrentPosition ? interpolatedPoint(from: timedPoints, elapsedSeconds: elapsedSeconds) : nil

        return ASMRRouteOverlayRenderPlan(
            routePoints: timedPoints.map(\.point),
            visibleRoutePoints: visibleRoutePoints,
            currentPosition: currentPosition,
            startPosition: showStartEndMarkers ? firstPoint.point : nil,
            endPosition: showStartEndMarkers ? timedPoints.last?.point : nil,
            style: style
        )
    }

    private struct TimedPoint {
        let seconds: TimeInterval
        let point: Point
    }

    private static func normalizedTimedPoints(from routePackage: ASMRRoutePackageInput) -> [TimedPoint] {
        let points = routePackage.routePoints
        guard !points.isEmpty else { return [] }

        let latitudes = points.map(\.latitude)
        let longitudes = points.map(\.longitude)
        guard
            let minLatitude = latitudes.min(),
            let maxLatitude = latitudes.max(),
            let minLongitude = longitudes.min(),
            let maxLongitude = longitudes.max()
        else {
            return []
        }

        let latitudeMidpoint = (minLatitude + maxLatitude) / 2
        let longitudeMidpoint = (minLongitude + maxLongitude) / 2
        let latitudeSpan = maxLatitude - minLatitude
        let longitudeSpan = maxLongitude - minLongitude
        let routeSpan = max(latitudeSpan, longitudeSpan)
        let routeStart = routePackage.manifest.routeStartedAt

        return points.map { routePoint in
            let normalizedPoint: Point
            if routeSpan > 0 {
                normalizedPoint = Point(
                    x: 0.5 + ((routePoint.longitude - longitudeMidpoint) / routeSpan),
                    y: 0.5 - ((routePoint.latitude - latitudeMidpoint) / routeSpan)
                )
            } else {
                normalizedPoint = Point(x: 0.5, y: 0.5)
            }

            return TimedPoint(
                seconds: max(0, routePoint.timestamp.timeIntervalSince(routeStart)),
                point: normalizedPoint
            )
        }
    }

    private static func routeElapsedSeconds(
        renderTimeSeconds: TimeInterval,
        effectStartSeconds: TimeInterval,
        effectDurationSeconds: TimeInterval?,
        routeDurationSeconds: TimeInterval,
        timingMode: ASMRRouteOverlayTimingMode
    ) -> TimeInterval {
        guard routeDurationSeconds > 0 else { return 0 }

        let effectElapsed = max(0, renderTimeSeconds - effectStartSeconds)
        switch timingMode {
        case .clipDuration:
            let effectDuration = effectDurationSeconds.flatMap { $0 > 0 ? $0 : nil }
                ?? routeDurationSeconds
            let progress = min(1, effectElapsed / effectDuration)
            return routeDurationSeconds * progress
        case .routeTimestamps:
            return min(effectElapsed, routeDurationSeconds)
        }
    }

    private static func simplified(
        _ timedPoints: [TimedPoint],
        maximumPointCount: Int
    ) -> [TimedPoint] {
        guard maximumPointCount >= 2, timedPoints.count > maximumPointCount else {
            return timedPoints
        }

        let lastIndex = timedPoints.count - 1
        let divisor = Double(maximumPointCount - 1)
        return (0..<maximumPointCount).map { outputIndex in
            let sourceIndex = Int((Double(outputIndex) * Double(lastIndex) / divisor).rounded())
            return timedPoints[sourceIndex]
        }
    }

    private static func visiblePoints(from timedPoints: [TimedPoint], elapsedSeconds: TimeInterval) -> [Point] {
        guard !timedPoints.isEmpty else { return [] }

        var points = timedPoints
            .filter { $0.seconds <= elapsedSeconds }
            .map(\.point)

        if let currentPoint = interpolatedPoint(from: timedPoints, elapsedSeconds: elapsedSeconds),
           points.last != currentPoint {
            points.append(currentPoint)
        }

        return points
    }

    private static func interpolatedPoint(from timedPoints: [TimedPoint], elapsedSeconds: TimeInterval) -> Point? {
        guard let firstPoint = timedPoints.first else { return nil }
        guard timedPoints.count > 1 else { return firstPoint.point }

        if elapsedSeconds < firstPoint.seconds {
            return firstPoint.point
        }

        var previousPoint = firstPoint
        for nextPoint in timedPoints.dropFirst() {
            if nextPoint.seconds <= elapsedSeconds {
                previousPoint = nextPoint
                continue
            }

            let segmentDuration = nextPoint.seconds - previousPoint.seconds
            guard segmentDuration > 0 else {
                previousPoint = nextPoint
                continue
            }

            let progress = (elapsedSeconds - previousPoint.seconds) / segmentDuration
            return Point(
                x: previousPoint.point.x + ((nextPoint.point.x - previousPoint.point.x) * progress),
                y: previousPoint.point.y + ((nextPoint.point.y - previousPoint.point.y) * progress)
            )
        }

        return timedPoints.last?.point
    }
}

struct ASMRRouteOverlayStyle: Codable, Equatable, Sendable {
    let routeColor: ASMRRouteOverlayColor
    let currentPositionColor: ASMRRouteOverlayColor
    let markerColor: ASMRRouteOverlayColor
    let paddingFraction: Double
    let lineWidthFraction: Double
    let currentDotRadiusFraction: Double
    let markerRadiusFraction: Double

    static let `default` = ASMRRouteOverlayStyle(
        routeColor: ASMRRouteOverlayColor(red: 33, green: 151, blue: 243, alpha: 230),
        currentPositionColor: ASMRRouteOverlayColor(red: 255, green: 255, blue: 255, alpha: 255),
        markerColor: ASMRRouteOverlayColor(red: 255, green: 193, blue: 7, alpha: 245),
        paddingFraction: 0.12,
        lineWidthFraction: 0.012,
        currentDotRadiusFraction: 0.022,
        markerRadiusFraction: 0.017
    )
}

struct ASMRRouteOverlayColor: Codable, Equatable, Sendable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8
    let alpha: UInt8
}

struct ASMRRouteOverlayBitmap: Equatable, Sendable {
    let width: Int
    let height: Int
    var rgbaPixels: [UInt8]

    init(width: Int, height: Int) {
        self.width = max(0, width)
        self.height = max(0, height)
        rgbaPixels = Array(repeating: 0, count: self.width * self.height * 4)
    }
}

enum ASMRRouteOverlayPixelFormat: Equatable, Sendable {
    case rgba
    case bgra
}

enum ASMRRouteOverlayRenderer {
    static func bitmap(for plan: ASMRRouteOverlayRenderPlan, width: Int, height: Int) -> ASMRRouteOverlayBitmap {
        var bitmap = ASMRRouteOverlayBitmap(width: width, height: height)
        guard width > 0, height > 0, !plan.isEmpty else { return bitmap }

        bitmap.rgbaPixels.withUnsafeMutableBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            render(
                plan,
                into: baseAddress,
                width: width,
                height: height,
                bytesPerRow: width * 4,
                pixelFormat: .rgba
            )
        }

        return bitmap
    }

    static func render(
        _ plan: ASMRRouteOverlayRenderPlan,
        into destination: UnsafeMutableRawPointer,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixelFormat: ASMRRouteOverlayPixelFormat
    ) {
        guard width > 0, height > 0, bytesPerRow >= width * 4 else { return }

        memset(destination, 0, bytesPerRow * height)
        guard !plan.isEmpty else { return }

        let pixelBuffer = destination.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
        let writer = PixelWriter { x, y, color in
            guard x >= 0, x < width, y >= 0, y < height else { return }

            let offset = (y * bytesPerRow) + (x * 4)
            switch pixelFormat {
            case .rgba:
                blend(color, into: pixelBuffer, offset: offset, redIndex: 0, greenIndex: 1, blueIndex: 2, alphaIndex: 3)
            case .bgra:
                blend(color, into: pixelBuffer, offset: offset, redIndex: 2, greenIndex: 1, blueIndex: 0, alphaIndex: 3)
            }
        }

        draw(plan: plan, width: width, height: height, pixelWriter: writer)
    }

    private static func draw(
        plan: ASMRRouteOverlayRenderPlan,
        width: Int,
        height: Int,
        pixelWriter: PixelWriter
    ) {
        let shorterSide = Double(min(width, height))
        let padding = shorterSide * plan.style.paddingFraction
        let lineWidth = max(1, shorterSide * plan.style.lineWidthFraction)
        let dotRadius = max(1, shorterSide * plan.style.currentDotRadiusFraction)
        let markerRadius = max(1, shorterSide * plan.style.markerRadiusFraction)

        if plan.visibleRoutePoints.count > 1 {
            for index in 1..<plan.visibleRoutePoints.count {
                drawLine(
                    from: pixelPoint(plan.visibleRoutePoints[index - 1], width: width, height: height, padding: padding),
                    to: pixelPoint(plan.visibleRoutePoints[index], width: width, height: height, padding: padding),
                    radius: lineWidth / 2,
                    color: plan.style.routeColor,
                    pixelWriter: pixelWriter
                )
            }
        }

        if let startPosition = plan.startPosition {
            drawCircle(
                center: pixelPoint(startPosition, width: width, height: height, padding: padding),
                radius: markerRadius,
                color: plan.style.markerColor,
                pixelWriter: pixelWriter
            )
        }

        if let endPosition = plan.endPosition {
            drawCircle(
                center: pixelPoint(endPosition, width: width, height: height, padding: padding),
                radius: markerRadius,
                color: plan.style.markerColor,
                pixelWriter: pixelWriter
            )
        }

        if let currentPosition = plan.currentPosition {
            drawCircle(
                center: pixelPoint(currentPosition, width: width, height: height, padding: padding),
                radius: dotRadius,
                color: plan.style.currentPositionColor,
                pixelWriter: pixelWriter
            )
        }
    }

    private static func pixelPoint(
        _ point: ASMRRouteOverlayRenderPlan.Point,
        width: Int,
        height: Int,
        padding: Double
    ) -> ASMRRouteOverlayRenderPlan.Point {
        let drawableWidth = max(0, Double(width) - (padding * 2))
        let drawableHeight = max(0, Double(height) - (padding * 2))

        return ASMRRouteOverlayRenderPlan.Point(
            x: padding + (point.x * drawableWidth),
            y: padding + (point.y * drawableHeight)
        )
    }

    private static func drawLine(
        from start: ASMRRouteOverlayRenderPlan.Point,
        to end: ASMRRouteOverlayRenderPlan.Point,
        radius: Double,
        color: ASMRRouteOverlayColor,
        pixelWriter: PixelWriter
    ) {
        let minX = Int(floor(min(start.x, end.x) - radius))
        let maxX = Int(ceil(max(start.x, end.x) + radius))
        let minY = Int(floor(min(start.y, end.y) - radius))
        let maxY = Int(ceil(max(start.y, end.y) + radius))
        let radiusSquared = radius * radius

        for y in minY...maxY {
            for x in minX...maxX {
                let pixelCenter = ASMRRouteOverlayRenderPlan.Point(x: Double(x) + 0.5, y: Double(y) + 0.5)
                guard squaredDistance(from: pixelCenter, toSegmentStart: start, segmentEnd: end) <= radiusSquared else {
                    continue
                }
                pixelWriter.write(x, y, color)
            }
        }
    }

    private static func drawCircle(
        center: ASMRRouteOverlayRenderPlan.Point,
        radius: Double,
        color: ASMRRouteOverlayColor,
        pixelWriter: PixelWriter
    ) {
        let minX = Int(floor(center.x - radius))
        let maxX = Int(ceil(center.x + radius))
        let minY = Int(floor(center.y - radius))
        let maxY = Int(ceil(center.y + radius))
        let radiusSquared = radius * radius

        for y in minY...maxY {
            for x in minX...maxX {
                let pixelCenter = ASMRRouteOverlayRenderPlan.Point(x: Double(x) + 0.5, y: Double(y) + 0.5)
                let dx = pixelCenter.x - center.x
                let dy = pixelCenter.y - center.y
                guard ((dx * dx) + (dy * dy)) <= radiusSquared else { continue }
                pixelWriter.write(x, y, color)
            }
        }
    }

    private static func squaredDistance(
        from point: ASMRRouteOverlayRenderPlan.Point,
        toSegmentStart start: ASMRRouteOverlayRenderPlan.Point,
        segmentEnd end: ASMRRouteOverlayRenderPlan.Point
    ) -> Double {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let segmentLengthSquared = (dx * dx) + (dy * dy)

        guard segmentLengthSquared > 0 else {
            let pointDX = point.x - start.x
            let pointDY = point.y - start.y
            return (pointDX * pointDX) + (pointDY * pointDY)
        }

        let t = max(0, min(1, (((point.x - start.x) * dx) + ((point.y - start.y) * dy)) / segmentLengthSquared))
        let projection = ASMRRouteOverlayRenderPlan.Point(
            x: start.x + (t * dx),
            y: start.y + (t * dy)
        )
        let projectionDX = point.x - projection.x
        let projectionDY = point.y - projection.y
        return (projectionDX * projectionDX) + (projectionDY * projectionDY)
    }

    private static func blend(
        _ sourceColor: ASMRRouteOverlayColor,
        into pixelBuffer: UnsafeMutablePointer<UInt8>,
        offset: Int,
        redIndex: Int,
        greenIndex: Int,
        blueIndex: Int,
        alphaIndex: Int
    ) {
        let sourceAlpha = Double(sourceColor.alpha) / 255
        let destinationAlpha = Double(pixelBuffer[offset + alphaIndex]) / 255
        let outputAlpha = sourceAlpha + (destinationAlpha * (1 - sourceAlpha))

        guard outputAlpha > 0 else { return }

        func blendChannel(_ source: UInt8, destination: UInt8) -> UInt8 {
            let sourceValue = Double(source) / 255
            let destinationValue = Double(destination) / 255
            let outputValue = ((sourceValue * sourceAlpha) + (destinationValue * destinationAlpha * (1 - sourceAlpha))) / outputAlpha
            return UInt8(max(0, min(255, round(outputValue * 255))))
        }

        pixelBuffer[offset + redIndex] = blendChannel(sourceColor.red, destination: pixelBuffer[offset + redIndex])
        pixelBuffer[offset + greenIndex] = blendChannel(sourceColor.green, destination: pixelBuffer[offset + greenIndex])
        pixelBuffer[offset + blueIndex] = blendChannel(sourceColor.blue, destination: pixelBuffer[offset + blueIndex])
        pixelBuffer[offset + alphaIndex] = UInt8(max(0, min(255, round(outputAlpha * 255))))
    }

    private struct PixelWriter {
        let write: (Int, Int, ASMRRouteOverlayColor) -> Void
    }
}
