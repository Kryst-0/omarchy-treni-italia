import QtQuick
import qs.Commons as Commons
Item {
    id: root
    property var segments: []
    property int selected: -1
    signal picked(var segment)
    readonly property var bounds: {
        if (!segments.length) return [6,36,19,47]
        var xs=[], ys=[]
        for (var s of segments) { xs.push(s.points[0],s.points[2]); ys.push(s.points[1],s.points[3]) }
        return [Math.min.apply(null,xs),Math.min.apply(null,ys),Math.max.apply(null,xs),Math.max.apply(null,ys)]
    }
    function point(lon,lat) {
        var b=bounds, dx=Math.max(.2,(b[2]-b[0])*.74),dy=Math.max(.2,b[3]-b[1])
        var scale=Math.min((width-32)/dx,(height-24)/dy)
        return {x:width/2+(lon-(b[0]+b[2])/2)*.74*scale,y:height/2-(lat-(b[1]+b[3])/2)*scale}
    }
    onSegmentsChanged: { selected=-1; canvas.requestPaint() }
    onSelectedChanged: canvas.requestPaint()
    Connections { target: Commons.Color; function onAccentChanged() { canvas.requestPaint() } function onForegroundChanged() { canvas.requestPaint() } }
    Canvas {
        id: canvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var c=getContext('2d'); c.reset()
            for(var i=0;i<root.segments.length;i++) {
                var s=root.segments[i],a=root.point(s.points[0],s.points[1]),b=root.point(s.points[2],s.points[3])
                c.beginPath(); c.moveTo(a.x,a.y); c.lineTo(b.x,b.y)
                c.strokeStyle=i===root.selected ? Commons.Color.foreground : (s.active ? Commons.Color.accent : Qt.darker(Commons.Color.foreground,2.6))
                c.lineWidth=i===root.selected?5:(s.active?2.5:1); c.stroke()
                c.beginPath();c.arc(a.x,a.y,1.6,0,2*Math.PI);c.fillStyle=c.strokeStyle;c.fill()
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
            var best=12,hit=-1
            for(var i=0;i<root.segments.length;i++) {
                var s=root.segments[i],a=root.point(s.points[0],s.points[1]),b=root.point(s.points[2],s.points[3])
                var dx=b.x-a.x,dy=b.y-a.y,t=Math.max(0,Math.min(1,((mouse.x-a.x)*dx+(mouse.y-a.y)*dy)/(dx*dx+dy*dy||1)))
                var d=Math.hypot(mouse.x-a.x-t*dx,mouse.y-a.y-t*dy)
                if(d<best){best=d;hit=i}
            }
            if(hit>=0){root.selected=hit;root.picked(root.segments[hit])}
        }
    }
}
