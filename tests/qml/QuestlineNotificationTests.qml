import QtQuick
import QtTest
import Quickshell
import Quickshell.Services.Notifications
import "../../configs/spectrum-shell" as Shell
import "../../configs/spectrum-shell/NotificationStyle.js" as NotificationStyle

Scope {
    id:shell
    property var colors:({surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#ffbb00"})
    property var notificationHistory:[]
    property int nextToastId:0
    property alias toastNotifications:toastModel
    property string backendDir:Quickshell.env("SPECTRUM_NOTIFICATION_TEST_DIR")
    property var fixtures:[]
    property var updatesRequests:[]
    function openOnFocused(method){updatesRequests=updatesRequests.concat([method]);}
    ListModel {id:toastModel}
    property bool nativeMode:false
    property var notificationServer:nativeMode ? liveNotificationServer : fakeNotificationServer
    QtObject {id:fakeNotificationServer;property var trackedNotifications:({values:[]})}
    NotificationServer {
        id:liveNotificationServer
        actionsSupported:true
        persistenceSupported:true
        onNotification:notification=>shell.acceptNotification(notification)
    }
    QtObject {
        id:testTheme
        property var colors:shell.colors
        property string fontFamily:"sans-serif"
        property int fontSize:14
        property string barStyle:"full"
        property string barPosition:"top"
        property bool animationsEnabled:false
        property bool widgetBounceEnabled:false
    }
    Component {
        id:fakeNotification
        QtObject {
            property int id:0
            property bool tracked:false
            property string appName:"Questline"
            property string summary:"Hydration reminder"
            property string body:"3/12 today"
            property string appIcon:""
            property var hints:({"x-questline-kind":"hydration","x-questline-reminder-token":"reminder"})
            property var actions:[]
            property int expireTimeout:10
            signal closed(int reason)
            function dismiss(){closed(NotificationCloseReason.Dismissed);notificationServer.trackedNotifications={values:notificationServer.trackedNotifications.values.filter(item=>item.id!==id)};}
            function expire(){closed(NotificationCloseReason.Expired);notificationServer.trackedNotifications={values:notificationServer.trackedNotifications.values.filter(item=>item.id!==id)};}
        }
    }
    function notificationIcon(notification){return notification.appIcon;}
    function makeNotification(id,patch) {
        const item=fakeNotification.createObject(shell,Object.assign({id:id},patch || {}));
        fixtures=fixtures.concat([item]);notificationServer.trackedNotifications={values:notificationServer.trackedNotifications.values.concat([item])};acceptNotification(item);return item;
    }
    // SHELL_NOTIFICATION_METHODS
    FloatingWindow {
        id:window
        implicitWidth:420;implicitHeight:1000
        visible:true
        Column {
            id:stack;width:400
            Repeater {
                id:cards
                model:toastModel
                Shell.NotificationToast {
                    id:card
                    required property var model
                    theme:testTheme
                    notification:model
                    presented:true
                    width:stack.width
                    onDismissed:shell.removeToast(model.toastId)
                    onActionInvoked:identifier=>shell.invokeNotificationAction(model.notificationId,identifier)
                    Timer {
                        interval:Math.max(1,card.model.expiresAt-Date.now())
                        running:card.revealed && card.model.expiresAt>0
                        onTriggered:card.revealed=false
                    }
                }
            }
        }
    }
    Shell.NotificationCenter {
        id:center
        theme:testTheme
        notificationModel:notificationServer.trackedNotifications
        history:shell.notificationHistory
        doNotDisturb:false
        expanded:false
        topInset:8
        onQuestlineDrinkRequested:item=>shell.invokeNotificationAction(item.id,"questline-drink")
        onUpdatesRequested:item=>shell.invokeNotificationAction(item.id,"spectrum-open-updates")
    }
    TestCase {
        name:"QuestlineNotifications"
        when:true
        onCompletedChanged:if(completed){console.log("Questline notifications:",qtest_results.passCount,"passed",qtest_results.failCount,"failed");Qt.quit();}
        function settle(){tryVerify(()=>questlineNotificationActions.job===null && questlineNotificationActions.queue.length===0,5000);wait(30);}
        function init(){shell.updatesRequests=[];settle();toastModel.clear();shell.nativeMode=qtest_results.functionName.startsWith("test_native_");if(!shell.nativeMode)fakeNotificationServer.trackedNotifications={values:[]};shell.notificationHistory=[];shell.colors={surface:"#222222",surface_alt:"#333333",foreground:"#eeeeee",muted:"#aaaaaa",accent:"#ffbb00"};}
        function cleanup(){center.expanded=false;if(shell.nativeMode)for(const item of Array.from(liveNotificationServer.trackedNotifications.values))item.dismiss();settle();toastModel.clear();if(!shell.nativeMode)fakeNotificationServer.trackedNotifications={values:[]};for(const item of shell.fixtures)item.destroy();shell.fixtures=[];}
        function test_purple_and_blue_remain_fixed_after_palette_changes(){
            try {
            makeNotification(1,{summary:"The Swarm",hints:{"x-questline-kind":"swarm"},expireTimeout:10000});makeNotification(2);
            wait(50);compare(cards.itemAt(0).color,"#180a26");compare(cards.itemAt(1).color,"#071930");
            shell.colors={surface:"#ff0000",surface_alt:"#00ff00",foreground:"#111111",muted:"#222222",accent:"#ff00ff"};wait(30);
            compare(cards.itemAt(0).palette.accent,"#a855f7");compare(cards.itemAt(1).palette.accent,"#38bdf8");compare(cards.itemAt(1).color,"#071930");
            }catch(e){console.warn("fixed_colors",e.message,String(e.stack));throw e;}
        }
        function test_notification_center_keeps_blue_and_can_record_a_drink(){
            try {
            makeNotification(55,{hints:{"x-questline-kind":"hydration","x-questline-reminder-token":"center-reminder"}});center.expanded=true;wait(100);
            const list=findChild(center,"notification-center-items");list.forceLayout();wait(40);
            const entry=list.itemAtIndex(0);verify(entry!==null);compare(entry.color,"#071930");
            mouseClick(findChild(entry,"notification-center-drink"));settle();compare(toastModel.count,0);compare(notificationServer.trackedNotifications.values.length,0);
            }catch(e){console.warn("notification_center",e.message,String(e.stack));throw e;}
        }
        function test_legacy_icons_and_ordinary_notifications_are_classified_correctly(){
            compare(NotificationStyle.kind({appName:"Questline",appIcon:"/icons/notification_swarm.png"}),"swarm");
            compare(NotificationStyle.kind({appName:"Questline",appIcon:"/icons/hydration.png",summary:"Hydration Reminder"}),"hydration");
            compare(NotificationStyle.kind({appName:"Other",hints:{"x-questline-kind":"hydration"}}),"");
            compare(NotificationStyle.palette({appName:"Other"},shell.colors).accent,shell.colors.accent);
        }
        function test_water_remains_visible_past_five_seconds_and_has_drink_button(){
            try {
            makeNotification(3);wait(50);compare(toastModel.get(0).expiresAt,0);
            const button=findChild(cards.itemAt(0),"notification-actions").itemAt(0);compare(button.label,"Drink");
            wait(5200);compare(toastModel.count,1);verify(cards.itemAt(0).revealed);
            }catch(e){console.warn("water_persistent",e.message,String(e.stack));throw e;}
        }
        function test_drink_button_records_once_and_closes_only_its_reminder(){
            try {
            makeNotification(4);wait(50);const button=findChild(cards.itemAt(0),"notification-actions").itemAt(0);
            mouseClick(button);mouseClick(button);settle();compare(toastModel.count,0);compare(notificationServer.trackedNotifications.values.length,0);
            }catch(e){console.warn("drink_button",e.message,String(e.stack));throw e;}
        }
        function test_drink_errors_keep_the_reminder_open_for_retry(){
            makeNotification(5,{hints:{"x-questline-kind":"hydration","x-questline-reminder-token":"force-error"}});invokeNotificationAction(5,"questline-drink");settle();compare(toastModel.count,1);verify(toastModel.get(0).body.includes("Try again"));compare(toastModel.get(0).actionBusy,false);
        }
        function test_ctrl_space_dismisses_without_drinking(){makeNotification(6);dismissLatestNotification();settle();compare(toastModel.count,0);compare(notificationServer.trackedNotifications.values.length,0);}
        function test_replacement_expires_old_reminder_without_acknowledging_it(){
            const old=makeNotification(7);makeNotification(8,{body:"4/12 today"});settle();compare(toastModel.count,1);compare(toastModel.get(0).notificationId,8);
        }
        function test_many_other_notifications_do_not_evict_water(){
            makeNotification(9);for(let i=20;i<34;i++)makeNotification(i,{appName:"Other",summary:"A message",hints:{},expireTimeout:10000});compare(toastModel.count,10);verify(Array.from({length:toastModel.count},(_,i)=>toastModel.get(i)).some(item=>item.notificationId===9));
        }
        function nativeNotification(kind,token,body) {
            Quickshell.execDetached(["notify-send","--app-name=Questline","--expire-time=0","--hint=string:x-questline-kind:"+kind,"--hint=string:x-questline-reminder-token:"+token,kind==="swarm"?"Notification Swarm":"Hydration reminder",body]);
        }
        function test_native_dbus_drink_action_closes_the_real_notification(){
            try {
            nativeNotification("hydration","native-drink","3/12 today");tryCompare(toastModel,"count",1,3000);wait(50);
            compare(toastModel.get(0).expiresAt,0);compare(cards.itemAt(0).palette.accent,"#38bdf8");
            mouseClick(findChild(cards.itemAt(0),"notification-actions").itemAt(0));settle();tryCompare(toastModel,"count",0,3000);compare(Array.from(liveNotificationServer.trackedNotifications.values).length,0);
            }catch(e){console.warn("native_drink",e.message,String(e.stack));throw e;}
        }
        function test_native_dbus_ctrl_space_dismisses_without_drinking(){
            nativeNotification("hydration","native-dismiss","3/12 today");tryCompare(toastModel,"count",1,3000);dismissLatestNotification();settle();compare(toastModel.count,0);compare(Array.from(liveNotificationServer.trackedNotifications.values).length,0);
        }
        function test_native_dbus_refresh_replaces_the_existing_card(){
            nativeNotification("hydration","native-refresh","3/12 today");tryCompare(toastModel,"count",1,3000);
            nativeNotification("hydration","native-refresh","4/12 today");tryVerify(()=>toastModel.count===1 && toastModel.get(0).body==="4/12 today",3000);compare(Array.from(liveNotificationServer.trackedNotifications.values).length,1);
        }
        function test_native_stable_update_button_opens_widget_once(){
            Quickshell.execDetached(["notify-send","--app-name=SpectrumOS Updates","--expire-time=15000","--hint=string:x-spectrumos-kind:stable-updates","Fresh loot on Stable","1 SpectrumOS package update is ready."]);
            tryCompare(toastModel,"count",1,3000);wait(50);
            const button=findChild(cards.itemAt(0),"notification-actions").itemAt(0);compare(button.label,"Open Updates");
            mouseClick(button);wait(30);compare(shell.updatesRequests.length,1);compare(shell.updatesRequests[0],"openUpdates");compare(toastModel.count,0);
        }
        function test_stable_update_center_button_opens_widget(){
            makeNotification(80,{appName:"SpectrumOS Updates",summary:"Fresh loot on Stable",hints:{"x-spectrumos-kind":"stable-updates"},expireTimeout:15000});
            center.expanded=true;wait(100);const list=findChild(center,"notification-center-items");list.forceLayout();wait(40);
            const entry=list.itemAtIndex(0);verify(entry!==null);const button=findChild(entry,"notification-center-open-updates");verify(button.visible);
            mouseClick(button);wait(30);compare(shell.updatesRequests.length,1);compare(shell.updatesRequests[0],"openUpdates");compare(toastModel.count,0);
        }
        function test_z_preview(){
            const file=Quickshell.env("SPECTRUM_NOTIFICATION_SCREENSHOT");if(!file)return;
            makeNotification(70,{summary:"Notification Swarm",body:"Your backlog called. It would like a word.",hints:{"x-questline-kind":"swarm"},expireTimeout:10000});makeNotification(71);wait(150);
            let done=false;stack.grabToImage(result=>{result.saveToFile(file);done=true;});tryVerify(()=>done,5000);
        }
        function test_hydration_progress_is_blue_and_expires(){
            makeNotification(40);makeNotification(41,{summary:"Drink recorded",hints:{"x-questline-kind":"hydration-progress"},expireTimeout:40});wait(150);compare(toastModel.count,0);
        }
    }
}
