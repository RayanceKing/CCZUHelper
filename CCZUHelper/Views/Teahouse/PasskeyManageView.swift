//
//  PasskeyManageView.swift
//  CCZUHelper
//
//  茶馆账号的通行密钥管理页：注册 / 重命名 / 删除。
//
//  Created for CCZUHelper on 2026/10/06.
//

import SwiftUI

struct PasskeyManageView: View {
    @StateObject private var manager = PasskeyManager()

    @State private var showError = false
    @State private var renameTarget: TeahousePasskey?
    @State private var renameText = ""
    @State private var deleteTarget: TeahousePasskey?

    var body: some View {
        content
            .navigationTitle("passkey.nav_title".localized)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .task { await manager.refresh() }
            .alert("passkey.rename.title".localized, isPresented: renameAlertBinding) {
                TextField("passkey.rename.placeholder".localized, text: $renameText)
                Button("common.cancel".localized, role: .cancel) { renameTarget = nil }
                Button("common.save".localized) {
                    guard let target = renameTarget else { return }
                    let newName = renameText
                    renameTarget = nil
                    Task { await manager.rename(id: target.id, to: newName) }
                }
            } message: {
                Text("passkey.rename.message".localized)
            }
            .alert("passkey.delete.title".localized, isPresented: deleteAlertBinding) {
                Button("common.cancel".localized, role: .cancel) { deleteTarget = nil }
                Button("common.delete".localized, role: .destructive) {
                    guard let target = deleteTarget else { return }
                    deleteTarget = nil
                    Task { await manager.delete(id: target.id) }
                }
            } message: {
                Text("passkey.delete.message".localized)
            }
            .alert("common.error".localized, isPresented: $showError) {
                Button("common.ok".localized, role: .cancel) { manager.errorMessage = nil }
            } message: {
                Text(manager.errorMessage ?? "")
            }
            .onChange(of: manager.errorMessage) { _, newValue in
                showError = newValue != nil
            }
    }

    // MARK: - Content

    private var content: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label("passkey.intro.title".localized, systemImage: "person.badge.key.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("passkey.intro.description".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                if manager.isLoading && manager.passkeys.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                } else if manager.passkeys.isEmpty {
                    Text("passkey.empty".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(manager.passkeys) { passkey in
                        passkeyRow(passkey)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteTarget = passkey
                                } label: {
                                    Label("common.delete".localized, systemImage: "trash")
                                }
                                Button {
                                    renameText = passkey.friendlyName ?? ""
                                    renameTarget = passkey
                                } label: {
                                    Label("passkey.rename.title".localized, systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            } header: {
                Text("passkey.list_header".localized)
            } footer: {
                if !manager.passkeys.isEmpty {
                    Text("passkey.list_footer".localized)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 380)
        #endif
    }

    private func passkeyRow(_ passkey: TeahousePasskey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(passkey.displayName)
                .font(.body)
            Text(subtitle(for: passkey))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                Task { await manager.register() }
            } label: {
                Label("passkey.add".localized, systemImage: "plus")
            }
            .disabled(manager.isLoading)
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )
    }

    private func subtitle(for passkey: TeahousePasskey) -> String {
        if let lastUsed = passkey.lastUsedAt {
            return "passkey.last_used".localized(with: Self.dateFormatter.string(from: lastUsed))
        }
        return "passkey.created_at".localized(with: Self.dateFormatter.string(from: passkey.createdAt))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()
}

#Preview {
    NavigationStack {
        PasskeyManageView()
    }
}
