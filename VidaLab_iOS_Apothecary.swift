//
//  VidaLab_iOS_Apothecary.swift
//  VIDA LAB — Apothecary, Condition Library, Community
//
//  Requires VidaLab_iOS_Core.swift in the same target.
//  This file contains the full Apothecary with context-sensitive filtering
//  (categories above search, Filters button with dropdown, filters adapt to selected category),
//  plus the Condition Library and Community views.
//

import SwiftUI

// MARK: - Apothecary View

struct ApothecaryView: View {
    @State private var resources: [HealthResource] = []
    @State private var favorites: [String: Favorite] = [:]
    @State private var isLoading = false
    @State private var selectedCategory: ApothecaryCategory = .all
    @State private var selectedSubcategory = "all"
    @State private var selectedFocus: Set<String> = []
    @State private var searchText = ""
    @State private var showFilters = false
    @State private var showFavoritesOnly = false
    @State private var selectedResource: HealthResource?

    private var subs: [String] { selectedCategory == .all ? [] : ApothecarySubcategory.forCategory(selectedCategory.rawValue) }

    // Context-sensitive: only show focus groups relevant to the selected category
    private var visibleFocusGroups: [FocusGroup] {
        apothecaryFocusGroups.filter { selectedCategory == .all || $0.categories.contains(selectedCategory.rawValue) }
    }

    private var activeFilterCount: Int {
        (selectedSubcategory != "all" ? 1 : 0) + selectedFocus.count + (showFavoritesOnly ? 1 : 0)
    }

