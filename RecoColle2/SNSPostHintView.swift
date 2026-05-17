import SwiftUI

struct SNSPostHintView: View {
    let record: RecordList2
    
    @State private var releaseDetail: ReleaseDetail?
    @State private var artistSummary: String?
    @State private var albumSummary: String?
    @State private var discography: [DiscographyItem] = []
    @State private var discographyPage = 1
    @State private var discographyTotalPages = 1
    @State private var isLoadingDiscography = false
    @State private var discographyArtistId: Int? = nil
    @State private var isLoading = true
    @State private var copiedSection: String? = nil

    var body: some View {
        contentView
            .navigationTitle((record.albumTitle ?? "") + NSLocalizedString("sns_title_suffix", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadData() }
    }
    
    @ViewBuilder
    private var contentView: some View {
        if isLoading {
            loadingView
        } else {
            scrollContent
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text(NSLocalizedString("sns_loading", comment: ""))
                .foregroundColor(.secondary)
        }
    }
    
    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                basicInfoSection
                artistSection
                albumSection
                if let detail = releaseDetail {
                    detailSections(detail: detail)
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Sections

    private var basicInfoSection: some View {
        let content = buildBasicInfoText()
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🎵 \(record.albumTitle ?? "") / \(record.artistName ?? "")")
                        .font(.headline)
                    if let detail = releaseDetail {
                        if let year = detail.year, let label = detail.label {
                            Text(String(format: NSLocalizedString("sns_year_label", comment: ""), year, label))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else if let year = detail.year {
                            Text(year)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else if let label = detail.label {
                            Text(label)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                Spacer()
                Button {
                    UIPasteboard.general.string = content
                    copiedSection = "basic"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSection = nil }
                } label: {
                    SwiftUI.Image(systemName: copiedSection == "basic" ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copiedSection == "basic" ? .green : .secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func buildBasicInfoText() -> String {
        var parts: [String] = []
        parts.append("🎵 \(record.albumTitle ?? "") / \(record.artistName ?? "")")
        if let detail = releaseDetail {
            if let year = detail.year, let label = detail.label {
                parts.append(String(format: NSLocalizedString("sns_year_label", comment: ""), year, label))
            } else if let year = detail.year {
                parts.append(year)
            } else if let label = detail.label {
                parts.append(label)
            }
        }
        return parts.joined(separator: "\n")
    }
    
    @ViewBuilder
    private var artistSection: some View {
        if let summary = artistSummary {
            SectionCard(
                title: NSLocalizedString("sns_artist_info", comment: ""),
                content: summary,
                copiedSection: $copiedSection
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("sns_artist_info", comment: ""))
                    .font(.headline)
                Text(NSLocalizedString("sns_no_artist_info", comment: ""))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var albumSection: some View {
        let content: String? = albumSummary ?? releaseDetail?.notes
        if let content = content, !content.isEmpty {
            SectionCard(
                title: NSLocalizedString("sns_album_info", comment: ""),
                content: content,
                copiedSection: $copiedSection
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("sns_album_info", comment: ""))
                    .font(.headline)
                Text(NSLocalizedString("sns_no_album_info", comment: ""))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func detailSections(detail: ReleaseDetail) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            if !detail.extraArtists.isEmpty {
                SectionCard(
                    title: NSLocalizedString("sns_musicians", comment: ""),
                    content: detail.extraArtists.joined(separator: "\n"),
                    copiedSection: $copiedSection
                )
            }
            if !detail.tracklist.isEmpty {
                SectionCard(
                    title: NSLocalizedString("sns_tracklist", comment: ""),
                    content: detail.tracklist.joined(separator: "\n"),
                    copiedSection: $copiedSection
                )
            }
            if !discography.isEmpty {
                discographySection
            }
            hashtagSection(detail: detail)
            actionButtons(detail: detail)
        }
    }

    // MARK: - Discography Section

    private var discographySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(NSLocalizedString("sns_discography", comment: ""))
                    .font(.headline)
                Spacer()
                Button {
                    let text = discography
                        .map { "・\($0.title) (\($0.displayYear))" }
                        .joined(separator: "\n")
                    UIPasteboard.general.string = text
                    copiedSection = "discography"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSection = nil }
                } label: {
                    SwiftUI.Image(systemName: copiedSection == "discography" ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copiedSection == "discography" ? .green : .secondary)
                }
            }

            ForEach(discography) { item in
                HStack(spacing: 12) {
                    if let thumb = item.thumb, let url = URL(string: thumb) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color(.tertiarySystemBackground)
                        }
                        .frame(width: 50, height: 50)
                        .cornerRadius(4)
                    } else {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemBackground))
                            .frame(width: 50, height: 50)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Text(item.displayYear)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let format = item.format {
                            Text(format)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                }
                .onAppear {
                    // 最後のアイテムが表示されたら次ページ読み込み
                    if item.id == discography.last?.id {
                        Task { await loadMoreDiscography() }
                    }
                }
                Divider()
            }

            // 読み込み中インジケーター
            if isLoadingDiscography {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    @ViewBuilder
    private func hashtagSection(detail: ReleaseDetail) -> some View {
        let tags = (detail.genres + detail.styles)
            .map { "#\($0.replacingOccurrences(of: " ", with: ""))" }
            .joined(separator: " ")
        if !tags.isEmpty {
            SectionCard(
                title: NSLocalizedString("sns_hashtags", comment: ""),
                content: tags,
                copiedSection: $copiedSection
            )
        }
    }
    
    private func actionButtons(detail: ReleaseDetail) -> some View {
        let fullText = buildFullText(detail: detail)
        return VStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = fullText
                copiedSection = "all"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSection = nil }
            } label: {
                Label(
                    copiedSection == "all"
                        ? NSLocalizedString("sns_copied", comment: "")
                        : NSLocalizedString("sns_copy_all", comment: ""),
                    systemImage: copiedSection == "all" ? "checkmark" : "doc.on.doc"
                )
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemBlue))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        async let detail = DiscogsService().fetchReleaseDetail(
            releaseId: record.discogsReleaseId ?? ""
        )
        async let artistSummaryResult = WikipediaService().fetchArtistSummary(
            artistName: record.artistName ?? ""
        )
        async let albumSummaryResult = WikipediaService().fetchAlbumSummary(
            artistName: record.artistName ?? "",
            albumTitle: record.albumTitle ?? ""
        )

        let fetchedDetail = try? await detail
        releaseDetail = fetchedDetail
        artistSummary = await artistSummaryResult
        albumSummary = await albumSummaryResult

        if let artistId = fetchedDetail?.artistId {
            discographyArtistId = artistId
            await loadMoreDiscography()
        }

        isLoading = false
    }

    private func loadMoreDiscography() async {
        guard !isLoadingDiscography,
              discographyPage <= discographyTotalPages,
              let artistId = discographyArtistId else { return }

        isLoadingDiscography = true
        defer { isLoadingDiscography = false }

        if let result = try? await DiscogsService().fetchArtistDiscography(artistId: artistId, page: discographyPage) {
            let newItems = result.releases
                .filter { $0.role == "Main" }
                .sorted { ($0.year ?? 0) < ($1.year ?? 0) }
            discography.append(contentsOf: newItems)
            discographyTotalPages = result.pagination.pages
            discographyPage += 1
        }
    }

    // MARK: - Text Builder

    private func buildFullText(detail: ReleaseDetail) -> String {
        var parts: [String] = []
        
        parts.append("🎵 \(record.albumTitle ?? "") / \(record.artistName ?? "")")
        
        if let year = detail.year, let label = detail.label {
            parts.append(String(format: NSLocalizedString("sns_year_label", comment: ""), year, label))
        } else if let year = detail.year {
            parts.append(year)
        } else if let label = detail.label {
            parts.append(label)
        }
        
        if let summary = artistSummary {
            parts.append("\n🎤 " + NSLocalizedString("sns_artist_info", comment: "") + "\n" + String(summary.prefix(150)) + "…")
        }
        
        let albumContent: String? = albumSummary ?? detail.notes
        if let albumContent = albumContent, !albumContent.isEmpty {
            parts.append("\n💿 " + NSLocalizedString("sns_album_info", comment: "") + "\n" + String(albumContent.prefix(150)) + "…")
        }
        
        if !detail.extraArtists.isEmpty {
            parts.append("\n🎸 " + NSLocalizedString("sns_musicians", comment: "") + "\n" + detail.extraArtists.prefix(5).joined(separator: "\n"))
        }
        
        if !detail.tracklist.isEmpty {
            parts.append("\n🎵 " + NSLocalizedString("sns_tracklist", comment: "") + "\n" + detail.tracklist.joined(separator: "\n"))
        }

        if !discography.isEmpty {
            let lines = discography.prefix(10).map { "・\($0.title) (\($0.displayYear))" }.joined(separator: "\n")
            parts.append("\n📀 " + NSLocalizedString("sns_discography", comment: "") + "\n" + lines)
        }
        
        let tags = (detail.genres + detail.styles)
            .map { "#\($0.replacingOccurrences(of: " ", with: ""))" }
            .joined(separator: " ")
        if !tags.isEmpty { parts.append("\n" + tags) }
        
        return parts.joined(separator: "\n")
    }
}

// MARK: - SectionCard

struct SectionCard: View {
    let title: String
    let content: String
    @Binding var copiedSection: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    UIPasteboard.general.string = content
                    copiedSection = title
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copiedSection = nil }
                } label: {
                    SwiftUI.Image(systemName: copiedSection == title ? "checkmark" : "doc.on.doc")
                        .foregroundColor(copiedSection == title ? .green : .secondary)
                }
            }
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}
