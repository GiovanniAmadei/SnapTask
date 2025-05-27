import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Binding var selectedLocation: TaskLocation?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = LocationPickerViewModel()
    @State private var searchText = ""
    @State private var showingMapPicker = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick Actions
                VStack(spacing: 12) {
                    // Current Location Button
                    Button(action: {
                        viewModel.useCurrentLocation()
                    }) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)
                            Text("Use Current Location")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            if viewModel.isLoadingCurrentLocation {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.blue.opacity(0.1))
                        )
                    }
                    .disabled(viewModel.isLoadingCurrentLocation)
                    
                    // Map Picker Button
                    Button(action: {
                        showingMapPicker = true
                    }) {
                        HStack {
                            Image(systemName: "map")
                                .foregroundColor(.green)
                            Text("Pick from Map")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                }
                .padding()
                
                Divider()
                
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
            .sheet(isPresented: $showingMapPicker) {
                MapPickerView(selectedLocation: $selectedLocation)
            }
            .onChange(of: searchText) { _, newValue in
                if !newValue.isEmpty {
                    viewModel.searchLocations(query: newValue)
                }
            }
            .onReceive(viewModel.$currentLocation) { location in
                if let location = location {
                    selectedLocation = location
                    dismiss()
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
    @Published var currentLocation: TaskLocation?
    @Published var isLoadingCurrentLocation = false
    
    private var locationManager = CLLocationManager()
    private var searchCompleter = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        setupLocationManager()
        setupSearchCompleter()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    private func setupSearchCompleter() {
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }
    
    func useCurrentLocation() {
        isLoadingCurrentLocation = true
        
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            // Handle denied permission
            isLoadingCurrentLocation = false
        @unknown default:
            isLoadingCurrentLocation = false
        }
    }
    
    func searchLocations(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        searchCompleter.queryFragment = query
    }
    
    func clearSearchResults() {
        searchResults = []
        searchCompleter.queryFragment = ""
    }
}

extension LocationPickerViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            isLoadingCurrentLocation = false
            return
        }
        
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isLoadingCurrentLocation = false
                
                if let placemark = placemarks?.first {
                    let taskLocation = TaskLocation(
                        name: placemark.name ?? "Current Location",
                        address: TaskPlacemark(from: placemark).formattedAddress,
                        coordinate: location.coordinate,
                        placemark: TaskPlacemark(from: placemark)
                    )
                    self?.currentLocation = taskLocation
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoadingCurrentLocation = false
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            if isLoadingCurrentLocation {
                manager.requestLocation()
            }
        } else if manager.authorizationStatus == .denied {
            isLoadingCurrentLocation = false
        }
    }
}

extension LocationPickerViewModel: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.map { completion in
            TaskLocation(
                name: completion.title,
                address: completion.subtitle.isEmpty ? nil : completion.subtitle
            )
        }
        
        DispatchQueue.main.async {
            self.searchResults = results
            self.isSearching = false
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isSearching = false
        }
    }
}