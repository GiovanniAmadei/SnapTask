import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var selectedLocation: TaskLocation?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme
    @StateObject private var viewModel = LocationPickerViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected Location Preview (always visible if a location is set)
                if let selectedLoc = selectedLocation {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("selected_location".localized)
                            .font(.headline)
                            .themedPrimaryText()
                            .padding(.horizontal)

                        LocationMapView(location: selectedLoc, height: 150, allowsInteraction: false)
                            .padding(.horizontal)
                    }
                    .padding(.top, 8)
                }

                // Search Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("search_location".localized)
                        .font(.headline)
                        .themedPrimaryText()
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .themedSecondaryText()
                        TextField("search_for_a_place".localized, text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .themedPrimaryText()
                            .accentColor(theme.primaryColor)
                            .onSubmit {
                                viewModel.searchLocations(query: searchText)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                viewModel.clearSearchResults()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .themedSecondaryText()
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(theme.backgroundColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(theme.borderColor, lineWidth: 1)
                            )
                    )
                    .padding(.horizontal)
                    
                    // Search Results
                    if viewModel.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                                .accentColor(theme.primaryColor)
                            Text("searching".localized)
                                .font(.subheadline)
                                .themedSecondaryText()
                        }
                        .padding(.horizontal)
                    } else if !viewModel.searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.searchResults, id: \.id) { location in
                                    LocationResultRow(location: location) {
                                        selectedLocation = location
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else if !searchText.isEmpty && !viewModel.isSearching {
                        Text("no_results_found".localized)
                            .font(.subheadline)
                            .themedSecondaryText()
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Clear Location Button
                if selectedLocation != nil {
                    Button(action: {
                        selectedLocation = nil
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("remove_location".localized)
                        }
                        .font(.headline)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.1))
                        )
                    }
                    .padding()
                }
            }
            .themedBackground()
            .navigationTitle("select_location".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                    .tint(.red)
                }
            }
            .onChange(of: searchText) { _, newValue in
                if !newValue.isEmpty {
                    viewModel.searchLocations(query: newValue)
                } else {
                    viewModel.clearSearchResults()
                }
            }
        }
    }
}

struct LocationResultRow: View {
    let location: TaskLocation
    let onTap: () -> Void
    @Environment(\.theme) private var theme
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .themedPrimaryText()
                        .multilineTextAlignment(.leading)
                    
                    if let address = location.address {
                        Text(address)
                            .font(.subheadline)
                            .themedSecondaryText()
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .themedSecondaryText()
                    .font(.system(size: 12))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.surfaceColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(theme.borderColor, lineWidth: 1)
                    )
                    .shadow(color: theme.shadowColor, radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

class LocationPickerViewModel: NSObject, ObservableObject {
    @Published var searchResults: [TaskLocation] = []
    @Published var isSearching = false
    
    private var searchTimer: Timer?
    private var currentSearchTask: URLSessionDataTask?
    
    override init() {
        super.init()
    }
    
    func searchLocations(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        searchTimer?.invalidate()
        currentSearchTask?.cancel()
        isSearching = true
        
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.performDirectSearch(query: query)
        }
    }
    
    private func performDirectSearch(query: String) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 45.4642, longitude: 9.1900), // Milano as center
            span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
        )
        
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isSearching = false
                
                if let error = error {
                    print("Search error: \(error.localizedDescription)")
                    self.searchResults = []
                    return
                }
                
                if let mapItems = response?.mapItems {
                    let locations = mapItems.prefix(15).compactMap { mapItem -> TaskLocation? in
                        guard let name = mapItem.name else { return nil }
                        return TaskLocation(
                            name: name,
                            address: self.formatAddress(from: mapItem.placemark),
                            coordinate: mapItem.placemark.coordinate,
                            placemark: TaskPlacemark(from: mapItem.placemark)
                        )
                    }
                    self.searchResults = Array(locations)
                    print("Found \(locations.count) locations for query: \(query)")
                } else {
                    print("No mapItems found for query: \(query)")
                    self.searchResults = []
                }
            }
        }
    }
    
    private func formatAddress(from placemark: MKPlacemark) -> String? {
        var components: [String] = []
        
        if let thoroughfare = placemark.thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = placemark.locality {
            components.append(locality)
        }
        if let administrativeArea = placemark.administrativeArea {
            components.append(administrativeArea)
        }
        if let country = placemark.country {
            components.append(country)
        }
        
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
    
    func clearSearchResults() {
        searchTimer?.invalidate()
        currentSearchTask?.cancel()
        searchResults = []
        isSearching = false
    }
}