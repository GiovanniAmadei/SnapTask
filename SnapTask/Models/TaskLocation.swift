import Foundation
import CoreLocation
import MapKit

struct TaskLocation: Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var address: String?
    var coordinate: CLLocationCoordinate2D?
    var placemark: TaskPlacemark?
    
    init(id: UUID = UUID(), name: String, address: String? = nil, coordinate: CLLocationCoordinate2D? = nil, placemark: TaskPlacemark? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.coordinate = coordinate
        self.placemark = placemark
    }
    
    var displayName: String {
        if let address = address, !address.isEmpty {
            return "\(name) - \(address)"
        }
        return name
    }
    
    var shortDisplayName: String {
        return name
    }
}

struct TaskPlacemark: Codable, Equatable, Hashable {
    let name: String?
    let thoroughfare: String?
    let locality: String?
    let administrativeArea: String?
    let country: String?
    let postalCode: String?
    
    init(from placemark: CLPlacemark) {
        self.name = placemark.name
        self.thoroughfare = placemark.thoroughfare
        self.locality = placemark.locality
        self.administrativeArea = placemark.administrativeArea
        self.country = placemark.country
        self.postalCode = placemark.postalCode
    }
    
    var formattedAddress: String {
        var components: [String] = []
        
        if let thoroughfare = thoroughfare {
            components.append(thoroughfare)
        }
        if let locality = locality {
            components.append(locality)
        }
        if let administrativeArea = administrativeArea {
            components.append(administrativeArea)
        }
        
        return components.joined(separator: ", ")
    }
}

// Extension to make CLLocationCoordinate2D Codable
extension CLLocationCoordinate2D: Codable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(latitude, forKey: .latitude)
        try container.encode(longitude, forKey: .longitude)
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        self.init(latitude: latitude, longitude: longitude)
    }
    
    private enum CodingKeys: String, CodingKey {
        case latitude, longitude
    }
}

extension CLLocationCoordinate2D: Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

extension CLLocationCoordinate2D: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }
}