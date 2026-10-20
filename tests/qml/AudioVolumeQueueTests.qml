import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "../../configs/spectrum-shell" as Shell
Scope {
 id:root
 property var receipts:[]
 property int errors:0
 Shell.AudioVolumeManager { id:manager;program:Quickshell.env("SPECTRUM_AUDIO_TEST_COMMAND");onFailed:root.errors++ }
 Process { id:reader;command:["cat",Quickshell.env("SPECTRUM_AUDIO_TEST_LOG")];stdout:StdioCollector {onStreamFinished:root.receipts=text.trim().split("\n").filter(Boolean).map(line=>JSON.parse(line))} }
 TestCase {
  name:"VolumeQueue"
  when:true
  onCompletedChanged:if(completed){console.log("Volume queue:",qtest_results.passCount,"passed",qtest_results.failCount,"failed");Qt.quit();}
  function test_last_value_survives_busy_backend() {
   manager.setVolume("sink","output",10);
   wait(40);
   for(let value=11;value<=83;value++)manager.setVolume("sink","output",value);
   manager.setVolume("source","microphone",37);
   tryCompare(manager,"busy",false,3000);
   reader.running=true;tryVerify(()=>root.receipts.length>=2,3000);
   const sinks=root.receipts.filter(args=>args[0]==="set-sink-volume");
   const sources=root.receipts.filter(args=>args[0]==="set-source-volume");
   compare(sinks[sinks.length-1],["set-sink-volume","output","83%"]);
   compare(sources[sources.length-1],["set-source-volume","microphone","37%"]);
   verify(root.receipts.length<=4);
   compare(root.errors,0);
  }
 }
}
