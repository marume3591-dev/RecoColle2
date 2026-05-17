import Foundation

struct WikipediaService {
    
    func fetchArtistSummary(artistName: String) async -> String? {
        // MusicBrainz経由のみ。見つからなければnilを返す（フォールバックなし）
        guard let wikiTitle = await fetchWikiTitleViaMusicBrainz(artistName: artistName) else {
            print("❌ MusicBrainzでWikipediaタイトル取得できず:", artistName)
            return nil
        }
        
        let lang = Locale.current.language.languageCode?.identifier == "ja" ? "ja" : "en"
        
        // 日本語版を試してからなければ英語版
        if lang == "ja", let content = await fetchPageContent(title: wikiTitle, lang: "ja") {
            return content
        }
        if let content = await fetchPageContent(title: wikiTitle, lang: "en") {
            return content
        }
        return nil
    }
    
    // MARK: - MusicBrainz経由でWikipediaタイトルを取得
    private func fetchWikiTitleViaMusicBrainz(artistName: String) async -> String? {
        let encoded = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artistName
        let urlString = "https://musicbrainz.org/ws/2/artist/?query=artist:\(encoded)&fmt=json&limit=5"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("RecoColle2/1.0 (marume3591@icloud.com)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let artists = json["artists"] as? [[String: Any]] else { return nil }
            
            // 全候補をログに出す
            for artist in artists {
                print("🎤 候補:", artist["name"] ?? "", "score:", artist["score"] ?? "")
            }
            
            // 名前が完全一致するもののみ採用
            guard let matched = artists.first(where: { artist in
                guard let name = artist["name"] as? String else { return false }
                return name.lowercased() == artistName.lowercased()
            }), let mbid = matched["id"] as? String else {
                print("❌ 完全一致なし")
                return nil
            }
            
            print("✅ MusicBrainz MBID:", mbid, "name:", matched["name"] ?? "")
            return await fetchWikiTitleFromMBID(mbid: mbid)
            
        } catch {
            print("❌ MusicBrainz検索失敗:", error)
            return nil
        }
    }
    // MARK: - MBIDからWikipediaタイトルを取得
    private func fetchWikiTitleFromMBID(mbid: String) async -> String? {
        let urlString = "https://musicbrainz.org/ws/2/artist/\(mbid)?inc=url-rels&fmt=json"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("RecoColle2/1.0 (marume3591@icloud.com)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let relations = json["relations"] as? [[String: Any]] else { return nil }
            
            // まずwikipediaを探す
            for relation in relations {
                guard let type = relation["type"] as? String,
                      type == "wikipedia",
                      let urlObj = relation["url"] as? [String: Any],
                      let resource = urlObj["resource"] as? String else { continue }
                if let wikiTitle = resource.components(separatedBy: "/wiki/").last {
                    print("✅ Wikipedia title from MusicBrainz:", wikiTitle)
                    return wikiTitle.removingPercentEncoding ?? wikiTitle
                }
            }
            
            // なければwikidataからWikipediaタイトルを取得
            for relation in relations {
                guard let type = relation["type"] as? String,
                      type == "wikidata",
                      let urlObj = relation["url"] as? [String: Any],
                      let resource = urlObj["resource"] as? String,
                      let wikidataId = resource.components(separatedBy: "/wiki/").last else { continue }
                print("🔍 Wikidata ID:", wikidataId)
                return await fetchWikiTitleFromWikidata(wikidataId: wikidataId)
            }
            
            return nil
        } catch {
            print("❌ MBID詳細取得失敗:", error)
            return nil
        }
    }
    
