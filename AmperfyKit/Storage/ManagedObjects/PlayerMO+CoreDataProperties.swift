//
//  PlayerMO+CoreDataProperties.swift
//  AmperfyKit
//
//  Created by Maximilian Bauer on 09.03.19.
//  Copyright (c) 2019 Maximilian Bauer. All rights reserved.
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import Foundation
import CoreData

extension PlayerMO {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<PlayerMO> {
        return NSFetchRequest<PlayerMO>(entityName: "Player")
    }

    @NSManaged public var autoCachePlayedItemSetting: Int16
    @NSManaged public var musicIndex: Int32
    @NSManaged public var podcastIndex: Int32
    @NSManaged public var playerMode: Int16
    @NSManaged public var isUserQueuePlaying: Bool
    @NSManaged public var repeatSetting: Int16
    @NSManaged public var shuffleSetting: Int16
    @NSManaged public var musicPlaybackRate: Double
    @NSManaged public var podcastPlaybackRate: Double
    @NSManaged public var contextPlaylist: PlaylistMO?
    @NSManaged public var shuffledContextPlaylist: PlaylistMO?
    @NSManaged public var userQueuePlaylist: PlaylistMO?
    @NSManaged public var podcastPlaylist: PlaylistMO?

}
