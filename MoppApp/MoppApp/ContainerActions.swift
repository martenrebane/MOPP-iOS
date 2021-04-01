//
//  ContainerActions.swift
//  MoppApp
//
/*
 * Copyright 2017 Riigi Infosüsteemide Amet
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
 *
 */
protocol ContainerActions {
    func openExistingContainer(with url: URL, cleanup: Bool)
    func importFiles(with urls: [URL], cleanup: Bool)
    func addDataFilesToContainer(dataFilePaths: [String])
    func createNewContainer(with url: URL, dataFilePaths: [String], startSigningWhenCreated: Bool, cleanUpDataFilesInDocumentsFolder: Bool)
    func createNewContainerForNonSignableContainerAndSign()
}

extension ContainerActions where Self: UIViewController {
    func importFiles(with urls: [URL], cleanup: Bool) {
        let landingViewController = LandingViewController.shared!
        let navController = landingViewController.viewController(for: .signTab) as! UINavigationController
        let topSigningViewController = navController.viewControllers.last!
        
        landingViewController.documentPicker.dismiss(animated: false, completion: nil)
        
        if topSigningViewController.presentedViewController is FileImportProgressViewController {
            topSigningViewController.presentedViewController?.errorAlert(message: L(.fileImportAlreadyInProgressMessage))
            return
        }
        
        topSigningViewController.present(landingViewController.importProgressViewController, animated: false)
        
        MoppFileManager.shared.importFiles(with: urls) { [weak self] error, dataFilePaths in

            if landingViewController.fileImportIntent == .addToContainer {
                landingViewController.addDataFilesToContainer(dataFilePaths: dataFilePaths)
            }
            else if landingViewController.fileImportIntent == .openOrCreate {
                navController.setViewControllers([navController.viewControllers.first!], animated: false)
             
                let ext = urls.first!.pathExtension
                if landingViewController.containerType == nil {
                    if ext.isCdocContainerExtension {
                        landingViewController.containerType = .cdoc
                    } else {
                        landingViewController.containerType = .asic
                    }
                }
                let isAsicOrPadesContainer = (ext.isAsicContainerExtension || ext == ContainerFormatPDF) &&
                    landingViewController.containerType == .asic
                let isCdocContainer = ext.isCdocContainerExtension && landingViewController.containerType == .cdoc
                if  (isAsicOrPadesContainer || isCdocContainer) && urls.count == 1 {
                    self?.openExistingContainer(with: urls.first!, cleanup: cleanup)
                } else {
                    self?.createNewContainer(with: urls.first!, dataFilePaths: dataFilePaths)
                }
            }
        }
    }
    
    func openExistingContainer(with url: URL, cleanup: Bool) {
    
        let landingViewController = LandingViewController.shared!
    
        // Move container from inbox folder to documents folder and cleanup.
        let filePath = url.relativePath
        let fileName = url.lastPathComponent
        
        // Used to access folders on user device when opening container outside app (otherwise gives "Operation not permitted" error)
        url.startAccessingSecurityScopedResource()

        let navController = landingViewController.viewController(for: .signTab) as? UINavigationController

        var newFilePath: String = MoppFileManager.shared.filePath(withFileName: fileName)
            newFilePath = MoppFileManager.shared.copyFile(withPath: filePath, toPath: newFilePath)

        if (cleanup) {
            MoppFileManager.shared.removeFile(withPath: filePath)
        }

        let failure: ((_ error: NSError?) -> Void) = { err in
            
            landingViewController.importProgressViewController.dismissRecursivelyIfPresented(animated: false, completion: nil)
            
            var alert: UIAlertController
            guard err?.code == 10005 && url.lastPathComponent.hasSuffix(ContainerFormatDdoc) else {
                alert = UIAlertController(title: L(.fileImportOpenExistingFailedAlertTitle), message: L(.fileImportOpenExistingFailedAlertMessage, [fileName]), preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: L(.actionOk), style: .default, handler: nil))
                
                navController?.viewControllers.last!.present(alert, animated: true)
                return
            }
            
            alert = UIAlertController(title: L(.fileImportOpenExistingFailedAlertTitle), message: L(.noConnectionMessage), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L(.actionOk), style: .default, handler: nil))