    private var filtered: [HealthResource] {
        resources.filter { r in
            let cat = selectedCategory == .all || r.category == selectedCategory.rawValue
            let sub = selectedSubcategory == "all" || r.subcategory == selectedSubcategory
            let focus = selectedFocus.isEmpty || selectedFocus.allSatisfy { r.tags?.contains($0) ?? false }
            let fav = !showFavoritesOnly || favorites[r.id] != nil
            let q = searchText.isEmpty || r.title.lowercased().contains(searchText.lowercased()) || (r.description?.lowercased().contains(searchText.lowercased()) ?? false) || (r.tags?.contains { $0.lowercased().contains(searchText.lowercased()) } ?? false)
            return cat && sub && focus && fav && q
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Medical disclaimer
                Text("⚠️ Educational purposes only. Not medical advice. Consult your provider before starting any new routine.")
                    .font(.caption).foregroundColor(.red.opacity(0.8)).padding(12).background(Color.red.opacity(0.05)).cornerRadius(10)

                // Category buttons (always visible, above search)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ApothecaryCategory.allCases) { cat in
                            Button(cat.label) {
                                selectedCategory = cat; selectedSubcategory = "all"; clearIrrelevantFocus()
                            }
                            .font(.caption).padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selectedCategory == cat ? Color(red: 0.18, green: 0.27, blue: 0.24) : Color(.systemGray5))
                            .foregroundColor(selectedCategory == cat ? .white : .primary).cornerRadius(20)
                        }
                    }
                }

                // Search + Filter button
                HStack {
                    TextField("Search…", text: $searchText).textFieldStyle(.roundedBorder)
                    Button(action: { showFilters.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3"); Text("Filters")
                            if activeFilterCount > 0 {
                                Text("\(activeFilterCount)").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(showFilters ? Color.white : Color(red: 0.24, green: 0.42, blue: 0.31))
                                    .foregroundColor(showFilters ? Color(red: 0.18, green: 0.27, blue: 0.24) : .white).clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(showFilters ? Color(red: 0.18, green: 0.27, blue: 0.24) : Color(.systemGray5))
                        .foregroundColor(showFilters ? .white : .primary).cornerRadius(20)
                    }
                }

                // Filter dropdown (context-sensitive — only shows filters relevant to selected category)
                if showFilters {
                    VStack(alignment: .leading, spacing: 16) {
                        if !subs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Subcategory").font(.caption.bold()).foregroundColor(.secondary)
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 6) {
                                        FilterChip(label: "All", isActive: selectedSubcategory == "all") { selectedSubcategory = "all" }
                                        ForEach(subs, id: \.self) { s in
                                            FilterChip(label: ApothecarySubcategory.prettyLabel(s), isActive: selectedSubcategory == s) { selectedSubcategory = selectedSubcategory == s ? "all" : s }
                                        }
                                    }
                                }
                            }
                        }

                        // Focus groups — context-sensitive per category
                        // Each group only shows if it applies to the selected category
                        // Individual filters within a group can also be category-specific
                        // (e.g. "One-Pot" only shows for Recipes)
                        ForEach(visibleFocusGroups) { group in
                            let visibleFilters = group.filters.filter { selectedCategory == .all || $0.categories == nil || $0.categories!.contains(selectedCategory.rawValue) }
                            if !visibleFilters.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(group.label).font(.caption.bold()).foregroundColor(.secondary)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(visibleFilters) { f in
                                                FilterChip(label: f.label, isActive: selectedFocus.contains(f.tag)) {
                                                    if selectedFocus.contains(f.tag) { selectedFocus.remove(f.tag) } else { selectedFocus.insert(f.tag) }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        if !favorites.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Saved").font(.caption.bold()).foregroundColor(.secondary)
                                FilterChip(label: "♡ My Favorites", isActive: showFavoritesOnly) { showFavoritesOnly.toggle() }
                            }
                        }

                        if activeFilterCount > 0 {
                            Button("Clear all filters") { selectedSubcategory = "all"; selectedFocus.removeAll(); showFavoritesOnly = false }
                                .font(.caption).foregroundColor(.red)
                        }
                    }
                    .padding().background(Color(.systemGray6)).cornerRadius(12)
                }

                Text("\(filtered.count) \(filtered.count == 1 ? "resource" : "resources")")
                    .font(.caption).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)

                if isLoading {
                    ProgressView().padding(.top, 40)
                } else if filtered.isEmpty {
                    Text("No resources match your filters.").foregroundColor(.secondary).padding(.top, 40)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(filtered) { r in
                            ApothecaryResourceCard(resource: r, isFavorited: favorites[r.id] != nil) { selectedResource = r }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("The Apothecary")
        .sheet(item: $selectedResource) { r in
            ApothecaryResourceDetailView(resource: r, isFavorited: favorites[r.id] != nil) { Task { await toggleFavorite(r) } }
        }
        .task { await load() }
    }

    // When category changes, remove focus tags that no longer apply
    private func clearIrrelevantFocus() {
        let applicable = Set(apothecaryFocusGroups
            .filter { selectedCategory == .all || $0.categories.contains(selectedCategory.rawValue) }
            .flatMap { $0.filters.filter { selectedCategory == .all || $0.categories == nil || $0.categories!.contains(selectedCategory.rawValue) }.map { $0.tag } })
        selectedFocus = selectedFocus.intersection(applicable)
    }

    private func load() async {
        isLoading = true
        do {
            resources = try await VidaAPIClient.shared.listEntities("HealthResource", sort: "sort_order", limit: 1000)
            let favs: [Favorite] = try await VidaAPIClient.shared.listEntities("Favorite", sort: "-created_date", limit: 500)
            favorites = favs.reduce(into: [String: Favorite]()) { $0[$1.resource_id] = $1 }
        } catch {}
        isLoading = false
    }

    private func toggleFavorite(_ r: HealthResource) async {
        do {
            let resp = try await VidaAPIClient.shared.toggleFavorite(resourceId: r.id, title: r.title, category: r.category)
            if resp.favorited { favorites[r.id] = Favorite(id: "local", resource_id: r.id, resource_title: r.title, resource_category: r.category) }
            else { favorites.removeValue(forKey: r.id) }
        } catch {}
    }
}

struct ApothecaryResourceCard: View {
    let resource: HealthResource
    let isFavorited: Bool
    let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(resource.category.capitalized).font(.caption2.bold()).padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color(red: 0.24, green: 0.42, blue: 0.31).opacity(0.15)).foregroundColor(Color(red: 0.24, green: 0.42, blue: 0.31)).cornerRadius(20)
                    Spacer()
                    Image(systemName: isFavorited ? "heart.fill" : "heart").foregroundColor(isFavorited ? .red : .secondary)
                }
                Text(resource.title).font(.system(size: 15, weight: .medium)).foregroundColor(.primary).lineLimit(2)
                if let d = resource.description { Text(d).font(.caption).foregroundColor(.secondary).lineLimit(2) }
                if let diff = resource.difficulty { Text(diff.capitalized).font(.caption2).foregroundColor(.secondary) }
            }
            .padding(14).background(Color(.systemGray6)).cornerRadius(14)
        }
        .buttonStyle(.plain)
    }
}

