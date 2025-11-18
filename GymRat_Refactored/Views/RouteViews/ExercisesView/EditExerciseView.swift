import SwiftUI

enum TestMenuItem: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    
    case history = "History"
    case records = "Records"
    case about = "About"
}

struct EditExerciseView: View {
    
    @EnvironmentObject private var appComp: AppComposition
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibility
    
    @StateObject var editStore: ExerciseFormStore
    let originalDTO: ExerciseDTO
    
    @StateObject var exerciseHistoryStore: ExerciseHistoryStore
    @StateObject var exerciseRecordStore: ExerciseRecordStore
    
    @State private var propertyMenuProgress: CGFloat = 0
    @State private var showEditExerciseSheet: Bool = false
    
    // FOR TESTING
    @State private var dragOffset: CGFloat = 0
    @State private var dragItemRect: CGRect = .zero
    @State private var containerRect: CGRect = .zero
    @State private var dragAnchorRect: CGRect = .zero
    @State private var items: [TestMenuItem: CGRect] = [:]
    @State private var selected: TestMenuItem = .history
    
    func clampedOffset(
        for translation: CGFloat,
        anchor: CGRect,
        container: CGRect
    ) -> CGFloat {
        let minOffset = container.minX - anchor.minX
        let maxOffset = container.maxX - anchor.maxX
        return min(max(translation, minOffset), maxOffset)
    }
    
