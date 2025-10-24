import SwiftUI

private enum TemplateRoute: Hashable {
    case editTemplate(UUID)
}

struct TemplatesView: View {
    @EnvironmentObject private var appComp: AppComposition
    @EnvironmentObject var tabActions: TabActionCenter
    
    @ObservedObject var filterStore: TemplateFilterStore
    
    @State private var showCreateTemplateSheet: Bool = false
    @State private var path = NavigationPath()
    
    var body: some View {
        NavigationStack (path: $path) {
            ScrollView(.vertical) {
                LazyVStack (spacing: 8) {
                    ForEach(filterStore.filteredTemplates) { template in
                        NavigationLink(value: TemplateRoute.editTemplate(template.id)) {
                            TemplateRowView(template: template)
                                .id(template.version)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .fadedBottomSafeArea()
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top) {
                TopBar(filterStore: filterStore)
                    .frame(maxWidth: .infinity)
            }
            .ignoresSafeArea(edges: [.top])
            .navigationDestination(for: TemplateRoute.self) { route in
                switch route {
                case .editTemplate(let id):
                    if let templateDTO = filterStore.allTemplates.first(where: { $0.id == id}) {
                        let editStore = WorkoutTemplateEditStore(
                            dto: templateDTO,
                            repo: appComp.templateRepository,
                            exerciseProvider: appComp.exerciseProvider
                        )
                        
                        EditTemplateView(
                            editStore: editStore,
                            originalDTO: templateDTO
                        )
                        .navigationBarBackButtonHidden()
                    }else {
                        Text("Template not found")
                    }
                }
            }
        }
        .onAppear(perform: {
            tabActions.register(.templates) {
                showCreateTemplateSheet.toggle()
            }
        })
        .onDisappear(perform: {
            tabActions.unregister(.templates)
        })
        .sheet(isPresented: $showCreateTemplateSheet) {
            CreateTemplateSheet(
                isPresented: $showCreateTemplateSheet,
                templateProvider: appComp.templateProvider,
                muscleGroupProvider: appComp.muscleGroupProvider
            )
        }
    }
}

fileprivate struct TopBar: View {
    
    @ObservedObject var filterStore: TemplateFilterStore
    
    var body: some View {
        VStack (alignment: .leading, spacing: 8) {
            Text("Templates")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            SearchField(placeholder: "Search for templates", input: $filterStore.searchText)
                .frame(maxWidth: .infinity)
                .frame(height: 55)
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

fileprivate struct TemplateRowView: View, Equatable {
    
    let template: WorkoutTemplateDTO
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.template == rhs.template
    }
    
    var body: some View {
        HStack {
            Text(template.name)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background {
            RoundedRectangle(cornerRadius: 12).fill(Color(red: 0.937, green: 0.937, blue: 0.937))
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
    }
}


