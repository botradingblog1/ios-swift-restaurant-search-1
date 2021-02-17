//
//  ViewController.swift
//  ios-swift-restaurant-search-1
//
//  Created by Chris Scheid on 2/15/21.
//

import GooglePlaces
import UIKit
import MapKit

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, CLLocationManagerDelegate {
    private var placesClient: GMSPlacesClient!
    private var resultsViewController: GMSAutocompleteResultsViewController?
    private var searchController: UISearchController?
    private var fetcher: GMSAutocompleteFetcher?
    private var searchPredictions = [GMSAutocompletePrediction]()
    private var selectedPlace: CLLocation?
    private var locationManager: CLLocationManager?
    private var permissionGranted = false
    private var initialLocationSet = false
    private let cellIdentifier = "autocompleteCell"

    
    private func createAutocompleteFetcher() -> GMSAutocompleteFetcher {
        let filter = GMSAutocompleteFilter()
            filter.type = .establishment
            filter.country = "US"
        
        fetcher = GMSAutocompleteFetcher(filter: filter);
        fetcher?.delegate = self
        
        return fetcher!
    }
    
    override func viewDidLoad() {
      super.viewDidLoad()
        
        // Initialize Google Places client
        placesClient = GMSPlacesClient.shared()
        
        // Initialize Autocomplete Fetcher
        fetcher = createAutocompleteFetcher()
        
        searchController = UISearchController(searchResultsController: nil)
        searchController?.searchResultsUpdater = self
        
        searchBarView.addSubview((searchController?.searchBar)!)
        searchController?.searchBar.sizeToFit()
        searchController?.searchBar.delegate = self

        // Add search bar to the navigation bar.
        searchController?.searchBar.sizeToFit()
        navigationItem.titleView = searchController?.searchBar

        // When UISearchController presents the results view, present it in
        // this view controller, not one further up the chain.
        definesPresentationContext = true

        // Prevent the navigation bar from being hidden when searching.
        searchController?.hidesNavigationBarDuringPresentation = false
        
        // Set up tableview
        tableView.separatorStyle = .none
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellIdentifier)
        tableView.isHidden = true
        tableView.delegate = self
        tableView.dataSource = self
        
        // Set up Location manager
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        
        // Request location tracking permission
        locationManager?.requestAlwaysAuthorization()
    }
    
    // MARK: Places functions
    private func fetchPlaceDetails(placeID: String) {
        let placesClient = GMSPlacesClient.shared()
        placesClient.lookUpPlaceID((placeID)) { [unowned self] (place, error) in
            if (error == nil) {
                self.selectedPlace = CLLocation.init(latitude: (place?.coordinate.latitude)!, longitude: (place?.coordinate.longitude)!)
                
                self.tableView.isHidden = true
                self.searchController?.dismiss(animated: true, completion: { [unowned self] in
                    //self.delegate?.sendPickedLocation(pickedLocation: self.pickedLocation!, pickedLocationDescription: self.pickedLocationDescription!)
                })
                
                guard let place = place else {
                    return
                }
                
                // Create a marker for this place
                createMapMarker(place: place)
                
            } else {
                print(error.debugDescription)
            }
        }
    }
    
    // MARK: Autocomplete table implementation
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchPredictions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        var cell: UITableViewCell! = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath)

        if cell == nil {
            cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier)
        }
        
        let row = indexPath.row
        
        cell.textLabel?.attributedText = searchPredictions[row].attributedPrimaryText;
        cell.detailTextLabel?.attributedText = searchPredictions[row].attributedSecondaryText;

        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = indexPath.row
        let prediction: GMSAutocompletePrediction?
        prediction = searchPredictions[row]
    
        guard let placeID = prediction?.placeID else {
            return
        }
        
        fetchPlaceDetails(placeID: placeID)
    }
    
    // MARK: Utilities
    func showAlert(_ message: String, title: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    // Stop location updates
    override func viewWillAppear(_ animated: Bool) {
        if (permissionGranted) {
            locationManager?.startUpdatingLocation()
        }
    }
    
    // Stop location updates
    override func viewWillDisappear(_ animated: Bool) {
        locationManager?.stopUpdatingLocation()
    }
    
    // MARK: Location manager delegate implementation
    // Callback from location permission authorization
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            permissionGranted = true
            
            // Start location updates
            locationManager?.startUpdatingLocation()
        }
    }

    // Callback for location updates
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            print("New location is \(location)")
            
            // Move map to current permission
            if (!initialLocationSet) {
                initialLocationSet =  true
                moveMap(coordinate: location.coordinate)
            }
        }
    }
    
    // MARK: Map function implementation
    private func moveMap(coordinate: CLLocationCoordinate2D) {
        let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        mapView.setRegion(region, animated: true)
    }
    
    func createMapMarker(place: GMSPlace) {
        mapView.removeAnnotations(mapView.annotations)

        // Move the map to place
        moveMap(coordinate: place.coordinate)

        // Create annotation
        let annotation = MKPointAnnotation()
        annotation.coordinate = place.coordinate
        annotation.title = place.name
        annotation.subtitle = place.formattedAddress
        mapView.addAnnotation(annotation)
    }
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var searchBarView: UIView!
    @IBOutlet weak var mapView: MKMapView!
}


// MARK: GMSAutocompleteFetcherDelegate implementation
 extension ViewController: GMSAutocompleteFetcherDelegate {
     func didAutocomplete(with predictions: [GMSAutocompletePrediction]) {
        // Show table view
        self.tableView.isHidden = false
        
        // Filter all restaurants
        var restaurants: [GMSAutocompletePrediction] =  []
        for prediction in predictions {
            if prediction.types.contains("restaurant") {
                restaurants.append(prediction)
            }
        }
        searchPredictions = restaurants
         
         self.tableView.reloadData()
     }
     
     func didFailAutocompleteWithError(_ error: Error) {
        print(error.localizedDescription)
        showAlert("Autocomplete fetch failed", title: "Error")
     }
     
 }

// MARK: SearchBar delegates
 extension ViewController: UISearchResultsUpdating, UISearchBarDelegate {
     func updateSearchResults(for searchController: UISearchController) {
     }

     func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
     }
     
     func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Start search when 3 characters or more are typed
        if (searchBar.text!.count >= 3) {
            fetcher?.sourceTextHasChanged(searchBar.text!)
        }
     }
     
     func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.dismiss(animated: true)
        self.tableView.isHidden = true
     }
 }
