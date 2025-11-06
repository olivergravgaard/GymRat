import Foundation
import SwiftUI

struct EditSetTypeView: View {
    let onConfirm: (_ setType: SetType) -> Void
    let close: (@escaping () -> ()) -> ()
    
    var body: some View {
        VStack {
            ForEach(SetType.allCases) { setType in
                labelView(setType) {
                    close {
                        onConfirm(setType)
                    }
                }
            }
        }
        .padding()
    }
    
    @ViewBuilder
    func labelView (_ setType: SetType, action: @escaping () -> ()) -> some View {
        Button {
            action()
        } label: {
            HStack (alignment: .center) {
                Text(setType.initials)
                    .foregroundStyle(setType.color)
                    .fontWeight(.semibold)
                    .font(.subheadline)
                    .frame(width: 24, alignment: .center)
                
                Text(setType.rawValue)
                    .foregroundStyle(.gray)
                    .fontWeight(.semibold)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 24)
        }

    }
}
