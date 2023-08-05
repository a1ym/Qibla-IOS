import SwiftUI
import MapKit

class SearchCompleter: NSObject, MKLocalSearchCompleterDelegate, ObservableObject {
    @Published var suggestions = [MKLocalSearchCompletion]()
    var completer: MKLocalSearchCompleter
    
    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        self.completer.delegate = self
    }
    
    func search(query: String) {
        self.completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.suggestions = completer.results
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Handle error
    }
}

struct ContentView: View {
    @State private var centerCoordinate = CLLocationCoordinate2D()
    @State private var location: MKPointAnnotation?
    @State private var polyline: MKGeodesicPolyline?
    @State private var mapType: MKMapType = .standard
    @State private var search: String = ""
    @State private var shouldUpdateCenterCoordinate: Bool = true
    @StateObject var searchCompleter = SearchCompleter()
    
    var body: some View {
        ZStack(alignment: .top) {
            MapView(centerCoordinate: $centerCoordinate, annotation: location, polyline: $polyline, mapType: $mapType, shouldUpdateCenterCoordinate: $shouldUpdateCenterCoordinate)
                .edgesIgnoringSafeArea(.all)
            
            Image(systemName: "scope")
                .imageScale(.large)
                .opacity(0.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .offset(x: 0, y: 0)
                .ignoresSafeArea(.keyboard)
            
            VStack {
                Spacer()
                HStack {
                    Button(action: {
                        let newLocation = MKPointAnnotation()
                        newLocation.coordinate = self.centerCoordinate
                        self.location = newLocation
                        
                        let destination = CLLocationCoordinate2DMake(21.42251, 39.82619)
                        let coordinates = [newLocation.coordinate, destination]
                        self.polyline = MKGeodesicPolyline(coordinates: coordinates, count: 2)
                        self.shouldUpdateCenterCoordinate = true
                    }) {
                        Text("Set Location")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(33)
                            .shadow(color: Color.black.opacity(0.7), radius: 10, x: 0, y: 5)
                    }
                    .padding()
                }
            }

            VStack {
                HStack {
                    TextField("Search", text: $search)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: search) { newValue in
                            searchCompleter.search(query: newValue)
                        }
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.15), radius: 40, x: 0, y: 5)

                    Button(action: {
                        mapType = mapType == .standard ? .satellite : .standard
                    }) {
                        Image(systemName: mapType == .standard ? "map" : "globe")
                            
                    }
                }
                
                .padding()
                .shadow(color: Color.black.opacity(0.6), radius: 5, x: 0, y: 0)
                
                
                if !search.isEmpty {
                    List {
                        ForEach(searchCompleter.suggestions, id: \.title) { suggestion in
                            Button(action: {
                                search = suggestion.title
                                let searchRequest = MKLocalSearch.Request(completion: suggestion)
                                let search = MKLocalSearch(request: searchRequest)
                                search.start { (response, error) in
                                    guard let response = response else { return }
                                    if let item = response.mapItems.first {
                                        self.location = MKPointAnnotation()
                                        self.location?.coordinate = item.placemark.coordinate
                                        self.centerCoordinate = item.placemark.coordinate
                                        self.shouldUpdateCenterCoordinate = true
                                    }
                                }
                                // Clear the search text field
                                self.search = ""
                            }) {
                                VStack(alignment: .leading) {
                                    Text(suggestion.title)
                                    Text(suggestion.subtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .cornerRadius(10)
                    .padding([.horizontal, .bottom])
                    .listStyle(PlainListStyle())
                    .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 5)
                }
            }
        }
    }
}


struct MapView: UIViewRepresentable {
    @Binding var centerCoordinate: CLLocationCoordinate2D
    var annotation: MKPointAnnotation?
    @Binding var polyline: MKGeodesicPolyline?
    @Binding var mapType: MKMapType
    @Binding var shouldUpdateCenterCoordinate: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        return mapView
    }
    
    func updateUIView(_ view: MKMapView, context: Context) {
        view.mapType = mapType
        view.removeAnnotations(view.annotations)
        view.removeOverlays(view.overlays)
        if let annotation = annotation {
            view.addAnnotation(annotation)
            if shouldUpdateCenterCoordinate {
                view.centerCoordinate = annotation.coordinate
                self.shouldUpdateCenterCoordinate = false
            }
        }
        if let polyline = polyline {
            view.addOverlay(polyline)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if overlay is MKPolyline {
                let renderer = MKPolylineRenderer(overlay: overlay)
                renderer.strokeColor = UIColor.blue
                renderer.lineWidth = 2
                return renderer
            } else {
                return MKOverlayRenderer()
            }
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.centerCoordinate = mapView.centerCoordinate
        }
    }
}
