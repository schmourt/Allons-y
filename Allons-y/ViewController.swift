//
//  ViewController.swift
//  Allons-y
//
//  Created by Courtney Langmeyer on 10/26/20.
//

import UIKit
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
}

struct Location: Decodable {
    let lat, lng: Float
}

class ViewController: UIViewController {
    var mapView = GMSMapView()
    private var locationManager = CLLocationManager()
    let places = GMSPlacesClient()
    
    var resultsViewController: GMSAutocompleteResultsViewController?
    var searchController: UISearchController?
    var resultView: UITextView?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
        
        resultsViewController = GMSAutocompleteResultsViewController()
        resultsViewController?.delegate = self

        searchController = UISearchController(searchResultsController: resultsViewController)
        searchController?.searchResultsUpdater = resultsViewController

        // Put the search bar in the navigation bar.
        searchController?.searchBar.sizeToFit()
        navigationItem.titleView = searchController?.searchBar

        // When UISearchController presents the results view, present it in
        // this view controller, not one further up the chain.
        definesPresentationContext = true

        // Prevent the navigation bar from being hidden when searching.
        searchController?.hidesNavigationBarDuringPresentation = false
    }

 }

extension ViewController: CLLocationManagerDelegate {
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



        let camera = GMSCameraPosition(target: location.coordinate, zoom: 16, bearing: 0, viewingAngle: 0)
        let mapID = GMSMapID(identifier: "20e1613fd0ec1ef")
        self.mapView = GMSMapView(frame: .zero, mapID: mapID, camera: camera)
        self.view = mapView

        mapView.isMyLocationEnabled = true
        mapView.settings.myLocationButton = true
    
        mapView.camera = camera
        let urlString = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?location=\(location.coordinate.latitude),\(location.coordinate.longitude)&radius=4200&opennow=true&key=AIzaSyDCoktDgwpRjzSpFCjwmFQDITGQLKgXQXM"
        
        print(urlString)
        if let url = URL(string: urlString) {
            if let data = try? Data(contentsOf: url) {
                //parse(json: data)
            }
        }
        locationManager.stopUpdatingLocation()
    }
   private func parse(json: Data) -> String? {
        let decoder = JSONDecoder()
        var places = [Place]()

        if let JSONPlaces = try? decoder.decode(Places.self, from: json) {
           places = JSONPlaces.results
            for place in places {
                print(places.count)
                setUpMarkers(place: place)
                print("Name: \(place.name) Vicinity: \(place.vicinity) Places: \(place.types) Coordinates: \(place.geometry.location.lat) and \(place.geometry.location.lng)")
    
                if !(place.next_page_token?.isEmpty ?? true) {
                    return place.next_page_token
                }
            }
        }
        return ""
    }
    
    private func setUpMarkers(place: Place) {
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: CLLocationDegrees(CGFloat(place.geometry.location.lat)), longitude: CLLocationDegrees(CGFloat(place.geometry.location.lng)))

        marker.title = place.name
        marker.map = self.mapView
        marker.icon = UIImage(named: "star")
    }
}

// Handle the user's selection.
extension ViewController: GMSAutocompleteResultsViewControllerDelegate {
  func resultsController(_ resultsController: GMSAutocompleteResultsViewController,
                         didAutocompleteWith place: GMSPlace) {
    searchController?.isActive = false
    // Do something with the selected place.
    print("Place name: \(String(describing: place.name))")
    place.coordinate.latitude
    print("Place address: \(String(describing: place.formattedAddress))")
    //print("Place attributions: \(place.attributions ?? <#default value#>)")
  }

  func resultsController(_ resultsController: GMSAutocompleteResultsViewController,
                         didFailAutocompleteWithError error: Error){
    // TODO: handle the error.
    print("Error: ", error.localizedDescription)
  }

  // Turn the network activity indicator on and off again.
  func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = true
  }

  func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
    UIApplication.shared.isNetworkActivityIndicatorVisible = false
  }
}

