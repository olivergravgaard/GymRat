import Foundation
import SwiftUI

struct FinishWorkoutSessionSheet: View {
    
    let unPerformedSets: Int
    let onClose: () -> Void
    let onCompleteUnfinishedSets: () -> Void
    let onDiscardUnfinishedSets: () -> Void
    let onFinishWorkoutSession: () -> Void
    
    var body: some View {
        ResizableSheet(animation: .smooth(duration: 0.3)) {
            VStack (spacing: 24) {
                Text("Finish workout?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .overlay (alignment: .trailing) {
                        CloseButton {
                            onClose()
                        }
                    }
                
                if unPerformedSets != 0 {
                    Text("You have \(unPerformedSets) unperformed sets.")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.gray)
                    
                    VStack (spacing: 16) {
                        Button {
                            onCompleteUnfinishedSets()
                        } label: {
                            Text("Complete Unfinished Sets")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 44, alignment: .center)
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.green)
                                }
                        }
                        
                        Button {
                            onDiscardUnfinishedSets()
                        } label: {
                            Text("Discard Unfinished Sets")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .frame(height: 44, alignment: .center)
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(.red.opacity(0.1))
                                }
                        }

                    }
                }else {
                    
                    Text("All sets have been completed. Are you sure you want to finish this workout?")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.gray)
                    
                    Button {
                        onFinishWorkoutSession()
                    } label: {
                        Text("Finish Workout")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .frame(height: 44, alignment: .center)
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(.green)
                            }
                    }
                }
            }
        }
    }
}
