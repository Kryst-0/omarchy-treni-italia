import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons
import qs.Ui as Ui

Ui.Panel {
    id: root
    moduleName: "krysto.treni"
    ipcTarget: "krysto.treni"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight
    Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }
    property string view: "station"
    property string boardKind: "arrivi"
    property bool simulation: true
    property double boardFetchedAt: 0
    property var stationLayout: ({})
    property string layoutStation: ""
    property string layoutStatus: "idle"
    property string stationId: setting("stationId", "")
    property string stationName: setting("stationName", "")
    property string regionId: String(setting("region", "0"))
    property bool autoRefresh: setting("autoRefresh", false)
    property var stations: []
    property var rows: []
    property var segments: []
    property var stops: []
    property var selectedTrain: null
    property var selectedRoute: null
    property string routeTitle: ""
    property string error: ""
    property string updated: ""
    property bool partial: false
    property int generation: 0
    property var requestQueue: []
    readonly property bool busy: feed.running || requestQueue.length > 0
    readonly property var regions: [{value:"0",label:strings.t("region.italy")},{value:"19",label:"Abruzzo"},{value:"15",label:"Basilicata"},{value:"17",label:"Calabria"},{value:"18",label:"Campania"},{value:"8",label:"Emilia-Romagna"},{value:"10",label:"Friuli Venezia Giulia"},{value:"5",label:"Lazio"},{value:"2",label:"Liguria"},{value:"1",label:"Lombardia"},{value:"11",label:"Marche"},{value:"7",label:"Molise"},{value:"3",label:"Piemonte"},{value:"16",label:"Puglia"},{value:"20",label:"Sardegna"},{value:"14",label:"Sicilia"},{value:"13",label:"Toscana"},{value:"21",label:strings.t("region.trento")},{value:"22",label:strings.t("region.bolzano")},{value:"6",label:"Umbria"},{value:"4",label:"Valle d'Aosta"},{value:"9",label:"Veneto"}]

    function persist(values) {
        var entry=Object.assign({id:moduleName},settings,values)
        settings=entry
        if(bar && bar.shell) bar.shell.updateEntryInline(moduleName,entry)
    }
    function reset() {
        generation++; requestQueue=[]; rows=[]; stops=[]; selectedTrain=null; selectedRoute=null;routeTitle="";error="";partial=false;updated=""
    }
    function run(args) {
        requestQueue=requestQueue.concat([{args:args,generation:generation}]); pump()
    }
    function pump() {
        if(feed.running || !requestQueue.length) return
        var next=requestQueue[0];requestQueue=requestQueue.slice(1)
        feed.action=next.args[0];feed.generation=next.generation
        feed.command=["python3",Qt.resolvedUrl("feed.py").toString().replace(/^file:\/\//,"")].concat(next.args)
        feed.running=true
    }
    function loadLayout() {
        if(!stationId || layoutStation===stationId || !setting("mapLayouts",true)) return
        if(layoutFeed.running)return
        layoutStation=stationId;layoutStatus="loading"
        layoutFeed.station=stationId
        layoutFeed.command=["python3",Qt.resolvedUrl("feed.py").toString().replace(/^file:\/\//,""),"layout",stationId]
        layoutFeed.running=true
    }
    function refresh() {
        if(busy)return
        error=""; partial=false
        if(selectedTrain)run(["train",selectedTrain.originId,selectedTrain.id,selectedTrain.date])
        else if(view==="station" && stationId){ run(["board",stationId,boardKind]);loadLayout() }
        else if(view==="map") { run(["map",regionId]); if(selectedRoute)run(["route",regionId,String(selectedRoute.a),String(selectedRoute.b)]) }
    }
    function selectStation(s) {
        reset();stationId=s.id;stationName=s.name;stations=[];stationLayout={};layoutStation="";layoutStatus="idle"
        persist({stationId:stationId,stationName:stationName});run(["board",stationId,boardKind]);loadLayout()
    }
    function platform(t) {
        return strings.t("platform").arg(t.platform||strings.t("unknown")).arg(strings.t(t.platformKind||"unknown"))
    }
    function showTrain(t) { reset();selectedTrain=t;run(["train",t.originId,t.id,t.date]) }
    onOpenedChanged: if(opened) refresh()
    Timer { interval:60000;running:root.opened && root.autoRefresh && !root.selectedTrain;repeat:true;onTriggered:root.refresh() }
    Process {
        id: feed
        property string action: ""
        property int generation: 0
        onRunningChanged: if(!running)Qt.callLater(root.pump)
        stdout: StdioCollector {
            onStreamFinished: {
                if(feed.generation!==root.generation)return
                try {
                    var d=JSON.parse(text)
                    if(!d.ok){root.error=strings.t(d.errorKey||"error.network");return}
                    root.updated=d.updated
                    if(feed.action==="search")root.stations=d.stations
                    if(feed.action==="board"||feed.action==="all"){root.rows=d.trains;root.partial=!!d.partial;if(feed.action==="board")root.boardFetchedAt=Date.now()}
                    if(feed.action==="map")root.segments=d.segments
                    if(feed.action==="route") {
                        root.routeTitle=d.routes.map(r=>r.name).join(" / ")
                        var seen={}, result=[]
                        for(var r of d.routes)for(var t of r.trains){var k=t.id+":"+t.originId+":"+t.date;if(!seen[k]){seen[k]=true;result.push(t)}}
                        root.rows=result
                    }
                    if(feed.action==="train"){root.selectedTrain=d.train;root.stops=d.stops}
                }catch(e){root.error=strings.t("error.response")}
            }
        }
    }
    Process {
        id:layoutFeed
        property string station:""
        onRunningChanged:if(!running)Qt.callLater(root.loadLayout)
        stdout:StdioCollector {
            onStreamFinished:{
                if(layoutFeed.station!==root.stationId||!root.setting("mapLayouts",true))return
                try {
                    var d=JSON.parse(text)
                    if(d.ok){root.stationLayout=d.layout;root.layoutStatus="ready"}
                    else {root.stationLayout={};root.layoutStatus="unavailable"}
                }catch(e){root.layoutStatus="unavailable"}
            }
        }
    }
    Ui.BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        text: "󰔬"
        tooltipText: strings.t("title")
        onPressed: function(b) { if(b===Qt.RightButton)root.refresh();else root.toggle() }
    }
    Ui.KeyboardPanel {
        id: panel
        owner: root
        anchorItem: button
        bar: root.bar
        open: root.opened
        focusTarget: panel.loadedContent
        contentWidth: panel.fittedContentWidth(Commons.Style.space(680))
        contentHeight: panel.fittedContentHeight(Commons.Style.space(740),Commons.Style.space(740))
        content: FocusScope {
            anchors.fill: parent
            Keys.onEscapePressed: root.close()
            Flickable {
                anchors.fill:parent
                contentWidth:width; contentHeight:column.implicitHeight
                clip:true; boundsBehavior:Flickable.StopAtBounds
                Column {
                    id:column
                    width:parent.width
                    spacing:Commons.Style.space(12)
                    Row {
                        spacing:Commons.Style.space(8)
                        Label { text:strings.t("title");font.pixelSize:Commons.Style.space(24) }
                        Ui.Button { text:strings.t("close");onClicked:root.close() }
                    }
                    Label { width:parent.width;text:strings.t("tagline");opacity:.65;font.pixelSize:Commons.Style.font.caption }
                    Row {
                        spacing:Commons.Style.space(6)
                        Ui.Button { text:strings.t("station");selected:root.view==="station";onClicked:{root.reset();root.view="station";root.refresh()} }
                        Ui.Button { text:strings.t("map");selected:root.view==="map";onClicked:{root.reset();root.view="map";root.refresh()} }
                        Ui.Button { text:strings.t("refresh");enabled:!root.busy;onClicked:root.refresh() }
                        Ui.Button { text:strings.t(root.autoRefresh?"autoOn":"autoOff");onClicked:{root.autoRefresh=!root.autoRefresh;root.persist({autoRefresh:root.autoRefresh})} }
                    }
                    Column {
                        width:parent.width
                        spacing:Commons.Style.space(8)
                        visible:root.view==="station"&&!root.selectedTrain
                        Row {
                            width:parent.width
                            spacing:Commons.Style.space(8)
                            Ui.TextField { id:query;width:parent.width-find.implicitWidth-parent.spacing;placeholderText:strings.t("search");maximumLength:80;onAccepted:if(text.trim().length>=2){root.generation++;root.requestQueue=[];root.run(["search",text.trim()])} }
                            Ui.Button { id:find;text:strings.t("find");enabled:!root.busy&&query.text.trim().length>=2;onClicked:{root.generation++;root.requestQueue=[];root.run(["search",query.text.trim()])} }
                        }
                        Repeater {
                            model:root.stations
                            Rectangle {
                                required property var modelData
                                width:column.width;height:Commons.Style.space(36)
                                color:pick.containsMouse?Qt.darker(Commons.Color.accent,2):"transparent"
                                Label { anchors.fill:parent;verticalAlignment:Text.AlignVCenter;text:modelData.name }
                                MouseArea { id:pick;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:root.selectStation(modelData) }
                            }
                        }
                        Label { width:parent.width;text:strings.t("stationJoke");opacity:.65;font.pixelSize:Commons.Style.font.caption }
                        Label { width:parent.width;text:root.stationName||strings.t("choose");font.pixelSize:Commons.Style.space(20) }
                        Row {
                            spacing:Commons.Style.space(8)
                            Ui.Button { text:strings.t("departures");selected:root.boardKind==="partenze";onClicked:{root.reset();root.simulation=false;root.boardKind="partenze";root.refresh()} }
                            Ui.Button { text:strings.t("arrivals");selected:root.boardKind==="arrivi";onClicked:{root.reset();root.boardKind="arrivi";root.refresh()} }
                            Ui.Button { text:strings.t("sim.title");selected:root.simulation;enabled:!!root.stationId;onClicked:{root.reset();root.simulation=!root.simulation;root.boardKind="arrivi";root.refresh()} }
                        }
                    }
                    Column {
                        width:parent.width
                        visible:root.view==="station"&&root.simulation&&!!root.stationId&&!root.selectedTrain
                        spacing:Commons.Style.space(6)
                        Row {
                            spacing:Commons.Style.space(6)
                            Ui.Button {
                                text:strings.t(root.setting("mapLayouts",true)?"sim.mapsOn":"sim.mapsOff")
                                onClicked:{
                                    var enabled=!root.setting("mapLayouts",true)
                                    root.persist({mapLayouts:enabled})
                                    root.layoutStation="";root.stationLayout={};root.layoutStatus="idle"
                                    if(enabled)root.loadLayout()
                                }
                            }
                            Ui.Button {
                                text:strings.t("sim.retryMap")
                                visible:root.layoutStatus==="unavailable"
                                onClicked:{root.layoutStation="";root.loadLayout()}
                            }
                        }
                        Label {width:parent.width;text:strings.t("sim.mapPrivacy");font.pixelSize:Commons.Style.font.caption}
                        Label {width:parent.width;visible:root.layoutStatus==="loading"||root.layoutStatus==="unavailable";text:strings.t("sim.map."+root.layoutStatus);font.pixelSize:Commons.Style.font.caption}
                    }
                    StationScene {
                        layout:root.stationLayout
                        stationId:root.stationId
                        stationName:root.stationName
                        width:parent.width
                        visible:root.view==="station" && root.simulation && !root.selectedTrain && !!root.stationId
                        active:root.opened && visible
                        trains:root.boardKind==="arrivi"?root.rows:[]
                        fetchedAt:root.boardFetchedAt
                        onTrainPicked:function(train){root.showTrain(train)}
                    }
                    Column {
                        visible:root.view==="map"&&!root.selectedTrain
                        width:parent.width;spacing:Commons.Style.space(8)
                        Ui.Dropdown { width:parent.width;options:root.regions;value:root.regionId;onChanged:function(value){root.reset();root.regionId=value;root.segments=[];root.persist({region:value});root.run(["map",value])} }
                        Label { width:parent.width;text:strings.t("mapJoke");opacity:.65;font.pixelSize:Commons.Style.font.caption }
                        Network { width:parent.width;height:Commons.Style.space(315);segments:root.segments;onPicked:function(s){root.reset();root.selectedRoute=s;root.run(["route",root.regionId,String(s.a),String(s.b)])} }
                        Label { width:parent.width;text:strings.t("mapHint");font.pixelSize:Commons.Style.font.caption }
                        Ui.Button { text:strings.t("all");enabled:!root.busy;onClicked:{root.reset();root.run(["all",root.regionId])} }
                        Label { width:parent.width;text:strings.t("bulk");font.pixelSize:Commons.Style.font.caption }
                        Label { width:parent.width;text:root.routeTitle;visible:text!=="" }
                    }
                    Label { width:parent.width;visible:root.busy;text:strings.t("loading");color:Commons.Color.accent }
                    Label { width:parent.width;visible:root.error!=="";text:root.error;color:Commons.Color.accent }
                    Label { width:parent.width;visible:root.partial;text:strings.t("partial") }
                    Column {
                        visible:!!root.selectedTrain
                        width:parent.width;spacing:Commons.Style.space(8)
                        Ui.Button { text:strings.t("back");onClicked:{root.reset();root.refresh()} }
                        Label { width:parent.width;text:root.selectedTrain?root.selectedTrain.number+" · "+root.selectedTrain.origin+" → "+root.selectedTrain.destination:"" }
                        Repeater {
                            model:root.stops
                            Label { required property var modelData;width:column.width;text:"●  "+modelData.time+"  "+modelData.name+(modelData.platform?" · "+strings.t("platform").arg(modelData.platform).arg(""):"") }
                        }
                    }
                    Label { width:parent.width;visible:!root.busy&&!root.error&&!root.rows.length&&!root.selectedTrain&&(!!root.stationId||root.view==="map");text:strings.t("empty") }
                    Repeater {
                        model:root.selectedTrain||(root.view==="station"&&root.simulation)?[]:root.rows
                        Rectangle {
                            required property var modelData
                            width:column.width;height:trainColumn.implicitHeight+Commons.Style.space(16)
                            radius:Commons.Style.cornerRadius
                            color:trainMouse.containsMouse?Qt.darker(Commons.Color.accent,2.5):Qt.rgba(1,1,1,.035)
                            Column {
                                id:trainColumn
                                x:Commons.Style.space(8);y:Commons.Style.space(8);width:parent.width-2*x;spacing:Commons.Style.space(4)
                                Label { width:parent.width;text:modelData.time+"  "+modelData.number+"  → "+modelData.destination;font.bold:true }
                                Label { width:parent.width;text:root.platform(modelData);color:modelData.platformKind==="actual"?Commons.Color.accent:Commons.Color.foreground;font.pixelSize:Commons.Style.space(18) }
                                Label { width:parent.width;text:modelData.cancelled?strings.t("cancelled"):strings.t("delay").arg((modelData.delay>0?"+":"")+Commons.I18n.formatNumber(modelData.delay)) }
                            }
                            MouseArea { id:trainMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:root.showTrain(modelData) }
                        }
                    }
                    Label { width:parent.width;visible:root.updated!=="";text:strings.t("updated").arg(root.updated);font.pixelSize:Commons.Style.font.caption }
                    Label { width:parent.width;text:strings.t("limit");font.pixelSize:Commons.Style.font.caption }
                    Label { width:parent.width;text:strings.t("source");font.pixelSize:Commons.Style.font.caption;opacity:.65 }
                }
            }
        }
    }
}
