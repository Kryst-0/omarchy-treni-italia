import QtQuick
import qs.Commons as Commons
import qs.Ui as Ui
import "StationModel.js" as Model

Column {
    id: root
    property var trains: []
    property string stationId: ""
    property string stationName: ""
    property var layout: ({})
    property double fetchedAt: 0
    property bool active: false
    property bool demoMode: false
    property bool paused: false
    property double clockNow: Date.now()
    property double demoStart: Date.now()
    property double demoElapsed: 0
    readonly property bool stale: !demoMode && fetchedAt > 0 && clockNow - fetchedAt > 120000
    readonly property double effectiveNow: demoMode ? demoStart + demoElapsed : (stale ? fetchedAt + 120000 : clockNow)
    readonly property var scene: Model.build(demoMode ? Model.demo(demoStart) : trains, effectiveNow, demoMode ? ["1","2","3","4"] : Model.platforms(stationId,layout))
    readonly property bool terminalStation: !demoMode && scene.tracks.length>0 && scene.tracks.every(function(t){return Model.topology(stationId,t.platform,false,layout)==="terminal" && Model.bufferSide(t.platform,false,layout)==="right"})
    signal trainPicked(var train)
    spacing: Commons.Style.space(8)
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
    onDemoModeChanged: { demoStart=Date.now(); demoElapsed=0 }
    onActiveChanged: if(active) clockNow=Date.now()
    Timer {
        interval: 1000
        running: root.active && !root.paused
        repeat: true
        onTriggered: {
            root.clockNow=Date.now()
            if(root.demoMode) {
                root.demoElapsed+=30000
                if(root.demoElapsed>660000) { root.demoStart=Date.now();root.demoElapsed=0 }
            }
        }
    }
    Row {
        spacing: Commons.Style.space(8)
        Ui.Button { text:strings.t(root.demoMode?"sim.live":"sim.demo");onClicked:root.demoMode=!root.demoMode }
        Ui.Button { text:strings.t(root.paused?"sim.play":"sim.pause");onClicked:root.paused=!root.paused }
    }
    Label { width:parent.width;text:strings.t(root.demoMode?"sim.demoHint":"sim.hint");font.pixelSize:Commons.Style.font.caption }
    Label { width:parent.width;visible:root.layout.source==="OpenStreetMap";text:strings.t("sim.osm");font.pixelSize:Commons.Style.font.caption }
    Label { width:parent.width;visible:!root.demoMode&&!!root.layout.orientation;text:strings.t("sim.axis."+(root.layout.orientation||"west-east"));font.pixelSize:Commons.Style.font.caption }
    Label { width:parent.width;visible:root.stale;text:strings.t("sim.stale");color:Commons.Color.accent }
    Rectangle {
        width:parent.width
        height:stationBody.implicitHeight+Commons.Style.space(24)
        color:Commons.Color.background
        radius:Commons.Style.space(8)
        border.color:Qt.darker(Commons.Color.foreground,2.5)
        clip:true
        Column {
            id:stationBody
            x:Commons.Style.space(12);y:Commons.Style.space(12)
            width:parent.width-2*x
            spacing:0
            // Station sign uses the active theme accent, mounted on two posts.
            Item {
                width:parent.width;height:Commons.Style.space(90)
                Rectangle { x:parent.width*.14;y:Commons.Style.space(42);width:Commons.Style.space(5);height:Commons.Style.space(40);color:Qt.darker(Commons.Color.foreground,1.4) }
                Rectangle { x:parent.width*.86;y:Commons.Style.space(42);width:Commons.Style.space(5);height:Commons.Style.space(40);color:Qt.darker(Commons.Color.foreground,1.4) }
                Rectangle {
                    x:Commons.Style.space(8);y:Commons.Style.space(4)
                    width:parent.width-2*x;height:Commons.Style.space(55)
                    radius:Commons.Style.space(3)
                    color:Commons.Color.accent;border.color:Commons.Color.foreground;border.width:Commons.Style.space(2)
                    Text {
                        anchors.fill:parent;anchors.margins:Commons.Style.space(8)
                        textFormat:Text.PlainText
                        text:root.stationName.toUpperCase()
                        color:Commons.Color.background;font.family:Commons.Style.font.family
                        font.pixelSize:Commons.Style.space(24);font.bold:true
                        fontSizeMode:Text.Fit;minimumPixelSize:12
                        horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter
                        elide:Text.ElideRight;maximumLineCount:1
                    }
                }
                Label {
                    x:Commons.Style.space(8);y:Commons.Style.space(64)
                    width:parent.width-Commons.Style.space(90)
                    text:strings.t("sim.yard");color:Qt.darker(Commons.Color.foreground,1.3);font.pixelSize:Commons.Style.font.caption
                }
            }
            Item {
                width:parent.width
                height:trackRows.implicitHeight
                // A head concourse is drawn only for verified terminal stations.
                Rectangle {
                    visible:root.terminalStation
                    x:parent.width-Commons.Style.space(72);width:Commons.Style.space(72);height:parent.height
                    color:Qt.lighter(Commons.Color.background,1.6)
                    Rectangle { x:Commons.Style.space(8);width:Commons.Style.space(2);height:parent.height;color:Qt.darker(Commons.Color.foreground,2.0) }
                    Repeater {
                        model:Math.floor(parent.height/Commons.Style.space(22))
                        Rectangle { required property int index;y:index*Commons.Style.space(22);width:parent.width;height:1;color:Qt.darker(Commons.Color.foreground,3) }
                    }
                    Text {
                        anchors.centerIn:parent;rotation:90
                        textFormat:Text.PlainText;text:strings.t("sim.concourse")
                        color:Commons.Color.foreground;font.pixelSize:Commons.Style.space(12);font.bold:true;font.letterSpacing:3
                    }
                }
                Column {
                    id:trackRows
                    width:parent.width
                    Repeater {
                        model:root.scene.tracks
                        Item {
                            id:track
                            required property var modelData
                            width:trackRows.width;height:Commons.Style.space(90)
                            readonly property string topology:Model.topology(root.stationId,modelData.platform,root.demoMode,root.layout)
                            readonly property string bufferSide:Model.bufferSide(modelData.platform,root.demoMode,root.layout)
                            readonly property bool leftEnd:topology==="terminal" && bufferSide==="left"
                            readonly property real startX:leftEnd?Commons.Style.space(80):0
                            readonly property real endX:topology==="terminal"&&!leftEnd?width-Commons.Style.space(80):width
                            readonly property real railLength:endX-startX
                            clip:true
                            // Ballast, sleepers and the two steel rails.
                            Rectangle { x:track.startX;y:0;width:track.railLength;height:Commons.Style.space(35);color:Qt.lighter(Commons.Color.background,1.2) }
                            Repeater {
                                model:Math.floor(track.railLength/Commons.Style.space(10))
                                Rectangle { required property int index;x:track.startX+index*Commons.Style.space(10);y:Commons.Style.space(5);width:Commons.Style.space(4);height:Commons.Style.space(25);color:Qt.darker(Commons.Color.foreground,3) }
                            }
                            Rectangle { x:track.startX;y:Commons.Style.space(10);width:track.railLength;height:Commons.Style.space(2);color:Qt.darker(Commons.Color.foreground,1.4) }
                            Rectangle { x:track.startX;y:Commons.Style.space(25);width:track.railLength;height:Commons.Style.space(2);color:Qt.darker(Commons.Color.foreground,1.4) }
                            // The rails physically end at this conspicuous buffer stop.
                            Item {
                                visible:track.topology==="terminal"
                                x:track.leftEnd?track.startX:track.endX-Commons.Style.space(16)
                                y:Commons.Style.space(1)
                                width:Commons.Style.space(16);height:Commons.Style.space(33)
                                Rectangle { x:Commons.Style.space(5);width:Commons.Style.space(7);height:parent.height;color:Commons.Color.accent;radius:Commons.Style.space(2) }
                                Rectangle { y:Commons.Style.space(7);width:parent.width;height:Commons.Style.space(6);color:Commons.Color.foreground;radius:Commons.Style.space(2) }
                                Rectangle { y:Commons.Style.space(22);width:parent.width;height:Commons.Style.space(6);color:Commons.Color.foreground;radius:Commons.Style.space(2) }
                            }
                            // Raised platform with a yellow safety line and tiled paving.
                            Rectangle {
                                x:Commons.Style.space(48);y:Commons.Style.space(38)
                                width:parent.width-x-(track.topology==="terminal"?0:Commons.Style.space(48));height:Commons.Style.space(46)
                                color:Qt.lighter(Commons.Color.background,1.8);radius:Commons.Style.space(2)
                                Rectangle { width:parent.width-Commons.Style.space(72);height:Commons.Style.space(3);color:Commons.Color.accent }
                                Repeater {
                                    model:Math.max(0,Math.floor((parent.width-Commons.Style.space(75))/Commons.Style.space(28)))
                                    Rectangle { required property int index;x:index*Commons.Style.space(28);y:Commons.Style.space(5);width:1;height:Commons.Style.space(40);color:Qt.darker(Commons.Color.foreground,2.5) }
                                }
                                // A narrow canopy with supports and a shadow.
                                Rectangle { x:Commons.Style.space(57);y:Commons.Style.space(7);width:Math.max(0,parent.width-Commons.Style.space(150));height:Commons.Style.space(4);color:Commons.Color.background;opacity:.8 }
                                Rectangle { x:Commons.Style.space(55);y:Commons.Style.space(4);width:Math.max(0,parent.width-Commons.Style.space(150));height:Commons.Style.space(5);color:Qt.darker(Commons.Color.foreground,1.6) }
                                Rectangle { x:Commons.Style.space(60);y:Commons.Style.space(9);width:Commons.Style.space(3);height:Commons.Style.space(10);color:Commons.Color.foreground }
                                Rectangle {
                                    x:Commons.Style.space(7);y:Commons.Style.space(9);width:Commons.Style.space(35);height:Commons.Style.space(28)
                                    color:Commons.Color.accent;radius:Commons.Style.space(2)
                                    Text { anchors.centerIn:parent;textFormat:Text.PlainText;text:track.modelData.platform;color:Commons.Color.background;font.bold:true;font.pixelSize:Commons.Style.space(18) }
                                }
                                Label {
                                    x:Commons.Style.space(55);y:Commons.Style.space(15)
                                    width:Math.max(0,parent.width-Commons.Style.space(134))
                                    text:track.modelData.train ? track.modelData.train.number+" · "+strings.t("sim.minutes").arg(Commons.I18n.formatNumber(track.modelData.minutes)) : strings.t("sim.emptyTrack")
                                    color:Commons.Color.foreground;font.pixelSize:Commons.Style.space(11);elide:Text.ElideRight;wrapMode:Text.NoWrap
                                }
                                Label {
                                    x:Commons.Style.space(55);y:Commons.Style.space(29)
                                    width:Math.max(0,parent.width-Commons.Style.space(134))
                                    text:strings.t("sim.type."+track.topology)+(track.topology==="terminal"&&track.bufferSide==="unknown"?" · "+strings.t("sim.sideUnknown"):"")+(track.modelData.train?" · "+strings.t("sim."+track.modelData.state):"")
                                    color:Qt.darker(Commons.Color.foreground,1.3);font.pixelSize:Commons.Style.space(9);elide:Text.ElideRight;wrapMode:Text.NoWrap
                                }
                            }
                            // A three-car train, viewed from above, approaches the platform.
                            Item {
                                visible:!!track.modelData.train
                                width:Commons.Style.space(119);height:Commons.Style.space(22)
                                y:Commons.Style.space(7)
                                readonly property real movement:Model.position(track.modelData.progress,track.modelData.train?track.modelData.train.expectedAt:0,root.effectiveNow,track.topology,root.demoMode)
                                x:track.topology==="terminal" ? track.startX+Commons.Style.space(18)+(track.leftEnd?1-movement:movement)*Math.max(0,track.railLength-width-Commons.Style.space(36)) : -width+movement*(track.endX+width)
                                // A reversing demo train turns around on a terminal track.
                                rotation:(track.leftEnd?180:0)+(root.demoMode && track.topology==="terminal" && track.modelData.train && root.effectiveNow>track.modelData.train.expectedAt+30000?180:0)
                                Behavior on x { enabled:root.active&&!root.paused;NumberAnimation { duration:Commons.Style.duration(220);easing.type:Easing.OutCubic } }
                                Repeater {
                                    model:3
                                    Rectangle {
                                        required property int index
                                        x:index*Commons.Style.space(40);width:Commons.Style.space(37);height:parent.height
                                        radius:Commons.Style.space(4)
                                        color:track.modelData.train&&track.modelData.train.platformKind==="actual"?Commons.Color.foreground:Qt.darker(Commons.Color.foreground,1.4)
                                        border.color:Commons.Color.background;border.width:1
                                        Rectangle { x:Commons.Style.space(4);y:Commons.Style.space(3);width:parent.width-Commons.Style.space(8);height:Commons.Style.space(3);color:index===2?Commons.Color.accent:Commons.Color.accent;radius:1 }
                                        Rectangle { x:Commons.Style.space(9);y:Commons.Style.space(9);width:Commons.Style.space(18);height:Commons.Style.space(6);color:Qt.darker(Commons.Color.foreground,1.8);radius:2 }
                                        Rectangle { visible:index===2;anchors.right:parent.right;anchors.rightMargin:2;y:Commons.Style.space(9);width:Commons.Style.space(4);height:Commons.Style.space(6);color:Commons.Color.background;radius:1 }
                                    }
                                }
                            }
                            MouseArea { anchors.fill:parent;enabled:!root.demoMode&&!!track.modelData.train;cursorShape:Qt.PointingHandCursor;onClicked:root.trainPicked(track.modelData.train) }
                        }
                    }
                }
            }
            Rectangle {
                width:parent.width;height:Commons.Style.space(42)
                color:Qt.lighter(Commons.Color.background,1.5)
                Label { anchors.centerIn:parent;text:strings.t(root.terminalStation?"sim.entrance":"sim.underpass");color:Commons.Color.foreground;font.pixelSize:Commons.Style.space(12);font.bold:true }
                Rectangle { x:Commons.Style.space(15);y:Commons.Style.space(13);width:Commons.Style.space(22);height:Commons.Style.space(16);color:Commons.Color.accent;radius:2 }
                Text { x:Commons.Style.space(22);y:Commons.Style.space(14);textFormat:Text.PlainText;text:"i";color:Commons.Color.background;font.bold:true }
            }
        }
    }
    Label { width:parent.width;visible:!root.scene.tracks.length;text:strings.t("sim.empty") }
    Label { width:parent.width;visible:root.scene.unknown>0;text:strings.t("sim.unassigned").arg(Commons.I18n.formatNumber(root.scene.unknown));font.pixelSize:Commons.Style.font.caption }
}
