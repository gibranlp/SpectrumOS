import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell

Scope {
    FloatingWindow {
        id: bar
        implicitWidth: 1280
        implicitHeight: 34
        visible: target.topBarActive
        property string style: "full"
        color: "transparent"
        mask: Shell.BarInputRegion { backdrop: islands; islands: bar.style === "islands"; hoverTarget: target }
        Shell.BarIslands {
            id: islands
            anchors.fill: parent
            groups: [{start:10,length:180}]
        }
        Shell.DashboardHoverTarget {
            id: target
            targetScreen: Quickshell.screens[0]
            anchors { top: parent.top; bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: 260
            onOpenRequested: dashboardOpen = true
        }
    }
    SignalSpy { id: opened; target: target; signalName: "openRequested" }
    TestCase {
        name: "DashboardHoverTarget"
        when: true
        onCompletedChanged: if (completed) {
            console.log("Dashboard hover targets:",qtest_results.passCount,"passed",qtest_results.failCount,"failed");
            Qt.quit();
        }
        function test_layouts_data() {
            const rows=[];
            for (const style of ["full","islands"])
                for (const position of ["top","left"])
                    for (const profile of ["standard","minimal","detailed","multimedia","gaming"])
                        rows.push({tag:style+"-"+position+"-"+profile,style:style,position:position,profile:profile});
            return rows;
        }
        function test_layouts(data) {
            target.dashboardOpen=true;
            bar.style=data.style;
            target.barPosition=data.position;
            target.barProfile=data.profile;
            target.barVisible=!["minimal","gaming"].includes(data.profile);
            target.leftInset=target.barVisible && data.position==="left" ? 52 : 0;
            const edge=findChild(target,"dashboard-edge-window");
            const area=findChild(edge.contentItem,"dashboard-edge-area");
            const onBar=target.topBarActive;
            compare(edge.visible,!onBar);
            if (!onBar) {
                compare(edge.implicitHeight,data.position==="left" && data.profile==="multimedia" ? 34 : 8);
                verify(area.width>0);
                verify(area.x>=0 && area.x+area.width<=edge.width);
                verify(area.x<=edge.width/2 && area.x+area.width>=edge.width/2);
                mouseMove(area,area.width+50,area.height+50);
            } else mouseMove(target,-80,80);
            wait(40);
            opened.clear();target.dashboardOpen=false;
            if (onBar) mouseMove(target,target.width/2,1);
            else mouseMove(area,area.width/2,1);
            tryCompare(opened,"count",1,700);
            verify(target.dashboardOpen);
            wait(40);compare(opened.count,1);
            if (onBar) mouseMove(target,-80,80);
            else mouseMove(area,area.width+50,area.height+50);
        }
    }
}