    // WikidataIDからWikipediaタイトルを取得
    private func fetchWikiTitleFromWikidata(wikidataId: String) async -> String? {
        let lang = Locale.current.language.languageCode?.identifier == "ja" ? "ja" : "en"
        let urlString = "https://www.wikidata.org/w/api.php?action=wbgetentities&ids=\(wikidataId)&props=sitelinks&sitefilter=\(lang)wiki,enwiki&format=json"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let entities = json["entities"] as? [String: Any],
                  let entity = entities[wikidataId] as? [String: Any],
                  let sitelinks = entity["sitelinks"] as? [String: Any] else { return nil }
            
            // 日本語版を優先、なければ英語版
            if let jaWiki = sitelinks["\(lang)wiki"] as? [String: Any],
               let title = jaWiki["title"] as? String {
                print("✅ Wikipedia title from Wikidata (\(lang)):", title)
                return title
            }
            if let enWiki = sitelinks["enwiki"] as? [String: Any],
               let title = enWiki["title"] as? String {
                print("✅ Wikipedia title from Wikidata (en):", title)
                return title
            }
            return nil
        } catch {
            print("❌ Wikidata取得失敗:", error)
            return nil
        }
    }
    // MARK: - Wikipediaページ本文取得
    private func fetchPageContent(title: String, lang: String) async -> String? {
        let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        let urlString = "https://\(lang).wikipedia.org/w/api.php?action=query&prop=extracts&exintro=false&explaintext=true&titles=\(encoded)&format=json&exsectionformat=plain"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let query = json["query"] as? [String: Any],
                  let pages = query["pages"] as? [String: Any],
                  let page = pages.values.first as? [String: Any],
                  let extract = page["extract"] as? String else { return nil }
            
            let cleaned = extract
                .components(separatedBy: "\n")
                .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                .joined(separator: "\n\n")
            
            return cleaned.count > 3000 ? String(cleaned.prefix(3000)) + "…" : cleaned
        } catch { return nil }
    }
    
    // MARK: - フォールバック：従来の検索
    private func fetchViaSearch(artistName: String) async -> String? {
        let lang = Locale.current.language.languageCode?.identifier == "ja" ? "ja" : "en"
        let query = "\(artistName) musician"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://\(lang).wikipedia.org/w/api.php?action=query&list=search&srsearch=\(encoded)&format=json&srlimit=1"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let query = json["query"] as? [String: Any],
                  let search = query["search"] as? [[String: Any]],
                  let first = search.first,
                  let title = first["title"] as? String else { return nil }
            return await fetchPageContent(title: title, lang: lang)
        } catch { return nil }
    }
    // アルバム情報をWikipediaから取得
    func fetchAlbumSummary(artistName: String, albumTitle: String) async -> String? {
        // MusicBrainz経由でアルバムのWikipediaページを取得
        if let content = await fetchAlbumViaMusicBrainz(artistName: artistName, albumTitle: albumTitle) {
            return content
        }
        // 取れなければnil（フォールバックなし）
        print("❌ アルバム情報取得できず:", albumTitle)
        return nil
    }
    // MARK: - MusicBrainz経由でアルバム情報を取得
    private func fetchAlbumViaMusicBrainz(artistName: String, albumTitle: String) async -> String? {
        // アーティストMBIDを取得
        guard let mbid = await fetchArtistMBID(artistName: artistName) else {
            print("❌ アーティストMBID取得失敗:", artistName)
            return nil
        }
        
        // MBIDでリリース一覧を取得
        guard let releaseMBID = await fetchReleaseMBID(artistMBID: mbid, albumTitle: albumTitle) else {
            print("❌ リリースMBID取得失敗:", albumTitle)
            return nil
        }
        
        // リリースMBIDからWikipediaタイトルを取得
        guard let wikiTitle = await fetchWikiTitleFromReleaseMBID(releaseMBID: releaseMBID) else {
            print("❌ アルバムWikipediaタイトル取得失敗:", albumTitle)
            return nil
        }
        
        let lang = Locale.current.language.languageCode?.identifier == "ja" ? "ja" : "en"
        if lang == "ja", let content = await fetchPageContent(title: wikiTitle, lang: "ja") {
            return content
        }
        return await fetchPageContent(title: wikiTitle, lang: "en")
    }

    // アーティスト名からMBIDを取得（既存のfetchWikiTitleViaMusicBrainzと同じロジック）
    private func fetchArtistMBID(artistName: String) async -> String? {
        let encoded = artistName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? artistName
        let urlString = "https://musicbrainz.org/ws/2/artist/?query=artist:\(encoded)&fmt=json&limit=5"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("RecoColle2/1.0 (marume3591@icloud.com)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let artists = json["artists"] as? [[String: Any]] else { return nil }
            
            let matched = artists.first { artist in
                guard let name = artist["name"] as? String else { return false }
                return name.lowercased() == artistName.lowercased()
            }
            
            guard let mbid = matched?["id"] as? String else { return nil }
            print("✅ アーティストMBID:", mbid)
            return mbid
        } catch { return nil }
    }

    // アーティストMBIDとアルバム名からリリースMBIDを取得
    private func fetchReleaseMBID(artistMBID: String, albumTitle: String) async -> String? {
        let encoded = albumTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? albumTitle
        let urlString = "https://musicbrainz.org/ws/2/release-group/?query=releasegroup:\(encoded)%20AND%20arid:\(artistMBID)&fmt=json&limit=5"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("RecoColle2/1.0 (marume3591@icloud.com)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let releaseGroups = json["release-groups"] as? [[String: Any]] else { return nil }
            
            // タイトルが完全一致するものを優先
            let matched = releaseGroups.first { group in
                guard let title = group["title"] as? String else { return false }
                return title.lowercased() == albumTitle.lowercased()
            } ?? releaseGroups.first
            
            guard let mbid = matched?["id"] as? String,
                  let title = matched?["title"] as? String else { return nil }
            print("✅ リリースグループMBID:", mbid, "title:", title)
            return mbid
        } catch { return nil }
    }

    // リリースグループMBIDからWikipediaタイトルを取得
    private func fetchWikiTitleFromReleaseMBID(releaseMBID: String) async -> String? {
        let urlString = "https://musicbrainz.org/ws/2/release-group/\(releaseMBID)?inc=url-rels&fmt=json"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        request.setValue("RecoColle2/1.0 (marume3591@icloud.com)", forHTTPHeaderField: "User-Agent")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let relations = json["relations"] as? [[String: Any]] else { return nil }
            
            // wikipediaを優先
            for relation in relations {
                guard let type = relation["type"] as? String,
                      type == "wikipedia",
                      let urlObj = relation["url"] as? [String: Any],
                      let resource = urlObj["resource"] as? String,
                      let wikiTitle = resource.components(separatedBy: "/wiki/").last else { continue }
                print("✅ アルバムWikipedia title:", wikiTitle)
                return wikiTitle.removingPercentEncoding ?? wikiTitle
            }
            
            // なければwikidata経由
            for relation in relations {
                guard let type = relation["type"] as? String,
                      type == "wikidata",
                      let urlObj = relation["url"] as? [String: Any],
                      let resource = urlObj["resource"] as? String,
                      let wikidataId = resource.components(separatedBy: "/wiki/").last else { continue }
                print("🔍 アルバムWikidata ID:", wikidataId)
                return await fetchWikiTitleFromWikidata(wikidataId: wikidataId)
            }
            
            return nil
        } catch { return nil }
    }
    private func searchAlbumPageTitle(query: String, artistName: String, albumTitle: String) async -> String? {
        let lang = Locale.current.language.languageCode?.identifier == "ja" ? "ja" : "en"
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "https://\(lang).wikipedia.org/w/api.php?action=query&list=search&srsearch=\(encoded)&format=json&srlimit=5"
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let queryResult = json["query"] as? [String: Any],
                  let search = queryResult["search"] as? [[String: Any]] else { return nil }
            
            // 全候補をログに出す
            for result in search {
                print("💿 アルバム候補:", result["title"] ?? "")
            }
            
            let matched = search.first { result in
                guard let title = result["title"] as? String else { return false }
                return title.lowercased().contains(albumTitle.lowercased())
            } ?? search.first
            
            guard let title = matched?["title"] as? String else { return nil }
            print("✅ Wikipedia album title:", title)
            return title
        } catch { return nil }
    }
}