            navController?.viewControllers.last!.present(alert, animated: true)
        }
        if landingViewController.containerType == .asic {
            MoppLibContainerActions.sharedInstance().openContainer(withPath: newFilePath,
                success: { (_ container: MoppLibContainer?) -> Void in
                    if container == nil {
                        // Remove invalid container. Probably ddoc.
                        MoppFileManager.shared.removeFile(withName: fileName)
                        failure(nil)
                        return
                    }
                
                    // If file to open is PDF and there is no signatures then create new container
                    let isPDF = url.pathExtension.lowercased() == ContainerFormatPDF
                    if isPDF && container!.signatures.isEmpty {
                        landingViewController.createNewContainer(with: url, dataFilePaths: [newFilePath])
                        return
                    }
                    
                    let containerViewController = ContainerViewController.instantiate()
                        containerViewController.containerPath = newFilePath
                        containerViewController.forcePDFContentPreview = isPDF
                    
                    landingViewController.importProgressViewController.dismissRecursively(animated: false, completion: {
                        navController?.pushViewController(containerViewController, animated: true)
                    })

                },
                failure: { error in
                    guard let nsError = error as NSError? else { failure(nil); return }
                    failure(nsError)
                }
            )
        } else {
            let containerViewController = CryptoContainerViewController.instantiate()
            let container = CryptoContainer(filename: fileName as NSString, filePath: newFilePath as NSString)
            
            MoppLibCryptoActions.sharedInstance().parseCdocInfo(
                newFilePath as String?,
                success: {(_ cdocInfo: CdocInfo?) -> Void in
                    guard let strongCdocInfo = cdocInfo else { return }
                    container.addressees = strongCdocInfo.addressees
                    container.dataFiles = strongCdocInfo.dataFiles
                    containerViewController.containerPath = newFilePath
                    containerViewController.state = .opened
                    containerViewController.container = container
                    containerViewController.isContainerEncrypted = true
                    landingViewController.importProgressViewController.dismissRecursively(animated: false, completion: {
                        navController?.pushViewController(containerViewController, animated: true)
                    })
                },
                failure: { _ in
                    DispatchQueue.main.async {
                         failure(nil)
                    }
                }
            )
        }
        url.stopAccessingSecurityScopedResource()
    }

    func addDataFilesToContainer(dataFilePaths: [String]) {
        let landingViewController = LandingViewController.shared!
        let navController = landingViewController.viewController(for: .signTab) as! UINavigationController
        let topSigningViewController = navController.viewControllers.last!

        if landingViewController.containerType == .asic {
            let containerViewController = topSigningViewController as? ContainerViewController
            let containerPath = containerViewController!.containerPath
            MoppLibContainerActions.sharedInstance().addDataFilesToContainer(
                withPath: containerPath,
                withDataFilePaths: dataFilePaths,
                success: { container in
                    landingViewController.importProgressViewController.dismissRecursively(animated: false, completion: {
                        containerViewController?.reloadContainer()
                    })
                },
                failure: { error in
                    landingViewController.importProgressViewController.dismissRecursively(animated: false, completion: {
                        guard let nsError = error as NSError? else { return }
                        if nsError.code == Int(MoppLibErrorCode.moppLibErrorDuplicatedFilename.rawValue) {
                            DispatchQueue.main.async {
                                self.errorAlert(message: L(.containerDetailsFileAlreadyExists))
                            }
                        }
                    })
                }
            )
        } else {
            let containerViewController = topSigningViewController as? CryptoContainerViewController
            dataFilePaths.forEach {
                let filename = ($0 as NSString).lastPathComponent as NSString
                if isDuplicatedFilename(container: (containerViewController?.container)!, filename: filename) {
                    DispatchQueue.main.async {
                        self.errorAlert(message: L(.containerDetailsFileAlreadyExists))
                    }
                    return
                }
                let dataFile = CryptoDataFile.init()
                dataFile.filename = filename as String?
                dataFile.filePath = $0
                
                containerViewController?.container.dataFiles.add(dataFile)
            }
            
            landingViewController.importProgressViewController.dismissRecursively(animated: false, completion: {
                containerViewController?.reloadContainer()
            })
        }
    }
    
    private func isDuplicatedFilename(container: CryptoContainer, filename: NSString) -> Bool {
        for dataFile in container.dataFiles {
            if let strongDataFile = dataFile as? CryptoDataFile {
                if strongDataFile.filename as NSString == filename {
                    return true
                }
            }
        }
        return false
    }
    
    func createNewContainer(with url: URL, dataFilePaths: [String], startSigningWhenCreated: Bool = false, cleanUpDataFilesInDocumentsFolder: Bool = true) {
        let landingViewController = LandingViewController.shared!
    
        let filePath = url.relativePath
        let fileName = url.lastPathComponent
        
        let (filename, _) = fileName.filenameComponents()
        let containerFilename: String
        if landingViewController.containerType == .asic {
            containerFilename = filename + "." + DefaultContainerFormat
        }else{
            containerFilename = filename + "." + ContainerFormatCdoc
        }
        
        var containerPath = MoppFileManager.shared.filePath(withFileName: containerFilename)
            containerPath = MoppFileManager.shared.duplicateFilename(atPath: containerPath)

        let navController = landingViewController.viewController(for: .signTab) as? UINavigationController

        let cleanUpDataFilesInDocumentsFolderCode: () -> Void = {
            dataFilePaths.forEach {
                if $0.hasPrefix(MoppFileManager.shared.documentsDirectoryPath()) {
                    MoppFileManager.shared.removeFile(withPath: $0)
                }
            }
        }
        if landingViewController.containerType == .asic {
            MoppLibContainerActions.sharedInstance().createContainer(
                withPath: containerPath,
                withDataFilePaths: dataFilePaths,
                success: { container in
                    if cleanUpDataFilesInDocumentsFolder {
                        cleanUpDataFilesInDocumentsFolderCode()
                    }
                    if container == nil {
                        
                        landingViewController.importProgressViewController.dismissRecursively(animated: false, completion: nil)
                        
                        let alert = UIAlertController(title: L(.fileImportCreateNewFailedAlertTitle), message: L(.fileImportCreateNewFailedAlertMessage, [fileName]), preferredStyle: .alert)
                        alert.addAction(UIAlertAction(title: L(.actionOk), style: .default, handler: nil))
                        
                        landingViewController.present(alert, animated: true)
                        return
                    }
                    
                    let containerViewController = SigningContainerViewController.instantiate()
                    containerViewController.containerPath = containerPath
                    
                    containerViewController.isCreated = true
                    containerViewController.startSigningWhenOpened = startSigningWhenCreated
                    
                    landingViewController.importProgressViewController.dismissRecursively(animated: false, completion: {
                        navController?.pushViewController(containerViewController, animated: true)
                    })
                    
            }, failure: { error in
                if cleanUpDataFilesInDocumentsFolder {
                    cleanUpDataFilesInDocumentsFolderCode()
                }
                landingViewController.importProgressViewController.dismiss(animated: false, completion: nil)
                MoppFileManager.shared.removeFile(withPath: filePath)
            }
            )
        } else {

            let containerViewController = CryptoContainerViewController.instantiate()
            let container = CryptoContainer(filename: containerFilename as NSString, filePath: containerPath as NSString)
            containerViewController.containerPath = containerPath
            
            for dataFilePath in dataFilePaths {
                let dataFile = CryptoDataFile.init()
                dataFile.filename = (dataFilePath as NSString).lastPathComponent
                dataFile.filePath = dataFilePath
                container.dataFiles.add(dataFile)
            }
            
            containerViewController.container = container
            containerViewController.isCreated = true
            
            landingViewController.importProgressViewController.dismissRecursively(animated: false, completion: {
                navController?.pushViewController(containerViewController, animated: true)
            })
        }

    }
    
    func createNewContainerForNonSignableContainerAndSign() {
        if let containerViewController = self as? ContainerViewController {
            let containerPath = containerViewController.containerPath!
            let containerPathURL = URL(fileURLWithPath: containerPath)
            createNewContainer(with: containerPathURL, dataFilePaths: [containerPath], startSigningWhenCreated: true, cleanUpDataFilesInDocumentsFolder: false)
        }
    }
}
