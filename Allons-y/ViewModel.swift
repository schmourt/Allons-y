//
//  ViewModel.swift
//  Allons-y
//
//  Created by Courtney Langmeyer on 11/29/20.
//

import Foundation
import CoreLocation
import GoogleMaps
import GooglePlaces

struct Place: Decodable {
    let name: String
    let vicinity: String
    let types: [String]
    let geometry: Geometry
    let next_page_token: String?
}

struct Geometry: Decodable {
    let location: Location
}

struct Places: Decodable {
    let results: [Place]
    let next_page_token: String?
}

struct Location: Decodable {
    let lat, lng: Float
}

class ViewModel: NSObject {
    
    private var locationManager = CLLocationManager()
    private var currentLocation = CLLocation()
    private var openPlaces = [Place]()
    private var hasNextPageToken = true
    
    override init() {
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        locationManager.requestWhenInUseAuthorization()
    }
    
    internal func getCurrentLocation() -> CLLocation {
        return self.currentLocation
    }
    
    internal func getOpenPlaces(completion: @escaping ([Place]) -> Void) {
        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(self.currentLocation.coordinate.latitude),\(self.currentLocation.coordinate.longitude)&radius=4200&opennow=true&key=AIzaSyDCoktDgwpRjzSpFCjwmFQDITGQLKgXQXM"
        
        if let url = URL(string: urlString) {
            print(urlString)
            if let token = parseURL(url: url) {
                if token != "" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        print("big one", url.appendingPathComponent("&token=\(token)"))
                        if let anotherToken = self.parseURL(url: url.appendingPathComponent("&token=\(token)")) {
                            print(">>>>>>")
                            if anotherToken != "" {
                                if self.parseURL(url: url.appendingPathComponent("&token=\(anotherToken)")) != nil {
                                    completion(self.openPlaces)
                                }
                            }
                        }
                        completion(self.openPlaces)
                    }
                }
            }
        }
    }
    
    private func parseURL(url: URL) -> String? {
        if let data = try? Data(contentsOf: url) {
            let decoder = JSONDecoder()

            if let JSONPlaces = try? decoder.decode(Places.self, from: data) {
                for place in JSONPlaces.results {
                   self.openPlaces.append(place)
                    print("Name: \(place.name) Vicinity: \(place.vicinity) Places: \(place.types) Coordinates: \(place.geometry.location.lat) and \(place.geometry.location.lng)")
                }
                if let token = JSONPlaces.next_page_token {
                    return token
                }
            }
        }
        return ""
    }
}

extension ViewModel: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        guard status == .authorizedWhenInUse else {
            return
        }
        locationManager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            /// DISCONNECTED STATE
            return
        }
        
        self.currentLocation = location
    }
}
