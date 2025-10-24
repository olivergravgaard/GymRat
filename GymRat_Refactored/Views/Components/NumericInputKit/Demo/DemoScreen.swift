import Foundation
import SwiftUI

struct FieldsListView: View {
    @ObservedObject var host: _NumpadHost

    var rowHeight: CGFloat = 32
    var rowSpacing: CGFloat = 8
    var rowPadding: EdgeInsets = .init(top: 6, leading: 12, bottom: 6, trailing: 12)
    var font: UIFont = .monospacedSystemFont(ofSize: 18, weight: .regular)
    var insets: FieldInsets = .default
    let ids: [FieldID]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: rowSpacing, pinnedViews: []) {
                    /*FieldRow(
                        id: ids[0],
                        host: host,
                        inputPolicy: InputPolicies.time(limit: .hours, allowedNegative: false),
                        config: .init(
                            font: .monospacedSystemFont(ofSize: 18, weight: .bold),
                            textColor: .blue,
                            selectionColor: .red,
                            caretColor: UIColor(.indigo),
                            insets: .init(top: 0, left: 0, bottom: 0, right: 8),
                            alignment: .trailing
                        )
                    )
                    .frame(height: rowHeight)
                    .id(ids[0])
                    .padding(rowPadding)
                    
                    FieldRow(
                        id: ids[1],
                        host: host,
                        inputPolicy: _DecimalPolicy(maxIntegerDigits: 3, maxFractionDigits: 3, allowNegative: false),
                        config: .init(
                            font: .monospacedSystemFont(ofSize: 14, weight: .bold),
                            textColor: .red,
                            selectionColor: .blue,
                            caretColor: UIColor(.green),
                            insets: .init(top: 0, left: 0, bottom: 0, right: 0),
                            alignment: .center
                        )
                    )
                    .frame(height: rowHeight)
                    .id(ids[1])
                    .padding(rowPadding)
                    
                    FieldRow(
                        id: ids[2],
                        host: host,
                        inputPolicy: _DigitsOnlyPolicy(maxDigits: 16, allowNegative: false),
                        config: .init(
                            font: .monospacedSystemFont(ofSize: 14, weight: .bold),
                            textColor: .red,
                            selectionColor: .blue,
                            caretColor: UIColor(.green),
                            insets: .init(top: 0, left: 8, bottom: 0, right: 8),
                            alignment: .center
                        )
                    )
                    .id(ids[1])
                    .padding(20)
                    .background {
                        RoundedRectangle(cornerRadius: 12).fill(Color.gray)
                    }
                    .frame(width: 100, height: 44)*/
                }
            }
            .onAppear {
                host.onScrollTo = { target in
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.20)) {
                            proxy.scrollTo(target, anchor: .center)
                        }

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(target, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DemoScreen: View {
    @StateObject private var host = _NumpadHost()
    @State private var ids: [FieldID] = [
        FieldID(),
        FieldID(),
        FieldID()
    ]

    private let numpadHeight: CGFloat = 264

    var body: some View {
        VStack(spacing: 0) {
            FieldsListView(
                host: host,
                rowHeight: 48,
                rowSpacing: 4,
                rowPadding: .init(top: 4, leading: 12, bottom: 4, trailing: 12),
                font: .monospacedSystemFont(ofSize: 18, weight: .regular),
                insets: .default,
                ids: ids
            )
        }
        .onAppear {
            host.setOrder(ids)
            host.onValueChanged = { _, _ in }
        }
        .safeAreaInset(edge: .bottom) {
            if host.activeId != nil {
                NumpadRepresentable(host: host)
                    .frame(height: 264)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }
}
