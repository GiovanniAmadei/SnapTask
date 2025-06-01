import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var selectedLocation: TaskLocation?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LocationPickerViewModel()
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Search Location")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search for a place...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                viewModel.searchLocations(query: searchText)
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                                viewModel.clearSearchResults()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.1))
                    )
                    .padding(.horizontal)
                    
                    // Search Results
                    if viewModel.isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    } else if !viewModel.searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.searchResults, id: \.id) { location in
                                    LocationResultRow(location: location) {
                                        selectedLocation = location
                                        dismiss()
                                    }
                                }
                                
                                if let selectedLoc = selectedLocation {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Selected Location")
                                            .font(.headline)
                                            .padding(.horizontal)
                                        
                                        LocationMapView(location: selectedLoc, height: 120, allowsInteraction: false)
                                            .padding(.horizontal)
                                    }
                                    .padding(.top, 16)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else if !searchText.isEmpty && !viewModel.isSearching {
                        Text("No results found")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                }
                
                Spacer()
                
                // Clear Location Button
                if selectedLocation != nil {
                    Button(action: {
                        selectedLocation = nil
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Location")
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
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
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
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let address = location.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
