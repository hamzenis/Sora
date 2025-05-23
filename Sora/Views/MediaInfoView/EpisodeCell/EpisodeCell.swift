//
//  EpisodeCell.swift
//  Sora
//
//  Created by Francesco on 18/12/24.
//

import SwiftUI
import Kingfisher

struct EpisodeLink: Identifiable {
    let id = UUID()
    let number: Int
    let href: String
}

struct EpisodeCell: View {
    let episodeIndex: Int
    let episode: String
    let episodeID: Int
    let progress: Double
    let itemID: Int
    
    let onTap: (String) -> Void
    let onMarkAllPrevious: () -> Void
    
    @State private var episodeTitle: String = ""
    @State private var episodeImageUrl: String = ""
    @State private var isLoading: Bool = true
    @State private var currentProgress: Double = 0.0
    
    var body: some View {
        HStack {
            ZStack {
                KFImage(URL(string: episodeImageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : episodeImageUrl))
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 100, height: 56)
                    .cornerRadius(8)
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            
            VStack(alignment: .leading) {
                Text("Episode \(episodeID + 1)")
                    .font(.system(size: 15))
                if !episodeTitle.isEmpty {
                    Text(episodeTitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            CircularProgressBar(progress: currentProgress)
                .frame(width: 40, height: 40)
        }
        .contentShape(Rectangle())
        .contextMenu {
            if progress <= 0.9 {
                Button(action: markAsWatched) {
                    Label("Mark as Watched", systemImage: "checkmark.circle")
                }
            }
            
            if progress != 0 {
                Button(action: resetProgress) {
                    Label("Reset Progress", systemImage: "arrow.counterclockwise")
                }
            }
            
            if episodeIndex > 0 {
                Button(action: onMarkAllPrevious) {
                    Label("Mark All Previous Watched", systemImage: "checkmark.circle.fill")
                }
            }
        }
        .onAppear {
            updateProgress()
            
            if UserDefaults.standard.object(forKey: "fetchEpisodeMetadata") == nil
                || UserDefaults.standard.bool(forKey: "fetchEpisodeMetadata") {
                fetchEpisodeDetails()
            }
        }
        .onChange(of: progress) { newProgress in
            updateProgress()
        }
        .onTapGesture {
            let imageUrl = episodeImageUrl.isEmpty ? "https://raw.githubusercontent.com/cranci1/Sora/refs/heads/main/assets/banner2.png" : episodeImageUrl
            onTap(imageUrl)
        }
    }
    
    private func markAsWatched() {
        let userDefaults = UserDefaults.standard
        let totalTime = 1000.0
        let watchedTime = totalTime
        userDefaults.set(watchedTime, forKey: "lastPlayedTime_\(episode)")
        userDefaults.set(totalTime, forKey: "totalTime_\(episode)")
        DispatchQueue.main.async {
            self.updateProgress()
        }
    }
    
    private func resetProgress() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(0.0, forKey: "lastPlayedTime_\(episode)")
        userDefaults.set(0.0, forKey: "totalTime_\(episode)")
        DispatchQueue.main.async {
            self.updateProgress()
        }
    }
    
    private func updateProgress() {
        let userDefaults = UserDefaults.standard
        let lastPlayedTime = userDefaults.double(forKey: "lastPlayedTime_\(episode)")
        let totalTime = userDefaults.double(forKey: "totalTime_\(episode)")
        currentProgress = totalTime > 0 ? min(lastPlayedTime / totalTime, 1.0) : 0
    }
    
    private func fetchEpisodeDetails() {
        guard let url = URL(string: "https://api.ani.zip/mappings?anilist_id=\(itemID)") else {
            isLoading = false
            return
        }
        
        URLSession.custom.dataTask(with: url) { data, _, error in
            if let error = error {
                Logger.shared.log("Failed to fetch episode details: \(error)", type: "Error")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }
            
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                guard let json = jsonObject as? [String: Any],
                      let episodes = json["episodes"] as? [String: Any],
                      let episodeDetails = episodes["\(episodeID + 1)"] as? [String: Any],
                      let title = episodeDetails["title"] as? [String: String],
                      let image = episodeDetails["image"] as? String else {
                          Logger.shared.log("Invalid response format", type: "Error")
                          DispatchQueue.main.async {
                              self.isLoading = false
                          }
                          return
                      }
                
                DispatchQueue.main.async {
                    self.episodeTitle = title["en"] ?? ""
                    self.episodeImageUrl = image
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }.resume()
    }
}
