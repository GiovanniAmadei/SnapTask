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
                        Text("Getting location info...")
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
                            Text("Selected Location")
                                .font(.headline)
                            
                            Text(locationName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack {
                                Button("Cancel") {
                                    selectedCoordinate = nil
                                    locationName = ""
                                }
                                .font(.headline)
                                .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Select") {
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
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Current") {
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
                    locationName = placemark.name ?? placemark.thoroughfare ?? "Selected Location"
                } else {
                    locationName = "Selected Location"
                }
            }
        }
    }
}

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}