//
//  PostListViewModel.swift
//  CCZUHelper
//
//  Created by rayanceking on 2025/12/13.
//

import Foundation
import Combine
import Supabase

@MainActor
class PostListViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchPosts() async {
        isLoading = true
        errorMessage = nil

        do {
            let response: PostgrestResponse<[Post]> = try await supabase
                .from("posts")
                .select("*")
                .order("created_at", ascending: false)
                .execute()

            posts = response.value
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
