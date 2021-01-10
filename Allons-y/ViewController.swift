//
//  ViewController.swift
//  Allons-y
//
//  Created by Courtney Langmeyer on 10/26/20.
//

import UIKit
import GoogleMaps
import GooglePlaces
import MapboxDirections
import MapboxCoreNavigation
import MapboxNavigation
import SwiftyJSON

class ViewController: UIViewController, GMSMapViewDelegate {
    var mapView = GMSMapView()

    let places = GMSPlacesClient()
    
    var currentLocation = CLLocation()
    var resultsViewController: GMSAutocompleteResultsViewController?
    var searchController: UISearchController?
    var resultView: UITextView?
    var viewModel: ViewModel
    
    init() {
        self.viewModel = ViewModel()
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aCoder: NSCoder) {
        self.viewModel = ViewModel()
        super.init(coder: aCoder)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        let location = viewModel.getCurrentLocation()
        let camera = GMSCameraPosition(target: location.coordinate, zoom: 12, bearing: 0, viewingAngle: 0)
        let mapID = GMSMapID(identifier: "20e1613fd0ec1ef")
        self.mapView = GMSMapView(frame: .zero, mapID: mapID, camera: camera)
        self.view = mapView

        self.mapView.isMyLocationEnabled = true
        self.mapView.settings.myLocationButton = true
        self.mapView.camera = camera
        self.mapView.delegate = self
        
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        self.viewModel.getOpenPlaces { places in
            print(places.count)
            for place in places {
                self.setUpMarkers(place: place)
            }
        }

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
    
    func mapView(_ mapView: GMSMapView, markerInfoWindow marker: GMSMarker) -> UIView? {
        
        guard let place = marker.userData as? Place else {
            return UIView()
        }
        
        let infoWindow = Bundle.main.loadNibNamed("InfoView", owner: self, options: nil)?.first as! InfoView
        
        infoWindow.place = place
        return infoWindow
    }
    
    private func setUpMarkers(place: Place) {
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: CLLocationDegrees(CGFloat(place.geometry.location.lat)), longitude: CLLocationDegrees(CGFloat(place.geometry.location.lng)))

        
        marker.userData = place
        marker.title = place.name
        marker.map = self.mapView
        marker.icon = UIImage(named: "star_icon")
        marker.appearAnimation = .pop
        
        
    }
    
    private func startNavigation(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) {
        // Define two waypoints to travel between
        let origin = Waypoint(coordinate: start, name: "Mapbox")
        let destination = Waypoint(coordinate: end, name: "White House")
         
        // ******************************** Save location to map every minute that can be viewed by friends!!!!!
        // 4 tabs -- map, share location settings and view history, friends tab where you can view history shared with you, and settings
        // Set options
        let routeOptions = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .walking)
         
        // Request a route using MapboxDirections.swift
        Directions().calculate(routeOptions) { [weak self] (session, result) in
        switch result {
        case .failure(let error):
        print(error.localizedDescription)
        case .success(let response):
        guard let route = response.routes?.first, let strongSelf = self else {
        return
        }
        // Pass the first generated route to the the NavigationViewController
        let viewController = NavigationViewController(for: route, routeIndex: 0, routeOptions: routeOptions)
            viewController.modalPresentationStyle = .overCurrentContext
        strongSelf.present(viewController, animated: true, completion: nil)
        }
        }
    }
    
    func drawMap (src: CLLocationCoordinate2D, dst: CLLocationCoordinate2D) -> [GMSPolyline] {
        var polylines = [GMSPolyline]()
        
        let url = URL(string: String(format:"https://maps.googleapis.com/maps/api/directions/json?origin=32.727344,-117.249805&destination=32.788941,-117.083627&mode=walking&key=AIzaSyDCoktDgwpRjzSpFCjwmFQDITGQLKgXQXM"))
        
        if let data = try? Data(contentsOf: url!) {
            if let json = try? JSON(data: data) {
                let routes = json["routes"].arrayValue
            
                for route in routes {
                    let routeOverviewPolyline = route["overview_polyline"].dictionary
                    let points = routeOverviewPolyline?["points"]?.stringValue
                    let path = GMSPath.init(fromEncodedPath: points!)
                    let polyline = GMSPolyline(path: path)
                    polyline.strokeWidth = 6
                    polyline.strokeColor =  .white
                    
                    polyline.map = self.mapView
                    polylines.append(polyline)
                }
                return polylines
            }
        }
        return polylines
    }
}

// Handle the user's selection.
extension ViewController: GMSAutocompleteResultsViewControllerDelegate {
  func resultsController(_ resultsController: GMSAutocompleteResultsViewController,
                         didAutocompleteWith place: GMSPlace) {
    searchController?.isActive = false
    // Do something with the selected place.
    
    self.currentLocation = self.viewModel.getCurrentLocation()
    print("Place name: \(String(describing: place.name))")

    print("Place address: \(String(describing: place.formattedAddress))")
    
    
    let northEast = self.currentLocation.coordinate

    let southWest = place.coordinate
    
    let marker = GMSMarker()
    marker.position = place.coordinate

    marker.title = place.name
    marker.map = self.mapView
    marker.icon = UIImage(named: "star")

    let bounds = GMSCoordinateBounds(coordinate: northEast, coordinate: southWest)
    let update = GMSCameraUpdate.fit(bounds, withPadding: 50.0)
    mapView.moveCamera(update)
    
    self.drawMap(src: self.currentLocation.coordinate, dst: place.coordinate)
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
        self.startNavigation(start: self.currentLocation.coordinate, end: place.coordinate)
    }
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

protocol InfoViewDelegate {
    func addStopTapped(coordinate: Location )
}

class InfoView: UIView {
    @IBOutlet private weak var button: UIButton!
    
    @IBOutlet weak var placeName: UILabel!
    @IBOutlet weak var placeTypes: UILabel!
    @IBOutlet weak var placeDistance: UILabel!
    
    @IBAction func addStopTapped(_ sender: Any) {
        print(place?.geometry.location)
    }
    
    var place: Place? {
        didSet {
            self.configure()
        }
    }

    init() {
        super.init(frame: .zero)
    }
    
    func configure() {
        guard let place = self.place else {
            return
        }
        self.placeName.text = place.name
        var types = ""
        for type in place.types {
            types += type
        }
        self.placeTypes.text = types
        self.placeDistance.text = "3.1 miles away"
    }
    
    required init?(coder aCoder: NSCoder) {
        super.init(coder: aCoder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.layer.cornerRadius = 20
        self.layer.borderWidth = 2
        self.layer.borderColor = UIColor.white.cgColor
        
        self.button.layer.cornerRadius = 10
        self.button.layer.borderWidth = 2
        self.button.layer.borderColor = UIColor.white.cgColor
    }
}

extension UIView {
    private static let kRotationAnimationKey = "rotationanimationkey"

    func rotate(duration: Double = 1) {
        if layer.animation(forKey: UIView.kRotationAnimationKey) == nil {
            let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation")

            rotationAnimation.fromValue = 0.0
            rotationAnimation.toValue = Float.pi * 2.0
            rotationAnimation.duration = duration
            rotationAnimation.repeatCount = Float.infinity

            layer.add(rotationAnimation, forKey: UIView.kRotationAnimationKey)
        }
    }

    func stopRotating() {
        if layer.animation(forKey: UIView.kRotationAnimationKey) != nil {
            layer.removeAnimation(forKey: UIView.kRotationAnimationKey)
        }
    }
}
