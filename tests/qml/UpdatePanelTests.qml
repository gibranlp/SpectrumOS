import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell

Scope {
    QtObject {
        id: theme
        property bool animationsEnabled: false
        property bool widgetBounceEnabled: false
        property string barStyle: "full"
        property string barPosition: "top"
        property string fontFamily: "monospace"
        property int fontSize: 13
        property bool checkingStableUpdates: false
        property var stableUpdates: ({})
        property var colors: ({surface:"#232029",surface_alt:"#2e2c34",foreground:"#eff3fa",muted:"#a6afbe",accent:"#b293e6",background:"#15131a"})
        function checkStableUpdates() {}
    }
    Shell.UpdatePanel {
        id: panel
        targetScreen: Quickshell.screens[0]
        theme: theme
        backendDir: "/unused-test-backend"
        expanded: true
    }
    Shell.StableUpdateMonitor {id:monitor;backendDir:Quickshell.env("SPECTRUM_UPDATE_TEST_BACKEND")}
    TestCase {
        name: "UpdatePanel"
        when: true
        onCompletedChanged: if(completed){console.log("Update panel:",qtest_results.passCount,"passed",qtest_results.failCount,"failed");Qt.quit();}
        function cleanup() {if(qtest_results.failed)console.warn("Failed update test:",qtest_results.functionName);}
        function visual(root,name) {
            if(!root)return null;
            if(root.objectName===name)return root;
            for(const child of root.children || []) {const found=visual(child,name);if(found)return found;}
            return null;
        }
        function item(name) {return findChild(panel,name) || visual(panel.contentItem,name);}
        function list() {return item("update-package-list");}
        function init() {
            theme.stableUpdates={checked_at:1,eligible:true,error:"",inventory_error:"",installed_packages:[
                {name:"spectrum-desktop",installed:"1.0.0-27"},{name:"spectrum-theme",installed:"1.0.0-5"}
            ],packages:[]};
            panel.expanded=true;wait(30);
        }
        function test_all_installed_versions_show_with_no_updates() {
            try {
            compare(list().rows.length,2);
            compare(list().rows[0].installed,"1.0.0-27");
            compare(list().rows[1].installed,"1.0.0-5");
            const row=item("update-package-spectrum-desktop");
            compare(findChild(row,"installed-version").text,"1.0.0-27");
            verify(!findChild(row,"available-version").visible);
            } catch(error) {console.warn("test_all_installed_versions_show_with_no_updates",error.message,String(error.stack));throw error;}
        }
        function test_newer_version_appears_beside_current_version() {
            try {
            theme.stableUpdates=Object.assign({},theme.stableUpdates,{packages:[{name:"spectrum-desktop",installed:"1.0.0-27",available:"1.0.0-28"}]});wait(30);
            const row=item("update-package-spectrum-desktop");
            compare(findChild(row,"installed-version").text,"1.0.0-27");
            verify(findChild(row,"available-version").visible);
            compare(findChild(row,"available-version").text,"1.0.0-28");
            compare(findChild(row,"available-version").color,theme.colors.accent);
            const preview=Quickshell.env("SPECTRUM_UPDATE_PREVIEW");
            if(preview)grabImage(panel.contentItem).save(preview);
            } catch(error) {console.warn("test_newer_version_appears_beside_current_version",error.message,String(error.stack));throw error;}
        }
        function test_compact_inventory_leaves_room_for_update_info() {
            theme.stableUpdates=Object.assign({},theme.stableUpdates,{installed_packages:Array.from({length:9},(_,i)=>({name:"spectrum-package-"+i,installed:"1.0.0-1"}))});
            panel.refresh();tryCompare(panel,"ready",true,3000);wait(50);
            verify(list().height<250);
            const card=item("update-card");
            compare(card.height,Math.min(900,panel.height-panel.topInset-24));
            verify(card.height>720);
            const safety=item("update-safety-text");
            verify(safety.mapToItem(card,0,0).y<card.height-200);
            const preview=Quickshell.env("SPECTRUM_UPDATE_PREVIEW");
            if(preview)grabImage(panel.contentItem).save(preview+"-nine.png");
        }
        function test_monitor_inventory_refresh_keeps_fresh_update_result() {
            monitor.refresh();
            tryVerify(()=>monitor.status.checked_at===20,3000);
            wait(300);
            compare(monitor.status.packages.length,1);
            compare(monitor.status.packages[0].available,"2");
            compare(monitor.status.installed_packages[0].installed,"1");
            compare(monitor.status.checked_at,20);
        }
        function test_old_cached_update_disappears_after_installation() {
            theme.stableUpdates=Object.assign({},theme.stableUpdates,{packages:[{name:"spectrum-desktop",installed:"1.0.0-26",available:"1.0.0-27"}]});wait(20);
            compare(list().rows[0].available,"");
        }
        function test_offline_and_non_stable_keep_installed_versions() {
            try {
            theme.stableUpdates=Object.assign({},theme.stableUpdates,{eligible:false,error:"Offline"});wait(20);
            compare(list().rows.length,2);
            verify(item("update-package-spectrum-theme").visible);
            } catch(error) {console.warn("test_offline_and_non_stable_keep_installed_versions",error.message,String(error.stack));throw error;}
        }
        function test_long_versions_wrap_inside_package_row() {
            try {
            theme.stableUpdates=Object.assign({},theme.stableUpdates,{installed_packages:[{name:"spectrum-xdg-desktop-portal-hyprland",installed:"1.4.1.r30.g0204ffb-1"}],packages:[{name:"spectrum-xdg-desktop-portal-hyprland",installed:"1.4.1.r30.g0204ffb-1",available:"1.4.1.r31.gabcdef-1"}]});wait(30);
            const row=item("update-package-spectrum-xdg-desktop-portal-hyprland");
            const version=findChild(row,"available-version");
            verify(version.width>0);verify(row.height>=version.height);
            verify(version.mapToItem(row,version.width,0).x<=row.width);
            } catch(error) {console.warn("test_long_versions_wrap_inside_package_row",error.message,String(error.stack));throw error;}
        }
        function test_package_list_scrolls_while_update_actions_remain_accessible() {
            theme.stableUpdates=Object.assign({},theme.stableUpdates,{installed_packages:Array.from({length:20},(_,i)=>({name:"spectrum-package-"+i,installed:"1.0.0-1"}))});wait(40);
            compare(list().rows.length,20);
            verify(list().height<500);
            panel.refresh();tryCompare(panel,"ready",true,3000);
            verify(panel.planText.includes("SpectrumOS 1.1"));
            const preview=Quickshell.env("SPECTRUM_UPDATE_PREVIEW");
            if(preview)grabImage(panel.contentItem).save(preview+"-scroll.png");
        }
    }
}
