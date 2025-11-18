import SwiftUI
import Foundation

struct DemoView: View {
    var body: some View {
        VStack {
            VStack (alignment: .leading, spacing: 4) {
                Text("Push v1")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.indigo)
                
                Text("7. November 2025")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.indigo.opacity(0.4))
                
                VStack (spacing: 12) {
                    
                    HStack (spacing: 8) {
                        Group {
                            Text("Set")
                                .frame(width: 72, alignment: .center)
                            Text("Weight")
                                .frame(width: 96, alignment: .center)
                            Text("Reps")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .padding(.trailing, 8)
                        }
                        .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    
                    ForEach(1..<4) { i in
                        HStack (alignment: .center, spacing: 8) {
                            Capsule()
                                .fill(.indigo.opacity(0.2))
                                .frame(width: 55, height: 32)
                                .overlay (alignment: .center) {
                                    Text("\(i)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.indigo)
                                }
                                .frame(width: 72, alignment: .center)
                            
                            Text("99 kg")
                                .frame(width: 96, alignment: .center)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("x4 reps")
                                .frame(maxWidth: .infinity, alignment: .trailing)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.gray)
                                .padding(.trailing, 8)
                        }
                    }
                }
                .padding(.top, 12)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
            }
            .padding()
        }
        
        VStack (alignment: .leading, spacing: 4) {
            Text("Records")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.indigo)
            
            VStack (spacing: 12) {
                HStack (spacing: 16) {
                    Group {
                        Text("Reps")
                            .frame(width: 72, alignment: .center)
                        Text("Weight")
                            .frame(width: 96, alignment: .center)
                        
                        Text("Date")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 8)
                    }
                    .font(.headline)
                }
                .frame(maxWidth: .infinity)
                
                ForEach(6..<10) { i in
                    HStack (spacing: 16) {
                        Capsule()
                            .fill(.indigo.opacity(0.2))
                            .frame(width: 55, height: 32, alignment: .center)
                            .overlay (alignment: .center) {
                                Text("\(i)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.indigo)
                            }
                            .frame(width: 72)
                        Text("999.999 kg")
                            .frame(width: 96, alignment: .center)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("\(i). November 2025")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.gray)
                            .padding(.trailing, 8)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 12)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.95, green: 0.95, blue: 0.97))
        }
        .padding()
    }
}

#Preview {
    DemoView()
}


