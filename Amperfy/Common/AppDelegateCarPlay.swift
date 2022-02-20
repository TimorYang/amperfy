import UIKit
import CarPlay
import MediaPlayer

typealias CarPlayPlayableFetchCallback = (_ completionHandler: @escaping () -> Void ) -> Void
typealias CarPlayTabFetchCallback = (_ completionHandler: @escaping ([CarPlayPlayableItem]) -> Void ) -> Void

struct CarPlayPlayableItem {
    let element: PlayableContainable
    let image: UIImage?
    let fetchCB: CarPlayPlayableFetchCallback?

    func asContentItem() -> MPContentItem {
        let item = MPContentItem(identifier: element.name)
        item.title = element.name
        item.subtitle = element.subtitle
        item.isContainer = true
        item.isPlayable = true
        item.isStreamingContent = !element.playables.hasCachedItems
        if let image = image {
            item.artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ -> UIImage in
                return image
            })
        }
        return item
    }
    
    func fetch(completionHandler: @escaping () -> Void) {
        if let fetchCB = fetchCB {
            fetchCB(completionHandler)
        } else {
            completionHandler()
        }
    }
}

struct CarPlayContainerItem {
    let element: PlayableContainable
    let image: UIImage?
    var containerItems = [CarPlayContainerItem]()
    var playableItems = [CarPlayPlayableItem]()

    var itemsCount: Int {
        return containerItems.count + playableItems.count
    }
    var items: [MPContentItem] {
        var result = [MPContentItem]()
        result.append(contentsOf: containerItems.compactMap{ $0.asContentItem() })
        result.append(contentsOf: playableItems.compactMap{ $0.asContentItem() })
        return result
    }
    
    func asContentItem() -> MPContentItem {
        let item = MPContentItem(identifier: element.name)
        item.title = element.name
        item.subtitle = element.subtitle
        item.isContainer = true
        item.isPlayable = false
        if let image = image {
            item.artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ -> UIImage in
                return image
            })
        }
        return item
    }
}

class CarPlayTabData {
    let title: String
    let image: UIImage
    var containerItems = [CarPlayContainerItem]()
    var playableItems = [CarPlayPlayableItem]()
    let fetchCB: CarPlayTabFetchCallback?
    
    init(title: String, image: UIImage, fetchCB: CarPlayTabFetchCallback?) {
        self.title = title
        self.image = image
        self.fetchCB = fetchCB
    }
    
    var itemsCount: Int {
        return containerItems.count + playableItems.count
    }
    var items: [MPContentItem] {
        var result = [MPContentItem]()
        result.append(contentsOf: containerItems.compactMap{ $0.asContentItem() })
        result.append(contentsOf: playableItems.compactMap{ $0.asContentItem() })
        return result
    }

    func asContentItem() -> MPContentItem {
        let item = MPContentItem(identifier: title)
        item.title = title
        item.isContainer = true
        item.isPlayable = false
        item.artwork = MPMediaItemArtwork(boundsSize: image.size, requestHandler: { _ -> UIImage in
            return self.image
        })
        return item
    }
    
    func fetch(completionHandler: @escaping () -> Void) {
        if let fetchCB = fetchCB {
            fetchCB() { items in
                self.playableItems = items
                completionHandler()
            }
        } else {
            completionHandler()
        }
    }
}

class CarPlayHandler: NSObject {

    let persistentStorage: PersistentStorage
    let library: LibraryStorage
    let backendApi: BackendApi
    let player: PlayerFacade
    var playableContentManager: MPPlayableContentManager
    var tabData = [CarPlayTabData]()

    init(persistentStorage: PersistentStorage, library: LibraryStorage, backendApi: BackendApi, player: PlayerFacade, playableContentManager: MPPlayableContentManager) {
        self.persistentStorage = persistentStorage
        self.library = library
        self.backendApi = backendApi
        self.player = player
        self.playableContentManager = playableContentManager
    }
    
    func initialize() {
        playableContentManager.delegate = self
        playableContentManager.dataSource = self
        populate()
    }
    
    func populate() {
        let recentSongsData = CarPlayTabData(title: "Recent Songs", image: UIImage.musicalNotesCarplay) { completionHandler in
            if self.persistentStorage.settings.isOnlineMode {
                self.persistentStorage.context.performAndWait {
                    let syncer = self.backendApi.createLibrarySyncer()
                    syncer.syncLatestLibraryElements(library: self.library)
                    let songs = self.library.getRecentSongsForCarPlay()
                    var songItems = [CarPlayPlayableItem]()
                    for song in songs {
                        let item = CarPlayPlayableItem(element: song, image: song.image, fetchCB: nil)
                        songItems.append(item)
                    }
                    completionHandler(songItems)
                }
            } else {
                completionHandler([])
            }
        }
        let songs = library.getRecentSongsForCarPlay()
        var songItems = [CarPlayPlayableItem]()
        for song in songs {
            let item = CarPlayPlayableItem(element: song, image: song.image, fetchCB: nil)
            songItems.append(item)
        }
        recentSongsData.playableItems = songItems

        let playlistsData = CarPlayTabData(title: "Playlists", image: UIImage.playlistCarplay, fetchCB: nil)
        let playlists = library.getPlaylistsForCarPlay()
        var playlistItems = [CarPlayPlayableItem]()
        for playlist in playlists {
            let item = CarPlayPlayableItem(element: playlist, image: nil) { completionHandler in
                playlist.fetchSync(storage: self.persistentStorage, backendApi: self.backendApi)
                completionHandler()
            }
            playlistItems.append(item)
        }
        playlistsData.playableItems = playlistItems

        let podcastsData = CarPlayTabData(title: "Podcasts", image: UIImage.podcastCarplay, fetchCB: nil)
        let podcasts = library.getPodcastsForCarPlay()
        var podcastItems = [CarPlayPlayableItem]()
        for podcast in podcasts {
            let item = CarPlayPlayableItem(element: podcast, image: podcast.image) { completionHandler in
                podcast.fetchSync(storage: self.persistentStorage, backendApi: self.backendApi)
                completionHandler()
            }
            podcastItems.append(item)
        }
        podcastsData.playableItems = podcastItems

        tabData = [playlistsData, recentSongsData, podcastsData]
    }
}

