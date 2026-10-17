import QtQuick
import QtTest
import "../../configs/spectrum-shell" as Shell

TestCase {
    id: tests
    name: "HotKey"
    visible: true
    width: 640; height: 550
    when: windowShown
    QtObject {
        id: theme
        property var colors: ({foreground:"#eeeeee",background:"#111111",surface_alt:"#333333",accent:"#66ccee",muted:"#aaaaaa"})
        property string fontFamily: "monospace"
        property int fontSize: 12
    }
    QtObject {
        id: backend
        property bool busy: false
        property var rules: []
        property string error: ""
        property var commands: []
        function command(args) { commands = commands.concat([args]); }
    }
    Shell.HotKeyEditor { id: editor; anchors.fill: parent; theme: theme; backend: backend }
    function init() { editor.clearForm(); backend.commands=[]; backend.busy=false; backend.rules=[]; }
    function test_save_sequence_interval_and_shortcut() {
        findChild(editor,"hotkey-sequence").text="234";
        findChild(editor,"hotkey-interval").text="50";
        findChild(editor,"hotkey-shortcut").text="Control+Shift+2";
        const save=findChild(editor,"hotkey-save");
        verify(save.enabled); save.clicked();
        compare(backend.commands.length,1);
        const rule=JSON.parse(backend.commands[0][1]);
        compare(rule.keys,"234"); compare(rule.interval_ms,50); compare(rule.shortcut,"Control+Shift+2");
    }
    function test_actual_shortcut_capture_and_named_key_selection() {
        const field=findChild(editor,"hotkey-shortcut");
        field.forceActiveFocus(); keyClick(Qt.Key_2,Qt.ControlModifier|Qt.ShiftModifier);
        compare(field.text,"Control+Shift+2");
        field.text="";
        keyClick(Qt.Key_At,Qt.ControlModifier|Qt.ShiftModifier);
        compare(field.text,"Control+Shift+2");
        field.text="";
        keyClick(Qt.Key_C,Qt.ShiftModifier);
        compare(field.text.toLowerCase(),"c");
        const selector=findChild(editor,"hotkey-key-selector");
        selector.currentIndex=1; selector.activated(1);
        compare(findChild(editor,"hotkey-sequence").text,"[Enter]");
    }
    function test_record_single_key_and_named_key() {
        const field=findChild(editor,"hotkey-shortcut");
        const record=findChild(editor,"hotkey-record-shortcut");
        record.clicked(); keyClick(Qt.Key_2);
        compare(field.text,"2"); verify(!editor.recordingShortcut);
        record.clicked(); keyClick(Qt.Key_Return);
        compare(field.text,"Enter"); verify(!editor.recordingShortcut);
        record.clicked(); keyClick(Qt.Key_F2);
        compare(field.text,"F2");
        record.clicked(); keyClick(Qt.Key_C,Qt.ShiftModifier);
        compare(field.text,"Shift+C");
        editor.editRule({id:"",keys:"2",interval_ms:50,shortcut:"2"});
        findChild(editor,"hotkey-save").clicked();
        compare(JSON.parse(backend.commands[0][1]).shortcut,"2");
    }
    function test_selector_popup_and_rows_use_theme_colors() {
        const selector=findChild(editor,"hotkey-key-selector");
        compare(findChild(editor,"hotkey-selector-background").color,theme.colors.surface_alt);
        compare(findChild(editor,"hotkey-selector-text").color,theme.colors.foreground);
        selector.popup.open();
        wait(30);
        compare(findChild(selector.popup,"hotkey-selector-popup-background").color,theme.colors.surface_alt);
        tryVerify(() => selector.popup.contentItem.itemAtIndex(1) !== null);
        const option=selector.popup.contentItem.itemAtIndex(1);
        const label=findChild(option,"hotkey-option-text-1");
        verify(label !== null);
        compare(label.color,theme.colors.foreground);
        mouseClick(option,option.width/2,option.height/2);
        tryCompare(findChild(editor,"hotkey-sequence"),"text","[Enter]");
        selector.popup.close();
    }
    function test_mouse_click_add_registers_shortcut_once() {
        editor.editRule({id:"",keys:"2",interval_ms:50,shortcut:"Ctrl+Shift+2"});
        const save=findChild(editor,"hotkey-save");
        mouseClick(save,save.width/2,save.height/2);
        compare(backend.commands.length,1);
        const rule=JSON.parse(backend.commands[0][1]);
        compare(rule.keys,"2"); compare(rule.shortcut,"Ctrl+Shift+2");
    }
    function test_edit_preserves_rule_identity_and_stop_all_is_direct() {
        editor.editRule({id:"a".repeat(32),keys:"2",interval_ms:50,shortcut:"CTRL + SHIFT + 2"});
        findChild(editor,"hotkey-save").clicked();
        compare(JSON.parse(backend.commands[0][1]).id,"a".repeat(32));
        findChild(editor,"hotkey-stop-all").clicked();
        compare(backend.commands[1][0],"stop-all");
    }
    function test_saved_row_actions_are_direct() {
        backend.rules=[{id:"sample",keys:"234",interval_ms:50,shortcut:"Control+Shift+2",active:false}];
        tryVerify(() => findChild(editor,"hotkey-toggle-sample") !== null);
        wait(30);
        const start=findChild(editor,"hotkey-toggle-sample");
        mouseClick(start,start.width/2,start.height/2);
        compare(backend.commands[0][0],"toggle"); compare(backend.commands[0][1],"sample");
        findChild(editor,"hotkey-edit-sample").clicked();
        compare(findChild(editor,"hotkey-sequence").text,"234");
        findChild(editor,"hotkey-remove-sample").clicked();
        compare(backend.commands[1][0],"remove"); compare(backend.commands[1][1],"sample");
    }
    function test_invalid_interval_and_busy_disable_saving() {
        editor.editRule({id:"a".repeat(32),keys:"2",interval_ms:5,shortcut:"CTRL + SHIFT + 2"});
        verify(!findChild(editor,"hotkey-save").enabled);
        findChild(editor,"hotkey-interval").text="50";
        backend.busy=true;
        verify(!findChild(editor,"hotkey-save").enabled);
    }
}
