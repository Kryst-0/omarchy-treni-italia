import QtQuick
import QtTest
import "../StationModel.js" as Model
TestCase {
    name: "StationSimulation"
    function train(platform, time, options) {
        return Object.assign({platform:platform,expectedAt:time,number:"REG 1",platformKind:"actual",arrived:false},options||{})
    }
    function test_no_invented_tracks() {
        var s=Model.build([train("",500000),train("2",0)],100000)
        compare(s.tracks.length,1);compare(s.tracks[0].train,null);compare(s.unknown,1)
    }
    function test_nearest_train_per_platform_and_numeric_order() {
        var s=Model.build([train("10",400000),train("2",300000),train("2",500000)],100000)
        compare(s.tracks.length,2);compare(s.tracks[0].platform,"2")
        compare(s.tracks[0].count,2);compare(s.tracks[0].train.expectedAt,300000)
    }
    function test_elapsed_estimate_does_not_confirm_arrival() {
        var s=Model.build([train("1",100000)],120000)
        compare(s.tracks[0].state,"due");compare(s.tracks[0].progress,1)
        s=Model.build([train("1",100000,{arrived:true})],120000)
        compare(s.tracks[0].state,"confirmed")
    }
    function test_cancelled_old_and_distant_trains_are_omitted() {
        var s=Model.build([train("1",300000,{cancelled:true}),train("2",1),train("3",5000000)],300000)
        compare(s.tracks.length,3);verify(s.tracks.every(function(t){return t.train===null}))
    }
    function test_progress_approaches_platform() {
        var t=train("1",900000)
        var early=Model.build([t],300000).tracks[0].progress
        var later=Model.build([t],600000).tracks[0].progress
        verify(later>early);verify(later<=1)
    }
    function test_empty_inventory_tracks_stay_visible() {
        var s=Model.build([],100000,Model.platforms("S06421"))
        compare(s.tracks.length,19);compare(s.tracks[18].platform,"19")
        verify(s.tracks.every(function(t){return t.train===null}))
    }
    function test_verified_track_topology() {
        compare(Model.topology("S06511","1",false),"through")
        compare(Model.topology("S06511","2",false),"through")
        compare(Model.topology("S06421","19",false),"terminal")
        compare(Model.topology("S99999","1",false),"unknown")
    }
    function test_live_arrival_does_not_invent_departure() {
        compare(Model.position(1,100000,999999,"through",false),0.55)
        compare(Model.position(1,100000,999999,"terminal",false),1)
    }
    function test_demo_through_and_terminal_exit_differ() {
        compare(Model.position(1,100000,190000,"through",true),1)
        compare(Model.position(1,100000,190000,"terminal",true),0)
    }
    function test_downloaded_layout_supports_new_and_mixed_stations() {
        var layout={platforms:{"1":"through","3":"terminal","4 EST":"unknown"}}
        compare(Model.platforms("S99998",layout).length,3)
        compare(Model.topology("S99998","1",false,layout),"through")
        compare(Model.topology("S99998","3",false,layout),"terminal")
        compare(Model.topology("S99998","4 EST",false,layout),"unknown")
        var scene=Model.build([],100000,Model.platforms("S99998",layout))
        compare(scene.tracks.length,3)
    }
    function test_buffer_sides_are_per_track() {
        var layout={bufferEnds:{"1":"left","2":"right"}}
        compare(Model.bufferSide("1",false,layout),"left")
        compare(Model.bufferSide("2",false,layout),"right")
        compare(Model.bufferSide("3",false,layout),"unknown")
        compare(Model.bufferSide("3",true,layout),"left")
    }
    function test_demo_is_explicitly_fictional() {
        var t=Model.demo(100000)
        compare(t.length,3);verify(t.every(function(t){return t.number.indexOf("DEMO")===0}))
    }
}
