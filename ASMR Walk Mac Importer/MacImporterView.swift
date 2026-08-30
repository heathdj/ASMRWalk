//
//  MacImporterView.swift
//  ASMR Walk Mac Importer
//

import SwiftUI

struct MacImporterView: View {
    @State private var viewModel = MacImporterViewModel()
    @State private var isImportingGPX = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            statusPanel
            actionBar
        }
        .padding(24)
        .frame(width: 560)
        .fileImporter(
            isPresented: $isImportingGPX,
            allowedContentTypes: [.gpx, .xml],
            allowsMultipleSelection: false
        ) { result in
            Task {
                await viewModel.handleGPXImportResult(result)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ASMR Walk Importer")
                .font(.title.bold())

            Text("Create route packages from ASMR Walk GPX exports.")
                .foregroundStyle(.secondary)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(viewModel.statusTitle, systemImage: viewModel.statusSystemImage)
                .font(.headline)

            if let message = viewModel.statusMessage {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if let packageURL = viewModel.packageURL {
                Text(packageURL.path(percentEncoded: false))
                    .font(.callout.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: .rect(cornerRadius: 8))
    }

    private var actionBar: some View {
        HStack {
            Button("Choose GPX Export", systemImage: "doc.badge.plus") {
                isImportingGPX = true
            }
            .buttonStyle(.borderedProminent)

            Button("Reveal Package", systemImage: "arrow.up.forward.app") {
                viewModel.revealPackageInFinder()
            }
            .disabled(viewModel.packageURL == nil)

            Spacer()
        }
    }
}

#Preview {
    MacImporterView()
}