struct ApothecaryResourceDetailView: View {
    let resource: HealthResource
    let isFavorited: Bool
    let onToggleFavorite: () -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(resource.category.capitalized).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color(red: 0.24, green: 0.42, blue: 0.31).opacity(0.15)).foregroundColor(Color(red: 0.24, green: 0.42, blue: 0.31)).cornerRadius(20)
                        Spacer()
                        Button(action: onToggleFavorite) { Image(systemName: isFavorited ? "heart.fill" : "heart").foregroundColor(isFavorited ? .red : .secondary) }
                    }
                    Text(resource.title).font(.title2.bold())
                    if let d = resource.description { Text(d).font(.subheadline).foregroundColor(.secondary) }
                    if let c = resource.content { Text(c).font(.body).foregroundColor(.primary) }
                    if let tags = resource.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) { ForEach(tags, id: \.self) { tag in
                                Text(tag.replacingOccurrences(of: "-", with: " ")).font(.caption2).padding(.horizontal, 8).padding(.vertical, 3).background(Color(.systemGray5)).cornerRadius(20)
                            } }
                        }
                    }
                    if let cit = resource.citations { Text("Sources").font(.headline); Text(cit).font(.caption).foregroundColor(.secondary) }
                }
                .padding()
            }
            .navigationTitle("Resource").toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - Filter Chip Helper

struct FilterChip: View {
    let label: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label).font(.caption).padding(.horizontal, 12).padding(.vertical, 7)
                .background(isActive ? Color(red: 0.18, green: 0.27, blue: 0.24) : Color(.systemGray5))
                .foregroundColor(isActive ? .white : .primary).cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Condition Library

struct ConditionLibraryView: View {
    @State private var reports: [DiseaseReport] = [], isLoading = false
    @State private var selectedCategory = "all"
    private let categories = ["all","autoimmune","neurological","cardiovascular","endocrine","musculoskeletal","gastrointestinal","respiratory","mental_health","chronic_pain","dysautonomia","gynecological","other"]
    var body: some View {
        List {
            Picker("Category", selection: $selectedCategory) { ForEach(categories, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }
            if isLoading { ProgressView() }
            ForEach(filtered) { r in
                NavigationLink(destination: ConditionDetailView(report: r)) {
                    VStack(alignment: .leading, spacing: 4) { Text(r.name).font(.headline); if let s = r.summary { Text(s).font(.caption).foregroundColor(.secondary).lineLimit(2) } }
                }
            }
        }
        .navigationTitle("Condition Library").task { await load() }
    }
    private var filtered: [DiseaseReport] { selectedCategory == "all" ? reports : reports.filter { $0.category == selectedCategory } }
    private func load() async { isLoading = true; do { reports = try await VidaAPIClient.shared.listEntities("DiseaseReport", sort: "sort_order", limit: 500) } catch {}; isLoading = false }
}

struct ConditionDetailView: View {
    let report: DiseaseReport
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(report.name).font(.title.bold())
                if let s = report.summary { Text(s).font(.subheadline).foregroundColor(.secondary) }
                if let o = report.overview { DetailSection(title: "Overview", text: o) }
                if let s = report.symptoms { DetailSection(title: "Symptoms", text: s) }
                if let d = report.diagnosis { DetailSection(title: "Diagnosis", text: d) }
                if let t = report.treatments { DetailSection(title: "Treatments", text: t) }
                if let g = report.doctors_guide { DetailSection(title: "Doctors to See", text: g) }
                if let a = report.advocacy_guide { DetailSection(title: "Self-Advocacy Guide", text: a) }
                if let c = report.conquer_plan { DetailSection(title: "Conquer Plan", text: c) }
                if let r = report.resources { DetailSection(title: "Medical Resources", text: r) }
            }
            .padding()
        }
        .navigationTitle(report.name)
    }
}

struct DetailSection: View {
    let title: String; let text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) { Text(title).font(.headline); Text(text).font(.body).foregroundColor(.secondary) }
        .frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(.systemGray6)).cornerRadius(12)
    }
}

// MARK: - Community

