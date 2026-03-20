import CoreLocation

enum AppConstants {
    static let vancouverCenter = CLLocationCoordinate2D(latitude: 49.2827, longitude: -123.1207)
    static let vancouverSpan = CLLocationCoordinate2D(latitude: 49.4100, longitude: -122.9000)
    static let vancouverLatitudeRange = 49.10 ... 49.41
    static let vancouverLongitudeRange = -123.30 ... -122.90
    static let defaultBubbleZoom = 12.8
}
