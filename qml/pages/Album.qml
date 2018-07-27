/**
 * Copyright (C) 2018 Willem-Jan de Hoog
 *
 * License: MIT
 */


import QtQuick 2.2
import Sailfish.Silica 1.0

import "../components"
import "../Spotify.js" as Spotify
import "../Util.js" as Util

Page {
    id: albumPage
    objectName: "AlbumPage"

    property string defaultImageSource : "image://theme/icon-l-music"
    property bool showBusy: false
    property var album
    property var albumArtists
    property bool isAlbumSaved: false

    property int offset: 0
    property int limit: app.searchLimit.value
    property bool canLoadNext: true
    property bool canLoadPrevious: offset >= limit
    property int currentIndex: -1

    property string currentTrackId: ""

    allowedOrientations: Orientation.All

    ListModel {
        id: searchModel
    }

    SilicaListView {
        id: listView
        model: searchModel

        width: parent.width
        anchors.top: parent.top
        anchors.bottom: navPanel.top
        clip: navPanel.expanded

        header: Column {
            id: lvColumn

            width: parent.width - 2*Theme.paddingMedium
            x: Theme.paddingMedium
            anchors.bottomMargin: Theme.paddingLarge
            spacing: Theme.paddingLarge

            PageHeader {
                id: pHeader
                width: parent.width
                title: qsTr("Album")
                MenuButton {}
            }

            LoadPullMenus {}
            LoadPushMenus {}

            Image {
                id: imageItem
                source:  (album && album.images)
                         ? album.images[0].url : defaultImageSource
                width: parent.width * 0.75
                height: width
                fillMode: Image.PreserveAspectFit
                anchors.horizontalCenter: parent.horizontalCenter
                onPaintedHeightChanged: height = Math.min(parent.width, paintedHeight)
                MouseArea {
                     anchors.fill: parent
                     onClicked: app.playContext(album)
                }
            }

            MetaInfoPanel {
                id: metaLabels
                width: parent.width
                firstLabelText: album.name
                // arrows: \u27A5 \u21A6 \u21A5
                // pointing finger: \u261B
                // triangles: \u25BA \u25B7 \u27A4
                // bars: \u2759 \u275A
                secondLabelText: "\u21A5 " + Util.createItemsString(album.artists, qsTr("no artist known"))
                thirdLabelText: {
                    var s = ""
                    if(album.tracks)
                        s += album.tracks.total + " " + qsTr("tracks")
                    else if(album.album_type === "single")
                        s += "1 " + qsTr("track")
                    if(album.release_date && album.release_date.length > 0)
                        s += ", " + Util.getYearFromReleaseDate(album.release_date)
                    if(album.genres && album.genres.length > 0)
                        s += ", " + Util.createItemsString(album.genres, "")
                    return s
                }
                onSecondLabelClicked: app.loadArtist(album.artists)
                //secondLabel.font.underline: true to indicate you can click on it
                isFavorite: isAlbumSaved
                onToggleFavorite: app.toggleSavedAlbum(album, isAlbumSaved, function(saved) {
                    isAlbumSaved = saved
                })
            }

            Separator {
                width: parent.width
                color: Theme.primaryColor
            }

        }

        delegate: ListItem {
            id: listItem
            width: parent.width - 2*Theme.paddingMedium
            x: Theme.paddingMedium
            contentHeight: Theme.itemSizeExtraSmall

            AlbumTrackListItem {
                id: albumTrackListItem
                dataModel: model
                isFavorite: saved
                onToggleFavorite: app.toggleSavedTrack(model)
            }

            menu: AlbumTrackContextMenu {}

            onClicked: app.playTrack(track)
        }

        VerticalScrollDecorator {}

        Label {
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignBottom
            visible: parent.count == 0
            text: qsTr("No tracks found")
            color: Theme.secondaryColor
        }

    }

    NavigationPanel {
        id: navPanel
    }

    onAlbumChanged: refresh()

    function refresh() {
        //showBusy = true
        searchModel.clear()        

        Spotify.getAlbumTracks(album.id,
                               {offset: offset, limit: limit},
                               function(error, data) {
            if(data) {
                try {
                    console.log("number of AlbumTracks: " + data.items.length)
                    offset = data.offset
                    var trackIds = []
                    for(var i=0;i<data.items.length;i++) {
                        searchModel.append({type: Spotify.ItemType.Track,
                                            name: data.items[i].name,
                                            saved: false,
                                            track: data.items[i]})
                        trackIds.push(data.items[i].id)
                    }
                    // get info about saved tracks
                    Spotify.containsMySavedTracks(trackIds, function(error, data) {
                        if(data) {
                            Util.setSavedInfo(Spotify.ItemType.Track, trackIds, data, searchModel)
                        }
                    })

                } catch (err) {
                    console.log(err)
                }
            } else {
                console.log("No Data for getAlbumTracks")
            }
        })

        var artists = []
        for(var i=0;i<album.artists.length;i++)
            artists.push(album.artists[i].id)
        Spotify.getArtists(artists, {}, function(error, data) {
            if(data)
                albumArtists = data.artists
        })

        Spotify.containsMySavedAlbums([album.id], {}, function(error, data) {
            if(data)
                isAlbumSaved = data[0]
        })
    }

}