    @ViewBuilder
    func testPickerItemView (for selection: TestMenuItem) -> some View {
        
        var isSelected: Bool {
            selection == selected
        }
        
        Text(selection.rawValue)
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(isSelected ? .white : .black)
            .onTapGesture {
                guard !isSelected else { return }
                withAnimation {
                    selected = selection
                }
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .compositingGroup()
            .onGeometryChange(for: CGRect.self) {
                $0.frame(in: .global)
            } action: { newValue in
                items[selection] = newValue
            }
        
    }
    
    var body: some View {
        ScrollView(.vertical) {
            switch selected {
            case .history:
                exerciseSessionsHistoryCards()
                    .padding(.horizontal)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .records:
                exerciseRecordsCard()
                    .padding(.horizontal)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .about:
                Text("About view")
            }
        }
        .frame(maxWidth: .infinity)
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, content: {
            HStack {
                ForEach(TestMenuItem.allCases, id: \.rawValue) {
                    testPickerItemView(for: $0)
                }
            }
            .frame(height: 44)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: .infinity).fill(Color(red: 0.937, green: 0.937, blue: 0.937))
                    .onGeometryChange(for: CGRect.self) {
                        $0.frame(in: .global)
                    } action: { newValue in
                        containerRect = newValue
                    }
                    .overlay(alignment: .topLeading) {
                        if containerRect != .zero, let target = items[selected], (target.width.isFinite && target.width > 0 && target.minX.isFinite && target.minX > 0) {
                            let x = target.minX - containerRect.minX
                            
                            RoundedRectangle(cornerRadius: .infinity).fill(.indigo.opacity(1))
                                .frame(width: target.width, height: 44)
                                .glassEffect(.clear.interactive(true), in: .rect(cornerRadius: .infinity))
                                .shadow(color: .indigo, radius: 4)
                                .offset(x: dragOffset + x)
                                .animation(.snappy, value: selected)
                                .animation(.snappy, value: dragOffset)
                        }
                    }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.1)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .first(true):
                            dragAnchorRect = items[selected] ?? .zero
                        case .second(true, let drag?):
                            let translation = drag.translation.width
                            dragOffset = clampedOffset(for: translation,
                                                       anchor: dragAnchorRect,
                                                       container: containerRect)
                        default: break
                        }
                    }
                    .onEnded { value in
                        switch value {
                        case .first(true):
                            dragOffset = 0
                        case .second(true, let drag?):
                            let t = clampedOffset(for: drag.translation.width,
                                                  anchor: dragAnchorRect,
                                                  container: containerRect)
                            let center = CGPoint(x: dragAnchorRect.midX + t,
                                                 y: dragAnchorRect.midY)
                            
                            if let new = items.first(where: { $0.value.contains(center) })?.key,
                               new != selected {
                                withAnimation {
                                    selected = new
                                }
                            }
                            dragOffset = 0
                        default: break
                        }
                    }
            )
            .padding()
        })
        .safeAreaInset(edge: .top) {
            topBar()
                .frame(maxWidth: .infinity)
        }
        .ignoresSafeArea(edges: [.top])
        .onAppear {
            tabBarVisibility.hide()
        }
        .overlay (alignment: .bottomTrailing) {
            ExpandableMenu(
                progress: propertyMenuProgress,
                config: .init(
                    placement: .vertical(.trailing),
                    glassSpacing: 16,
                    tabSize: .init(width: 55, height: 55),
                    items: [
                        .init(content: {
                            Button {
                                withAnimation {
                                    propertyMenuProgress = 0
                                } completion: {
                                    showEditExerciseSheet = true
                                }
                            } label: {
                                Image(systemName: "pencil")
                                    .fontWeight(.medium)
                            }
                        })
                    ],
                    fixedAttribute: .spacing(16)
                )) {
                    ZStack {
                        Group {
                            Button {
                                guard propertyMenuProgress == 0 else { return }
                                
                                withAnimation {
                                    propertyMenuProgress = 1
                                }
                            } label: {
                                Image(systemName: "pencil")
                                    .foregroundStyle(.black)
                            }
                            .opacity(1 - propertyMenuProgress)
                            .disabled(propertyMenuProgress > 0)
                            
                            Button {
                                guard propertyMenuProgress == 1 else { return }
                                
                                withAnimation {
                                    propertyMenuProgress = 0
                                }
                            } label: {
                                Image(systemName: "xmark")
                                    .foregroundStyle(.indigo)
                            }
                            .opacity(propertyMenuProgress)
                            .disabled(propertyMenuProgress < 1)
                        }
                        .fontWeight(.medium)
                    }
                }
                .padding(.trailing)
        }
        .sheet(isPresented: $showEditExerciseSheet) {
            EditExerciseSheet(
                isPresented: $showEditExerciseSheet,
                exercise: originalDTO,
                exerciseProvider: appComp.exerciseProvider,
                muscleGroupProvider: appComp.muscleGroupProvider
            )
        }
    }
    
    @ViewBuilder
    func exerciseSessionsHistoryCards () -> some View {
        LazyVStack (spacing: 16) {
            if !exerciseHistoryStore.sessions.isEmpty {
                ForEach(exerciseHistoryStore.sessions) { session in
                    exerciseSessionHistoryCard(session)
                }
            }else {
                Text("No sessions has been recorded with this exercise yet.")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 224, alignment: .center)
                    .padding(.vertical)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @ViewBuilder
    func exerciseSessionHistoryCard (_ session: ExerciseHistoryEntry) -> some View {
        VStack (alignment: .leading, spacing: 4) {
            Text(session.sessionName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.indigo)
            
            Text(formatDate(session.performedAt))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.indigo.opacity(0.4))
            
            VStack (alignment: .leading, spacing: 12) {
                
                HStack (spacing: 16) {
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
                
                ForEach(session.exerciseSession.sets, id: \.id) { set in
                    HStack (alignment: .center, spacing: 16) {
                        Capsule()
                            .fill(.indigo.opacity(0.2))
                            .frame(width: 55, height: 32)
                            .overlay (alignment: .center) {
                                Text("\(set.order)")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.indigo)
                            }
                            .frame(width: 72, alignment: .center)
                        
                        Text("\(formatWeight(set.weight)) \(session.exerciseSession.settings.metricType.rawValue)")
                            .frame(width: 96, alignment: .center)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text("x\(set.reps) reps")
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
    }
    
    @ViewBuilder
    func exerciseRecordsCard () -> some View {
        if !exerciseRecordStore.records.isEmpty {
            LazyVStack (alignment: .leading, spacing: 4) {
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
                    
                    ForEach(exerciseRecordStore.records) { record in
                        HStack (spacing: 16) {
                            Capsule()
                                .fill(.indigo.opacity(0.2))
                                .frame(width: 55, height: 32, alignment: .center)
                                .overlay (alignment: .center) {
                                    Text("\(record.reps)")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.indigo)
                                }
                                .frame(width: 72)
                            Text("\(formatWeight(record.weight)) kg")
                                .frame(width: 96, alignment: .center)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(formatDate(record.performedAt))
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
        }else {
            Text("No records has been recorded with this exercise yet.")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.gray)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 224, alignment: .center)
                .padding(.vertical)
        }
    }
    
    @ViewBuilder
    func topBar () -> some View {
        HStack (alignment: .center){
            DismissButton {
                dismiss()
                tabBarVisibility.show()
            }
            
            Spacer(minLength: 8)
            
            VStack (alignment: .trailing, spacing: 2) {
                Text(originalDTO.name)
                    .font(.title)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                Text(appComp.muscleGroupLookupSource.name(for: originalDTO.muscleGroupID))
                    .font(.footnote)
                    .fontWeight(.bold)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal)
        .padding(.bottom)
        .padding(.top, 55)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadii: .init(bottomLeading: 12, bottomTrailing: 12)))
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }
}