extension CarPlayHandler: MPPlayableContentDelegate {
    func playableContentManager(_ contentManager: MPPlayableContentManager, initiatePlaybackOfContentItemAt indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            guard indexPath.count > 0 else {
                completionHandler(nil)
                return
            }
            var containable: PlayableContainable? = nil
            if indexPath.count == 2 {
                let tabIndex = indexPath[0]
                let secondIndex = indexPath[1]
                containable = self.tabData[tabIndex].playableItems[secondIndex].element
            } else if indexPath.count == 3 {
                let tabIndex = indexPath[0]
                let secondIndex = indexPath[1]
                let thirdIndex = indexPath[2]
                containable = self.tabData[tabIndex].containerItems[secondIndex].playableItems[thirdIndex].element
            }

            if let containable = containable {
                self.player.play(context: PlayContext(containable: containable))
            }
            completionHandler(nil)
            
            #if targetEnvironment(simulator)
                // Workaround to make the Now Playing working on the simulator:
                // Source: https://stackoverflow.com/questions/52818170/handling-playback-events-in-carplay-with-mpnowplayinginfocenter
                UIApplication.shared.endReceivingRemoteControlEvents()
                UIApplication.shared.beginReceivingRemoteControlEvents()
            #endif
        }
    }
    
    func beginLoadingChildItems(at indexPath: IndexPath, completionHandler: @escaping (Error?) -> Void) {
        if indexPath.count == 1 {
            // Tab section
            let tabIndex = indexPath[0]
            tabData[tabIndex].fetch {
                completionHandler(nil)
            }
        } else if indexPath.count == 2 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            if !tabData[tabIndex].containerItems.isEmpty {
                completionHandler(nil)
            } else {
                tabData[tabIndex].playableItems[secondIndex].fetch {
                    completionHandler(nil)
                }
            }
        } else if indexPath.count == 3 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            let thirdIndex = indexPath[2]
            if !tabData[tabIndex].containerItems[secondIndex].containerItems.isEmpty {
                completionHandler(nil)
            } else {
                tabData[tabIndex].containerItems[secondIndex].playableItems[thirdIndex].fetch {
                    completionHandler(nil)
                }
            }
        } else {
            completionHandler(nil)
        }
    }
}

extension CarPlayHandler: MPPlayableContentDataSource {
    func numberOfChildItems(at indexPath: IndexPath) -> Int {
        if indexPath.indices.isEmpty {
            // Number of tabs
            return tabData.count
        } else if indexPath.indices.count == 1 {
            let tabIndex = indexPath[0]
            return tabData[tabIndex].itemsCount
        } else if indexPath.indices.count == 2 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            return tabData[tabIndex].containerItems[secondIndex].itemsCount
        } else if indexPath.indices.count == 3 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            let thirdIndex = indexPath[2]
            return tabData[tabIndex].containerItems[secondIndex].containerItems[thirdIndex].itemsCount
        }
        return 0
    }
    
    func contentItem(at indexPath: IndexPath) -> MPContentItem? {
        if indexPath.count == 1 {
            // Tab section
            let tabIndex = indexPath[0]
            return tabData[tabIndex].asContentItem()
        } else if indexPath.count == 2 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            return tabData[tabIndex].items[secondIndex]
        } else if indexPath.count == 3 {
            let tabIndex = indexPath[0]
            let secondIndex = indexPath[1]
            let thirdIndex = indexPath[2]
            return tabData[tabIndex].containerItems[secondIndex].items[thirdIndex]
        } else {
            return nil
        }
    }
}

/*
extension AppDelegate: CPApplicationDelegate {
    func application(_ application: UIApplication, didConnectCarInterfaceController interfaceController: CPInterfaceController, to window: CPWindow) {
        var sections = [CPListSection]()
        sections.append(
            CPListSection(items: [
                CPListItem(text: "ListItemExamle", detailText: "OK GO")
            ])
        )
        let listTemplate = CPListTemplate(title: "Blub", sections: sections)
        interfaceController.setRootTemplate(listTemplate, animated: true)
    }
    
    func application(_ application: UIApplication, didDisconnectCarInterfaceController interfaceController: CPInterfaceController, from window: CPWindow) {
        
    }
    
    
}
*/
