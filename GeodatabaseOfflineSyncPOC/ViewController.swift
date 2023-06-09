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
        // let url = "https://sampleserver6.arcgisonline.com/arcgis/rest/services/Sync/WildfireSync/FeatureServer"
        // ec2 / nginx
        let url = "https://ec2-54-149-175-248.us-west-2.compute.amazonaws.com/arcgis/rest/services/Sync/WildfireSync/FeatureServer"
        // let url = "https://services.arcgis.com/QdDMhZcUq2kGBzOx/arcgis/rest/services/tl_rd22_08049_roads/FeatureServer"
        // let url = "https://l9thfcs5hj.execute-api.us-west-2.amazonaws.com/arcgis/rest/services/Sync/WildfireSync/FeatureServer"
        // let url = "https://fjk1l1iw9b.execute-api.us-east-2.amazonaws.com/arcgis/rest/services/GFEE/Gas_Distribution/FeatureServer"
        // let url = "https://lzhu34j6ie.execute-api.us-east-2.amazonaws.com/arcgis/rest/services/GFEE/Gas_Distribution/FeatureServer"
        let featureServiceURL = URL(string: url)!
        return AGSGeodatabaseSyncTask(url: featureServiceURL)
    }()
    private var _activeJob: AGSJob?
    private var _downloadDirectory: URL?
    private var _generatedGeodatabase: AGSGeodatabase?
    
    // overrides
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        AGSAuthenticationManager.shared().delegate = self
        // self._setupMapStatic()
        
        do {
            try self._downloadDirectory = self._createDownloadDirectory()
        } catch {
            self._printError(message: "Error creating download directory...")
            print(error.localizedDescription)
        }
        
        print(String(describing: self._downloadDirectory))
        self._setupMapGeodatabaseSync()
        
    }
    
    // private functions
    
    private func _displayLayersFromGeodatabase() -> Void {
        guard let generatedGeoDatabase = self._generatedGeodatabase else { return }
        
        generatedGeoDatabase.load{ [weak self] (error: Error?) in
            guard let self = self else { return }
            
            if let error = error {
                self._printError(message: "Error in loading downloading geodatabase...")
                print(error.localizedDescription)
            } else {
                self.mapView.map?.operationalLayers.removeAllObjects()
                
                AGSLoadObjects(generatedGeoDatabase.geodatabaseFeatureTables) { (success: Bool) in
                    if (success) {
                        print("Offline tables loaded")
                        
                        for featureTable in generatedGeoDatabase.geodatabaseFeatureTables.reversed() {
                            if featureTable.hasGeometry {
                                let featureLayer = AGSFeatureLayer(featureTable: featureTable)
                                self.mapView.map?.operationalLayers.add(featureLayer)
                            }
                        }
                    }
                    print("now showing from geodatabase")
                }
            }
        }
    }
    
    private func _initiateSync() -> Void {
        guard let currentExtent = self._frameToExtent() else {
            self._printError(message: "Current extent null")
            return
        }
        print(String(describing: currentExtent))
        
        self.geodatabaseSyncTask.defaultGenerateGeodatabaseParameters(withExtent: currentExtent) { [weak self] (params: AGSGenerateGeodatabaseParameters?, error: Error?) in
            if let params = params,
               let self = self {
                params.returnAttachments = false
                
                let dateFormatter = ISO8601DateFormatter()
                
                let downloadFileURL = self._downloadDirectory!.appendingPathComponent(dateFormatter.string(from: Date()))
                    .appendingPathExtension("geodatabase")
                print("Downloading to ... \(downloadFileURL.path)")
                
                let generateJob = self.geodatabaseSyncTask.generateJob(with: params, downloadFileURL: downloadFileURL)
                self._activeJob = generateJob
                
                generateJob.start(
                    statusHandler: { (status: AGSJobStatus) in
                        print("Geo sync status is \(status.rawValue)")
                        print(generateJob.progress.localizedDescription!)
                    },
                    completion: { [weak self] (geodatabase: AGSGeodatabase?, error: Error?) in
                        
                        if let error = error {
                            self?._printError(message: "Error occurred in sync geodatabase operation...")
                            print(error.localizedDescription)
                            print(error)
                        } else {
                            self?._generatedGeodatabase = geodatabase
                            print("Download complete!!!!!!!!!")
                            
                            self!._displayLayersFromGeodatabase()
                        }
                        
                        self?._activeJob = nil
                    }
                )
                
                //                generateJob.start { AGSJobStatus in
                //                    <#code#>
                //                } completion: { <#AGSGeodatabase?#>, <#Error?#> in
                //                    <#code#>
                //                }
                
                
                
            } else {
                self?._printError(message: "Problem occurred in default generate parameters, error = \(error!)")
            }
        }
    }
    
    private func _frameToExtent() -> AGSGeometry? {
        return self.mapView.visibleArea
        // return self.mapView.currentViewpoint(with: .boundingGeometry)?.targetGeometry
    }
    
    
    private func _setupMapGeodatabaseSync() -> Void {
        let map = AGSMap(basemapStyle: .arcGISTopographic)
        
        self.mapView.map = map
        
        self.mapView.map!.load{ (error) in
            self.geodatabaseSyncTask.load{[weak self] (error) in
                print("Load completed...")
                if let error = error {
                    self?._printError(message: "Error occurred during initial map load...")
                    print(error.localizedDescription)
                    
                    return
                }
                
                guard let self = self,
                      let featureServiceInfo = self.geodatabaseSyncTask.featureServiceInfo else { return }
                
                self.mapView!.setViewpoint(self._getViewpoint(location: .SAN_FRANCISCO))
                
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
                
                print("About to initiate...")
                print(self.mapView.map!.loadStatus.rawValue)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
                    print("Queue fired")
                    self._initiateSync()
                }
            }
        }
        
        
    }
    
    private func _setupMapStatic() -> Void {
        let map = AGSMap(
            basemapStyle: .arcGISTopographic
        )
        
        self.mapView.map = map
        
        self.mapView!.setViewpoint(self._getViewpoint(location: .SAN_FRANCISCO))
    }
    
    private func _createDownloadDirectory() throws -> URL? {
        let defaultManager = FileManager.default
        let temporaryDownloadURL = defaultManager.temporaryDirectory.appendingPathComponent("TEMP_DOWNLOAD_GEODATABASE_SYNC")
        
        if defaultManager.fileExists(atPath: temporaryDownloadURL.path) {
            try defaultManager.removeItem(atPath: temporaryDownloadURL.path)
        }
        try  defaultManager.createDirectory(at: temporaryDownloadURL, withIntermediateDirectories: true, attributes: nil)
        
        // print( String(describing: defaultManager.subpaths(atPath: FileManager.default.temporaryDirectory.path)))
        
        return temporaryDownloadURL
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
                scale: 10_000
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

// Set the credentials to allow access for the Naperville damage assessment feature service.
extension ViewController: AGSAuthenticationManagerDelegate {
    func authenticationManager(_ authenticationManager: AGSAuthenticationManager, didReceive challenge: AGSAuthenticationChallenge) {
        print("DEBUG----->  Authentication challenge detected")
        // NOTE: Never hardcode login information in a production application. This is done solely for the sake of the sample.
        //        let credential = AGSCredential(user: "viewer01", password: "I68VGU^nMurF")
        //        challenge.continue(with: credential)
//                 challenge.continue(with: nil)
        challenge.trustHostAndContinue()
    }
}
