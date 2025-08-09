import SwiftUI
import MapKit

struct LocationMapView: View {
    let location: TaskLocation
    let height: CGFloat
    let showsUserLocation: Bool
    let allowsInteraction: Bool
    
    @State private var region: MKCoordinateRegion
    @State private var geocodedCoordinate: CLLocationCoordinate2D?
    @State private var isGeocoding = false
    
    init(location: TaskLocation, height: CGFloat = 150, showsUserLocation: Bool = false, allowsInteraction: Bool = true) {
        self.location = location
        self.height = height
        self.showsUserLocation = showsUserLocation
        self.allowsInteraction = allowsInteraction
        
        if let coordinate = location.coordinate {
            self._region = State(initialValue: MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            self._region = State(initialValue: MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        }
    }
    
    private var displayCoordinate: CLLocationCoordinate2D? {
        return location.coordinate ?? geocodedCoordinate
    }
    
    // A stable key to detect coordinate changes for live updates
    private var coordinateKey: String {
        if let c = displayCoordinate {
            return String(format: "%.6f,%.6f", c.latitude, c.longitude)
        }
        // include name/address so geocode triggers when only textual data changes
        return "none::\(location.name)::\(location.address ?? "")"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coordinate = displayCoordinate {
                Map(coordinateRegion: $region, 
                    showsUserLocation: showsUserLocation,
                    annotationItems: [location]) { location in
                    MapMarker(coordinate: coordinate, tint: .pink)
                }
                .frame(height: height)
                .cornerRadius(12)
                .disabled(!allowsInteraction)
                .onAppear {
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
                .id(coordinateKey)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(height: height)
                    
                    if isGeocoding {
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading map...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "location.slash")
                                .font(.system(size: 24))
                                .foregroundColor(.secondary)
                            Text("No coordinates available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onAppear {
                    if location.coordinate == nil && !isGeocoding {
                        geocodeLocation()
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(location.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let address = location.address, !address.isEmpty {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.top, 8)
        }
        // Live update region/geocoding when the underlying coordinate or textual address changes
        .onChange(of: coordinateKey) { _ in
            if let c = displayCoordinate {
                region = MKCoordinateRegion(
                    center: c,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            } else if !isGeocoding {
                geocodeLocation()
            }
        }
    }
    
    private func geocodeLocation() {
        isGeocoding = true
        let geocoder = CLGeocoder()
        let searchString = location.address?.isEmpty == false ? 
            "\(location.name), \(location.address!)" : location.name
        
        geocoder.geocodeAddressString(searchString) { placemarks, error in
            DispatchQueue.main.async {
                isGeocoding = false
                if let placemark = placemarks?.first,
                   let coordinate = placemark.location?.coordinate {
                    geocodedCoordinate = coordinate
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }
        }
    }
}
