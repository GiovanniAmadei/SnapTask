import SwiftUI
import MapKit

struct MapPickerView: View {
    @Binding var selectedLocation: TaskLocation?
    @Environment(\.dismiss) private var dismiss
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isLoading = false
    @State private var locationName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(coordinateRegion: $region, interactionModes: .all, annotationItems: selectedCoordinate.map { [MapAnnotation(coordinate: $0)] } ?? []) { annotation in
                    MapPin(coordinate: annotation.coordinate, tint: .pink)
                }
                .onTapGesture { location in
                    let coordinate = region.center
                    selectedCoordinate = coordinate
                    reverseGeocode(coordinate: coordinate)
                }
                
                // Crosshair overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.pink)
                            .background(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 30, height: 30)
                            )
                        Spacer()
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
                
                // Loading overlay
                if isLoading {
                    VStack {
                        ProgressView()
                        Text("getting_location_info".localized)
                            .font(.caption)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.regularMaterial)
                    )
                }
                
                // Location info card
                if let coordinate = selectedCoordinate, !locationName.isEmpty {
                    VStack {
                        Spacer()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("selected_location".localized)
                                .font(.headline)
                            
                            Text(locationName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("cancel".localized) {
                                    selectedCoordinate = nil
                                    locationName = ""
                                }
                                .font(.headline)
                                .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("select".localized) {
                                    let location = TaskLocation(
                                        name: locationName,
                                        coordinate: coordinate
                                    )
                                    selectedLocation = location
                                    dismiss()
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(.pink)
                                )
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.regularMaterial)
                        )
                        .padding()
                    }
                }
            }
            .navigationTitle("pick_location".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("current".localized) {
                        getCurrentLocation()
                    }
                }
            }
            .onAppear {
                getCurrentLocation()
            }
        }
    }
    
    private func getCurrentLocation() {
        let locationManager = CLLocationManager()
        locationManager.requestWhenInUseAuthorization()
        
        if let currentLocation = locationManager.location {
            region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        isLoading = true
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let placemark = placemarks?.first {
                    locationName = placemark.name ?? placemark.thoroughfare ?? "selected_location".localized
                } else {
                    locationName = "selected_location".localized
                }
            }
        }
    }
}

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}