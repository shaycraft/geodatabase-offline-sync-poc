//
//  ViewController.swift
//  GeodatabaseOfflineSyncPOC
//
//  Created by Samuel Haycraft on 3/29/23.
//

import UIKit
import ArcGIS

class ViewController: UIViewController {
    
    @IBOutlet weak var mapView: AGSMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self._setupMap()
        
    }
    
    private func _setupMap() -> Void {
        let map = AGSMap(
            basemapStyle: .arcGISTopographic
        )
        
        mapView.map = map
        
        mapView.setViewpoint(
            AGSViewpoint(
                latitude: 34.02700,
                longitude: -118.80500,
                scale: 72_000
            )
        )
    }
}