struct CommunityView: View {
    @State private var posts: [CommunityPost] = [], isLoading = false, showCreate = false, selectedCategory = "general"
    private let categories = [("general","General"),("sleep","Sleep"),("mood","Mood"),("nutrition","Nutrition"),("movement","Movement"),("stress","Stress"),("chronic_conditions","Chronic Conditions"),("treatments","Treatments"),("other","Other")]
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { ForEach(categories, id: \.0) { id, label in
                    Button(label) { selectedCategory = id }.font(.caption).padding(.horizontal, 14).padding(.vertical, 8)
                        .background(selectedCategory == id ? Color(red: 0.18, green: 0.27, blue: 0.24) : Color(.systemGray5))
                        .foregroundColor(selectedCategory == id ? .white : .primary).cornerRadius(20)
                } }.padding(.horizontal)
            }.padding(.vertical, 8)
            List {
                if isLoading { ProgressView() }
                ForEach(filteredPosts) { post in
                    NavigationLink(destination: PostDetailView(post: post)) {
                        VStack(alignment: .leading, spacing: 4) { Text(post.title).font(.headline); Text(post.content).font(.caption).foregroundColor(.secondary).lineLimit(2); Text(post.display_name ?? "Anonymous").font(.caption2).foregroundColor(.secondary) }
                    }
                }
            }
        }
        .navigationTitle("Community").toolbar { Button("New Post") { showCreate = true } }
        .sheet(isPresented: $showCreate) { NewPostView { load() } }.task { await load() }
    }
    private var filteredPosts: [CommunityPost] { selectedCategory == "general" ? posts : posts.filter { $0.category == selectedCategory } }
    private func load() async { isLoading = true; do { posts = try await VidaAPIClient.shared.listEntities("CommunityPost", sort: "-created_date", limit: 100) } catch {}; isLoading = false }
}

struct NewPostView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = "", content = "", displayName = "Anonymous", category = "general", isLoading = false
    var onCreated: () -> Void
    private let categories = [("general","General"),("sleep","Sleep"),("mood","Mood"),("nutrition","Nutrition"),("movement","Movement"),("stress","Stress"),("chronic_conditions","Chronic Conditions"),("treatments","Treatments"),("other","Other")]
    var body: some View {
        NavigationStack {
            Form {
                Section("Display Name") { TextField("Anonymous", text: $displayName) }
                Section("Title") { TextField("Post title", text: $title) }
                Section("Category") { Picker("Category", selection: $category) { ForEach(categories, id: \.0) { Text($1).tag($0) } } }
                Section("Content") { TextEditor(text: $content) }
            }
            .navigationTitle("New Post")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Post") { create() }.disabled(isLoading || title.isEmpty || content.isEmpty) } }
        }
    }
    private func create() {
        isLoading = true
        Task { do { let _: CommunityPost = try await VidaAPIClient.shared.createEntity("CommunityPost", body: ["title": title, "content": content, "category": category, "display_name": displayName, "status": "active", "flagged": false]); onCreated(); dismiss() } catch {}; isLoading = false }
    }
}

struct PostDetailView: View {
    let post: CommunityPost
    @State private var replies: [CommunityReply] = [], newReply = "", isLoading = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(post.title).font(.title2.bold()); Text(post.content).font(.body); Text(post.display_name ?? "Anonymous").font(.caption).foregroundColor(.secondary)
                Divider(); Text("Replies").font(.headline)
                ForEach(replies) { r in VStack(alignment: .leading, spacing: 4) { Text(r.content).font(.subheadline); Text(r.display_name ?? "Anonymous").font(.caption2).foregroundColor(.secondary) }.padding().background(Color(.systemGray6)).cornerRadius(10) }
                HStack { TextField("Write a reply…", text: $newReply).textFieldStyle(.roundedBorder); Button("Send") { reply() }.disabled(newReply.isEmpty || isLoading) }
            }
            .padding()
        }
        .navigationTitle("Post").task { await loadReplies() }
    }
    private func loadReplies() async { do { replies = try await VidaAPIClient.shared.listEntities("CommunityReply", sort: "created_date", limit: 200, filter: ["post_id": post.id]) } catch {} }
    private func reply() {
        isLoading = true
        Task { do { let _: CommunityReply = try await VidaAPIClient.shared.createEntity("CommunityReply", body: ["post_id": post.id, "content": newReply, "display_name": "Anonymous", "status": "active", "flagged": false]); newReply = ""; await loadReplies() } catch {}; isLoading = false }
    }
}

// MARK: - App Entry Point
//
//  In your @main App file:
//
//  @main
//  struct VidaLabApp: App {
//      var body: some Scene {
//          WindowGroup { VidaAppRoot() }
//      }
//  }