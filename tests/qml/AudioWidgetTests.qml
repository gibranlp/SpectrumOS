import QtQuick
import QtTest
import Quickshell
import "../../configs/spectrum-shell" as Shell
Scope {
 QtObject { id: audio; property real volume:0.42; property bool muted:false }
 QtObject { id: node; property string name:"test-output"; property bool isSink:true;property bool isStream:false;property bool ready:true;property var audio:audio }
 QtObject {
  id:theme
  property var colors:({foreground:"#eeeeee",background:"#111111",surface:"#222222",surface_alt:"#333333",accent:"#66ccee",muted:"#aaaaaa",accent_alt:"#eeccee",error:"#ff0000"})
  property string fontFamily:"sans-serif"
  property int fontSize:14
  property bool actionBusy:false
  property string actionError:""
  property bool animationsEnabled:false
  property bool widgetBounceEnabled:false
  property bool gamingActive:false
  property string barPosition:"left"
  property string barStyle:"full"
  property int panelLeftInset:52
  property int panelTopInset:0
  property bool volumeAvailable:false
  property bool volumeMuted:false
  property var volumeNode:node
  property var audioNodes:[]
  property int volumePercent:Math.round(audio.volume*100)
  property var audioDevices:({available:true,volume:"42%",sinks:[{id:"1",name:"test-output",label:"Test output",default:true,volume_percent:42,volume:"42%",muted:false},{id:"2",name:"test-2",label:"Second output",volume_percent:42},{id:"3",name:"test-3",label:"Third output",volume_percent:42},{id:"4",name:"test-4",label:"Fourth output",volume_percent:42}],sources:[]})
  property var media:({available:false,playing:false,title:"",artist:"",canSeek:false})
  property var mediaPlayers:[]
  property bool mediaChoiceRequired:false
  property string mediaPendingAction:""
  property var waveSamples:[]
  property var overview:({font_families:[]})
  property var keyboardLayout:({layouts:[],label:"Test"})
  property var network:({available:false,profiles:[],wifi:{},ethernet:{},networks:[]})
  property var performance:({available:false,modes:[]})
  property bool performancePending:false
  function backend(name) { return "/usr/bin/true"; }
  property var volumeChanges: []
  property bool audioVolumeBusy: false
  function setAudioVolume(kind,target,percent) { volumeChanges=volumeChanges.concat([[kind,target,percent]]); }
  function refreshControls() {}
  function dismissMediaChoice() {}
  function runAction(command) {}
 }
 Shell.BarWidget { id:panel;targetScreen:Quickshell.screens[0];theme:theme;expanded:true }
 TestCase {
  name:"FullAudio"
  when:true
  onCompletedChanged:if(completed){console.log("Full audio:",qtest_results.passCount,"passed",qtest_results.failCount,"failed");Qt.quit();}
  function test_device_drag_in_scroll_panel() {
   const repeater=findChild(panel,"audio-output-devices");
   tryVerify(() => !!repeater.itemAt(0),3000);
   const slider=findChild(repeater.itemAt(0),"device-volume");
   wait(150);
   console.log("Slider geometry",slider.objectName,slider.width,slider.height,JSON.stringify(slider.mapToItem(null,0,0)));
   mousePress(slider,slider.width*0.3,slider.height/2);
   mouseMove(slider,slider.width*0.75,slider.height/2+20,40);
   console.log("Press state",slider.objectName,slider.pressed,findChild(panel,"audio-scroll").interactive,JSON.stringify(theme.volumeChanges));
   verify(slider.pressed);
   verify(!findChild(panel,"audio-scroll").interactive);
   verify(theme.volumeChanges[theme.volumeChanges.length-1][2]>60);
   mouseRelease(slider,slider.width*0.75,slider.height/2+20);
   verify(findChild(panel,"audio-scroll").interactive);
  }
  function test_master_drag_in_scroll_panel() {
   const slider=findChild(panel,"master-volume");
   wait(150);
   console.log("Master state",slider.enabled,slider.width,slider.height,slider.value);
   console.log("Slider geometry",slider.objectName,slider.width,slider.height,JSON.stringify(slider.mapToItem(null,0,0)));
   mousePress(slider,slider.width*0.3,slider.height/2);
   mouseMove(slider,slider.width*0.75,slider.height/2+20,40);
   console.log("Master dragged",slider.pressed,slider.value,audio.volume);
   console.log("Press state",slider.objectName,slider.pressed,findChild(panel,"audio-scroll").interactive,JSON.stringify(theme.volumeChanges));
   verify(slider.pressed);
   verify(theme.volumeChanges[theme.volumeChanges.length-1][2]>60);
   verify(!findChild(panel,"audio-scroll").interactive);
   mouseRelease(slider,slider.width*0.75,slider.height/2+20);
   verify(findChild(panel,"audio-scroll").interactive);
  }
 }
}
