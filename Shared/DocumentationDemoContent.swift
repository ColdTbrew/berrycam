import SwiftUI

struct DocumentationCatVideoScene: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.98, green: 0.94, blue: 0.87), Color(red: 0.78, green: 0.91, blue: 0.84)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: 0) {
                    HStack(spacing: 22) {
                        ForEach(0..<4, id: \.self) { index in
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.54))
                                .frame(width: 78, height: 54)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                )
                                .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1.5 : 1.5))
                        }
                    }
                    .padding(.top, 26)

                    Spacer()

                    Path { path in
                        let y = proxy.size.height * 0.72
                        path.move(to: CGPoint(x: proxy.size.width * 0.08, y: y))
                        path.addCurve(
                            to: CGPoint(x: proxy.size.width * 0.92, y: y - 28),
                            control1: CGPoint(x: proxy.size.width * 0.30, y: y - 76),
                            control2: CGPoint(x: proxy.size.width * 0.64, y: y + 54)
                        )
                    }
                    .stroke(Color(red: 0.64, green: 0.52, blue: 0.38).opacity(0.82), lineWidth: 16)

                    Spacer()
                        .frame(height: 18)
                }

                DocumentationCatIllustration()
                    .frame(width: min(proxy.size.width * 0.38, 230), height: min(proxy.size.height * 0.52, 250))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.72))
                    .frame(width: 156, height: 42)
                    .overlay(
                        Label("Cat detected", systemImage: "pawprint.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(18)
            }
            .clipped()
        }
        .accessibilityLabel("Generated cat demo video scene")
    }
}

private struct DocumentationCatIllustration: View {
    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.14))
                .frame(width: 190, height: 42)
                .offset(y: 88)

            CatTail()
                .stroke(Color(red: 0.78, green: 0.45, blue: 0.20), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .frame(width: 165, height: 145)
                .offset(x: 78, y: 30)

            CatBody()
                .fill(Color(red: 0.92, green: 0.57, blue: 0.28))
                .frame(width: 170, height: 165)
                .offset(y: 24)

            CatHead()
                .fill(Color(red: 0.96, green: 0.66, blue: 0.34))
                .frame(width: 170, height: 140)
                .offset(y: -36)

            CatFace()
                .stroke(Color(red: 0.24, green: 0.13, blue: 0.08), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                .frame(width: 132, height: 86)
                .offset(y: -26)
        }
    }
}

private struct CatBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRoundedRect(in: rect.insetBy(dx: 16, dy: 8), cornerSize: CGSize(width: 78, height: 86))
        return path
    }
}

private struct CatHead: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 24, y: rect.minY + 48))
        path.addLine(to: CGPoint(x: rect.minX + 36, y: rect.minY + 4))
        path.addLine(to: CGPoint(x: rect.minX + 72, y: rect.minY + 36))
        path.addCurve(to: CGPoint(x: rect.maxX - 72, y: rect.minY + 36), control1: CGPoint(x: rect.midX - 24, y: rect.minY + 20), control2: CGPoint(x: rect.midX + 24, y: rect.minY + 20))
        path.addLine(to: CGPoint(x: rect.maxX - 36, y: rect.minY + 4))
        path.addLine(to: CGPoint(x: rect.maxX - 24, y: rect.minY + 48))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY), control1: CGPoint(x: rect.maxX + 8, y: rect.maxY - 14), control2: CGPoint(x: rect.midX + 52, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.minX + 24, y: rect.minY + 48), control1: CGPoint(x: rect.midX - 52, y: rect.maxY), control2: CGPoint(x: rect.minX - 8, y: rect.maxY - 14))
        path.closeSubpath()
        return path
    }
}

private struct CatFace: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addEllipse(in: CGRect(x: rect.minX + 18, y: rect.minY + 10, width: 12, height: 14))
        path.addEllipse(in: CGRect(x: rect.maxX - 30, y: rect.minY + 10, width: 12, height: 14))
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 34))
        path.addLine(to: CGPoint(x: rect.midX - 9, y: rect.minY + 47))
        path.addLine(to: CGPoint(x: rect.midX + 9, y: rect.minY + 47))
        path.closeSubpath()
        path.move(to: CGPoint(x: rect.midX - 1, y: rect.minY + 49))
        path.addCurve(to: CGPoint(x: rect.midX - 34, y: rect.minY + 53), control1: CGPoint(x: rect.midX - 12, y: rect.minY + 65), control2: CGPoint(x: rect.midX - 26, y: rect.minY + 65))
        path.move(to: CGPoint(x: rect.midX + 1, y: rect.minY + 49))
        path.addCurve(to: CGPoint(x: rect.midX + 34, y: rect.minY + 53), control1: CGPoint(x: rect.midX + 12, y: rect.minY + 65), control2: CGPoint(x: rect.midX + 26, y: rect.minY + 65))
        path.move(to: CGPoint(x: rect.minX + 14, y: rect.minY + 46))
        path.addLine(to: CGPoint(x: rect.minX - 14, y: rect.minY + 40))
        path.move(to: CGPoint(x: rect.minX + 16, y: rect.minY + 60))
        path.addLine(to: CGPoint(x: rect.minX - 12, y: rect.minY + 64))
        path.move(to: CGPoint(x: rect.maxX - 14, y: rect.minY + 46))
        path.addLine(to: CGPoint(x: rect.maxX + 14, y: rect.minY + 40))
        path.move(to: CGPoint(x: rect.maxX - 16, y: rect.minY + 60))
        path.addLine(to: CGPoint(x: rect.maxX + 12, y: rect.minY + 64))
        return path
    }
}

private struct CatTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 16, y: rect.maxY - 18))
        path.addCurve(to: CGPoint(x: rect.maxX - 22, y: rect.minY + 28), control1: CGPoint(x: rect.midX + 72, y: rect.maxY + 10), control2: CGPoint(x: rect.maxX + 24, y: rect.midY - 16))
        path.addCurve(to: CGPoint(x: rect.maxX - 68, y: rect.minY + 54), control1: CGPoint(x: rect.maxX - 64, y: rect.minY - 10), control2: CGPoint(x: rect.maxX - 96, y: rect.minY + 30))
        return path
    }
}

extension CatDetectionEventPayload {
    static var documentationDemoEvents: [CatDetectionEventPayload] {
        [
            CatDetectionEventPayload(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                timestamp: Date(timeIntervalSinceReferenceDate: 800_000_000),
                type: .catDetected,
                confidence: 0.92,
                boundingBox: DetectionBoxPayload(x: 0.36, y: 0.24, width: 0.32, height: 0.52),
                snapshotFilename: nil
            ),
            CatDetectionEventPayload(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                timestamp: Date(timeIntervalSinceReferenceDate: 799_998_420),
                type: .catMoved,
                confidence: 0.84,
                boundingBox: DetectionBoxPayload(x: 0.42, y: 0.28, width: 0.26, height: 0.48),
                snapshotFilename: nil
            ),
            CatDetectionEventPayload(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                timestamp: Date(timeIntervalSinceReferenceDate: 799_996_100),
                type: .catDetected,
                confidence: 0.88,
                boundingBox: DetectionBoxPayload(x: 0.30, y: 0.22, width: 0.34, height: 0.54),
                snapshotFilename: nil
            ),
        ]
    }
}
