import SwiftUI
import AppKit

public struct SubjectIconView: View {
    public let subject: Subject
    public var size: CGFloat = 20
    public var foregroundColor: Color = .white

    public init(subject: Subject, size: CGFloat = 20, foregroundColor: Color = .white) {
        self.subject = subject
        self.size = size
        self.foregroundColor = foregroundColor
    }

    public var body: some View {
        if let customImage = subject.customImage {
            Image(nsImage: customImage)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: max(3, size * 0.22), style: .continuous))
        } else {
            Image(systemName: subject.sfSymbolName)
                .font(.system(size: max(8, size * 0.72), weight: .semibold))
                .foregroundStyle(foregroundColor)
        }
    }
}
