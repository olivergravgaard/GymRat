import Foundation
import SwiftUI

struct SingleHPicker<T: Identifiable & Equatable>: View {
    
    var allCases: [T]
    var keypath: KeyPath<T, String>
    
    @Binding var activeCase: T?
    
    @Namespace var animationNS
    
    init (allCases: [T], activeCase: Binding<T?>, keyPath: KeyPath<T, String>) {
        self.allCases = allCases
        self.keypath = keyPath
        self._activeCase = activeCase
    }
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack (spacing: 12){
                ForEach(allCases, id: \.id) { t in
                    caseView(t: t)
                }
            }
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    func caseView(t: T) -> some View {
        let isActive = activeCase == t
        
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                handleTap(tapped: t)
            }
        } label: {
            Text(t[keyPath: keypath])
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isActive ? .white : .indigo)
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .background {
                    if isActive {
                        RoundedRectangle(cornerRadius: 12).fill(.indigo)
                            .shadow(color: .indigo.opacity(0.9), radius: 2, y: 2)
                            .matchedGeometryEffect(id: "selected", in: animationNS)
                    }else {
                        RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.937, green: 0.937, blue: 0.937))
                            .shadow(color: .black.opacity(0.1), radius: 2, y: 2)
                    }
                }
        }
    }
    
    private func handleTap(tapped: T) {
        if activeCase == tapped {
            activeCase = nil
        }else {
            activeCase = tapped
        }
    }
}

struct MultiHPicker<T: Identifiable & Equatable>: View {
    
    var allCases: [T]
    var keypath: KeyPath<T, String>
    
    @Binding var activeCases: [T]
    
    init (allCases: [T], activeCases: Binding<[T]>, keyPath: KeyPath<T, String>) {
        self.allCases = allCases
        self.keypath = keyPath
        self._activeCases = activeCases
    }
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack (spacing: 12){
                ForEach(allCases, id: \.id) { t in
                    CaseView(t: t)
                }
            }
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
    
    @ViewBuilder
    func CaseView(t: T) -> some View {
        let isActive = activeCases.contains(t)
        
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                handleTap(tapped: t)
            }
        } label: {
            Text(t[keyPath: keypath])
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(isActive ? .white : .indigo)
                .padding(.vertical, 8)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 12).fill(isActive ? .indigo : Color(red: 0.937, green: 0.937, blue: 0.937))
                        .shadow(color: isActive ? .indigo.opacity(0.9) : .black.opacity(0.1), radius: 2, y: 2)
                )
        }
    }
    
    private func handleTap(tapped: T) {
        if activeCases.contains(tapped) {
            activeCases.removeAll(where: {$0 == tapped})
        }else {
            activeCases.append(tapped)
        }
    }
}
