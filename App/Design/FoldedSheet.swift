import SwiftUI

/// A sheet of paper with its top-right corner folded down.
struct FoldedSheet: InsettableShape {
    static let fold: CGFloat = 22
    var radius: CGFloat = 20
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let fold = Self.fold - inset
        var path = Path()
        path.move(to: CGPoint(x: r.minX + radius, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - fold, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + fold))
        path.addArc(tangent1End: CGPoint(x: r.maxX, y: r.maxY), tangent2End: CGPoint(x: r.maxX - radius, y: r.maxY), radius: radius)
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.maxY), tangent2End: CGPoint(x: r.minX, y: r.maxY - radius), radius: radius)
        path.addArc(tangent1End: CGPoint(x: r.minX, y: r.minY), tangent2End: CGPoint(x: r.minX + radius, y: r.minY), radius: radius)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> FoldedSheet {
        var shape = self
        shape.inset += amount
        return shape
    }
}

/// The underside of the folded corner.
struct FoldFlap: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 4))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 4, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
