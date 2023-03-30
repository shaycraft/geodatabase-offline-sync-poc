//
//  ViewController.swift
//  GeodatabaseOfflineSyncPOC
//
//  Created by Samuel Haycraft on 3/29/23.
//

import UIKit
import ArcGIS

// enums
enum ViewpointSelector {
    case DENVER
    case CALIFORNIA
    case SAN_FRANCISCO
}

class ViewController: UIViewController {
    // public variables
    @IBOutlet weak var mapView: AGSMapView!
    
    // private variables
    private var geodatabaseSyncTask: AGSGeodatabaseSyncTask = {
        let url = "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Sync/WildfireSync/FeatureServer"
        let featureServiceURL = URL(string: url)!
        return AGSGeodatabaseSyncTask(url: featureServiceURL)
    }()
    private var _downloadDirectory: URL?
    
    // overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        // self._setupMapStatic()
        self._setupMapGeodatabaseSync()
        
    }
    
    // private functions
    private func _setupMapGeodatabaseSync() -> Void {
        let map = AGSMap(basemapStyle: .osmStreetsReliefBase)
        
        self.mapView.map = map
        
        self.geodatabaseSyncTask.load{[weak self] (error) in
            print("Load completed...")
            if let error = error {
                self?._printError(message: "Error occurred during initial map load...")
                print(error.localizedDescription)
                
                return
            }
            
            guard let self = self,
                  let featureServiceInfo = self.geodatabaseSyncTask.featureServiceInfo else { return }
            
            let featureLayers = featureServiceInfo.layerInfos.enumerated().map{(offset, layerInfo) -> AGSFeatureLayer in
                print("DEBUG: adding layer \(layerInfo.name)")
                let layerURL = self.geodatabaseSyncTask.url!.appendingPathComponent(String(offset))
                let featureTable = AGSServiceFeatureTable(url: layerURL)
                let featureLayer = AGSFeatureLayer(featureTable: featureTable)
                featureLayer.name = layerInfo.name
                return featureLayer
            }
            
            // Don't know why they call `reverse` here (I took this from the ESRI example, but assumign just `from: featureLayers` is okay?
            self.mapView!.map?.operationalLayers.addObjects(from: featureLayers.reversed())
            
            self.mapView!.setViewpoint(self._getViewpoint(location: .SAN_FRANCISCO))
            
        }
    }
    
    private func _setupMapStatic() -> Void {
        let map = AGSMap(
            basemapStyle: .arcGISTopographic
        )
        
        self.mapView.map = map
        
        
        self.mapView!.setViewpoint(self._getViewpoint(location: .CALIFORNIA))
    }
    
    private func _createDownloadDirectory() -> Void {
        
    }
    
    private func _printError(message: String) -> Void {
        print(">>>>>>> ERROR: \(message) <<<<<<<")
        
    }
    
    private func _getViewpoint(location: ViewpointSelector) -> AGSViewpoint {
        switch location {
        case ViewpointSelector.CALIFORNIA:
            return AGSViewpoint(
                latitude: 34.02700,
                longitude: -118.80500,
                scale: 72_000
            )
        case ViewpointSelector.DENVER:
            return AGSViewpoint(
                latitude: 39.731243,
                longitude: -104.968526,
                scale: 20_000
            )
        case ViewpointSelector.SAN_FRANCISCO:
            return AGSViewpoint(
                latitude: 37.807606,
                longitude: -122.475711,
                scale: 250_000
            )
        }
    }
    
}

