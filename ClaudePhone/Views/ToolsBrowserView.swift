import SwiftUI

// MARK: - Tools Browser View
struct ToolsBrowserView: View {
    @State private var searchText = ""
    @State private var selectedCategory: ToolCategory?
    @State private var expandedTool: String?

    private let registry = ToolRegistry.shared

    var filteredCategories: [ToolCategory] {
        if searchText.isEmpty {
            return ToolCategory.allCases.filter { !registry.tools(for: $0).isEmpty }
        }
        return ToolCategory.allCases.filter { category in
            registry.tools(for: category).contains { tool in
                tool.name.localizedCaseInsensitiveContains(searchText) ||
                tool.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Stats bar
                        statsBar

                        // Category grid
                        if searchText.isEmpty && selectedCategory == nil {
                            categoryGrid
                        }

                        // Tool list
                        if let category = selectedCategory {
                            toolList(for: category)
                        } else if !searchText.isEmpty {
                            searchResults
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppTheme.backgroundPrimary, for: .navigationBar)
            .searchable(text: $searchText, prompt: "Search tools...")
            .toolbar {
                if selectedCategory != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(AppTheme.springAnimation) {
                                selectedCategory = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("All")
                            }
                            .foregroundColor(AppTheme.primary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Stats Bar
    private var statsBar: some View {
        HStack(spacing: 12) {
            StatBadge(
                icon: "wrench.fill",
                value: "\(registry.allTools.count)",
                label: "Tools",
                color: AppTheme.primary
            )

            StatBadge(
                icon: "folder.fill",
                value: "\(filteredCategories.count)",
                label: "Categories",
                color: AppTheme.accent
            )

            StatBadge(
                icon: "cpu",
                value: "30+",
                label: "Frameworks",
                color: AppTheme.success
            )
        }
    }

    // MARK: - Category Grid
    private var categoryGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 8) {
            ForEach(filteredCategories, id: \.self) { category in
                CategoryCard(category: category, toolCount: registry.tools(for: category).count)
                    .onTapGesture {
                        withAnimation(AppTheme.springAnimation) {
                            selectedCategory = category
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }
            }
        }
    }

    // MARK: - Tool List
    private func toolList(for category: ToolCategory) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .foregroundColor(Color(hex: category.color))
                Text(category.rawValue)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppTheme.textPrimary)
                Spacer()
                Text("\(registry.tools(for: category).count) tools")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.textTertiary)
            }

            ForEach(registry.tools(for: category), id: \.name) { tool in
                ToolRow(tool: tool, isExpanded: expandedTool == tool.name)
                    .onTapGesture {
                        withAnimation(AppTheme.springAnimation) {
                            expandedTool = expandedTool == tool.name ? nil : tool.name
                        }
                    }
            }
        }
    }

    // MARK: - Search Results
    private var searchResults: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(filteredCategories, id: \.self) { category in
                let tools = registry.tools(for: category).filter { tool in
                    tool.name.localizedCaseInsensitiveContains(searchText) ||
                    tool.description.localizedCaseInsensitiveContains(searchText)
                }

                if !tools.isEmpty {
                    Text(category.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.textSecondary)
                        .padding(.top, 4)

                    ForEach(tools, id: \.name) { tool in
                        ToolRow(tool: tool, isExpanded: expandedTool == tool.name)
                            .onTapGesture {
                                withAnimation(AppTheme.springAnimation) {
                                    expandedTool = expandedTool == tool.name ? nil : tool.name
                                }
                            }
                    }
                }
            }
        }
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.textPrimary)

            Text(label)
                .font(.system(size: 10))
                .foregroundColor(AppTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .cardStyle()
    }
}

// MARK: - Category Card
struct CategoryCard: View {
    let category: ToolCategory
    let toolCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: category.icon)
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: category.color))
                Spacer()
                Text("\(toolCount)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(AppTheme.backgroundTertiary))
            }

            Text(category.rawValue)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.textPrimary)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .fill(AppTheme.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusMedium)
                .stroke(AppTheme.glassBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Tool Row
struct ToolRow: View {
    let tool: ClaudeTool
    let isExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "function")
                    .font(.system(size: 11))
                    .foregroundColor(AppTheme.accent)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(AppTheme.accent.opacity(0.15)))

                Text(tool.name)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(AppTheme.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(AppTheme.textTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tool.description)
                        .font(.system(size: 12))
                        .foregroundColor(AppTheme.textSecondary)

                    if !tool.parameters.isEmpty {
                        Text("Parameters:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.textTertiary)

                        ForEach(tool.parameters, id: \.name) { param in
                            HStack(alignment: .top, spacing: 4) {
                                Text(param.name)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(AppTheme.accent)

                                Text("(\(param.type.rawValue))")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(AppTheme.textTertiary)

                                if param.isRequired {
                                    Text("*")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(AppTheme.error)
                                }
                            }
                        }
                    }
                }
                .padding(.leading, 28)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .fill(isExpanded ? AppTheme.backgroundTertiary : AppTheme.backgroundSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.radiusSmall)
                .stroke(AppTheme.glassBorder, lineWidth: 0.5)
        )
    }
}
