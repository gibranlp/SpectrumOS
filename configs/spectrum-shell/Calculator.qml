import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: calculator
    required property var theme
    required property string backendDir
    signal closeRequested()
    property string result: ""
    property string error: ""
    property var steps: []
    property var history: []
    property string submitted: ""
    property string submittedInput: ""
    property bool advanced: false
    property string advancedPage: "Conversions"
    readonly property bool converting: advanced && advancedPage === "Conversions"
    property bool degrees: false
    property int conversionCategory: 0
    property string fromUnit: "m"
    property string toUnit: "cm"
    property string resultUnit: ""
    property string submittedUnit: ""
    readonly property var conversionGroups: [
        {name:"Length", units:["m","cm","mm","km","in","ft","yd","mi","nmi"]},
        {name:"Mass", units:["kg","g","mg","tonne","lb","oz"]},
        {name:"Temperature", units:["°C","°F","K"]},
        {name:"Area", units:["m^2","cm^2","km^2","ft^2","acre","hectare"]},
        {name:"Volume", units:["L","mL","m^3","cm^3","gallon","pint"]},
        {name:"Time", units:["s","min","h","day","week","year"]},
        {name:"Speed", units:["m/s","km/h","mph","knot"]},
        {name:"Data", units:["bit","byte","kB","MB","GB","TB","KiB","MiB","GiB","TiB"]},
        {name:"Energy", units:["J","kJ","cal","kcal","Wh","kWh","eV"]},
        {name:"Power", units:["W","kW","MW","horsepower"]},
        {name:"Pressure", units:["Pa","kPa","MPa","bar","atm","psi"]},
        {name:"Angle", units:["rad","degree","arcmin","arcsec"]},
        {name:"Frequency", units:["Hz","kHz","MHz","GHz"]},
        {name:"Force", units:["N","kN","lbf"]},
        {name:"Currency", units:["MXN","USD","EUR","GBP","CAD","JPY","CHF"]},
        {name:"Custom units", units:[]}
    ]
    readonly property var conversionUnits: conversionGroups[conversionCategory].units
    readonly property bool busy: evaluation.running
    spacing: 8

    function activate(): void { Qt.callLater(() => converting ? conversionValue.forceActiveFocus() : input.forceActiveFocus()); }
    function evaluate(unitHint = ""): void {
        if (busy || !input.text.trim()) return;
        error = "";
        submittedUnit = unitHint;
        submittedInput = input.text.trim();
        submitted = JSON.stringify({expression: submittedInput, steps: steps});
        evaluation.exec([backendDir + "/spectrum-shell-tools", "calculate-json", submitted]);
    }
    function press(key): void {
        if (busy) return;
        error = "";
        if (key === "=") { evaluate(); return; }
        if (key === "AC") { input.text = ""; result = ""; resultUnit = ""; steps = []; activate(); return; }
        if (key === "Copy") { if (result) Quickshell.execDetached(["wl-copy", result + (resultUnit ? " " + resultUnit : "")]); return; }
        if (key === "⌫") {
            if (input.selectedText) input.remove(input.selectionStart, input.selectionEnd);
            else if (input.cursorPosition > 0) input.remove(input.cursorPosition - 1, input.cursorPosition);
        } else if (key === "±") {
            input.text = input.text.trim() ? "(-(" + input.text + "))" : result ? "(-ans)" : "(-0)";
            input.cursorPosition = input.length;
        } else {
            const operator = ["+", "−", "×", "÷"].includes(key);
            if (operator && !input.text.trim() && result) {
                input.text = "ans ";
                input.cursorPosition = input.length;
            }
            input.insert(input.cursorPosition, key === "Ans" ? "ans" : key);
        }
        activate();
    }
    function recall(entry): void {
        if (busy) return;
        result = entry.result;
        resultUnit = entry.unit || "";
        steps = entry.steps.slice();
        error = "";
        input.text = "";
        activate();
    }
    function setCategory(index): void {
        conversionCategory = index;
        const units = conversionUnits;
        fromUnit = units.length ? units[0] : "m";
        toUnit = units.length > 1 ? units[1] : "cm";
        error = "";
    }
    function convert(): void {
        if (busy) return;
        const value = conversionValue.text.trim();
        const source = fromUnit.trim();
        const target = toUnit.trim();
        if (!value || !source || !target) { error = qsTranslate("Spectrum", "Enter a value and both units"); return; }
        input.text = "(" + value + ") " + source + " -> " + target;
        evaluate(conversionGroups[conversionCategory].name === "Temperature" && target !== "K" ? target : "");
    }
    function scientific(key): void {
        if (busy) return;
        if (key === "Ans") { press("Ans"); return; }
        if (key === "π" || key === "e") { press(key === "π" ? "pi" : "e"); return; }
        const value = input.text.trim() || (result ? "ans" : "");
        if (key === "xʸ") { input.text = (value || "ans") + " ^ "; activate(); return; }
        if (!value) { input.text = key === "x²" || key === "1/x" ? "(" : key + "("; activate(); return; }
        if (key === "x²") input.text = "(" + value + ") ^ 2";
        else if (key === "1/x") input.text = "1 / (" + value + ")";
        else if (["sin","cos","tan"].includes(key) && degrees) input.text = key + "((" + value + ") degree)";
        else if (["asin","acos","atan"].includes(key) && degrees) input.text = key + "(" + value + ") -> degree";
        else input.text = key + "(" + value + ")";
        evaluate();
    }
    Process {
        id: evaluation
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const response = JSON.parse(text);
                    if (!response.ok) { calculator.error = response.error || "Invalid expression"; return; }
                    calculator.result = response.result;
                    calculator.resultUnit = calculator.submittedUnit;
                    calculator.steps = response.steps;
                    calculator.history = [{expression: calculator.submittedInput, result: response.result, unit: calculator.resultUnit, steps: response.steps}].concat(calculator.history).slice(0, 12);
                    input.text = "";
                } catch (error) { calculator.error = qsTranslate("Spectrum", "Calculator returned an invalid response"); }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && !calculator.error) calculator.error = qsTranslate("Spectrum", "Could not calculate the result");
            if (calculator.visible) calculator.activate();
        }
    }
    ShellButton {
        Layout.fillWidth: true
        label: calculator.advanced ? qsTranslate("Spectrum", "← Normal calculator") : qsTranslate("Spectrum", "Conversions & scientific →")
        enabled: !calculator.busy
        fontFamily: calculator.theme.fontFamily
        fontSize: calculator.theme.fontSize
        backgroundColor: calculator.theme.colors.surface_alt
        foregroundColor: calculator.theme.colors.foreground
        onClicked: { calculator.advanced = !calculator.advanced; calculator.activate(); }
    }
    Rectangle {
        Layout.fillWidth: true
        visible: !calculator.converting
        implicitHeight: 46
        radius: 9
        color: calculator.theme.colors.background
        Text {
            anchors { fill: parent; margins: 12 }
            visible: !input.text
            text: calculator.result ? qsTranslate("Spectrum", "Continue with +, −, ×, ÷ or Ans") : qsTranslate("Spectrum", "Enter a calculation")
            verticalAlignment: Text.AlignVCenter
            color: calculator.theme.colors.muted
            font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize }
        }
        TextInput {
            id: input
            objectName: "calculator-input"
            anchors { fill: parent; margins: 12 }
            enabled: !calculator.busy
            activeFocusOnTab: true
            selectByMouse: true
            verticalAlignment: TextInput.AlignVCenter
            color: calculator.theme.colors.foreground
            selectionColor: calculator.theme.colors.accent
            font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize }
            Accessible.name: qsTranslate("Spectrum", "Calculation")
            Keys.onReturnPressed: calculator.evaluate()
            Keys.onEnterPressed: calculator.evaluate()
            Keys.onEscapePressed: calculator.closeRequested()
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Equal && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
                    calculator.evaluate(); event.accepted = true;
                }
            }
        }
    }
    Text {
        Layout.fillWidth: true
        text: (calculator.result || "0") + (calculator.resultUnit ? " " + calculator.resultUnit : "")
        horizontalAlignment: Text.AlignRight
        wrapMode: Text.WrapAnywhere
        color: calculator.theme.colors.accent
        font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize + 14; bold: true }
        Accessible.name: qsTranslate("Spectrum", "Result ") + text
    }
    Text {
        Layout.fillWidth: true
        visible: calculator.error.length > 0
        text: qsTranslate("Spectrum", calculator.error)
        wrapMode: Text.Wrap
        color: calculator.theme.colors.error || calculator.theme.colors.foreground
        font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize - 1 }
    }
    GridLayout {
        Layout.fillWidth: true
        visible: !calculator.advanced
        columns: 4
        columnSpacing: 6
        rowSpacing: 6
        Repeater {
            model: ["AC", "(", ")", "⌫", "7", "8", "9", "÷", "4", "5", "6", "×", "1", "2", "3", "−", "0", ".", "%", "+", "Ans", "±", "Copy", "="]
            ShellButton {
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                label: qsTranslate("Spectrum", modelData)
                enabled: !calculator.busy && (!["Ans", "Copy"].includes(modelData) || calculator.result.length > 0)
                fontFamily: calculator.theme.fontFamily
                fontSize: calculator.theme.fontSize
                backgroundColor: modelData === "=" ? calculator.theme.colors.accent : calculator.theme.colors.surface_alt
                foregroundColor: modelData === "=" ? calculator.theme.colors.background : calculator.theme.colors.foreground
                onClicked: calculator.press(modelData)
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: calculator.advanced
        Repeater {
            model: ["Conversions", "Scientific"]
            ShellButton {
                required property string modelData
                Layout.fillWidth: true
                label: qsTranslate("Spectrum", modelData)
                enabled: !calculator.busy
                fontFamily: calculator.theme.fontFamily
                fontSize: calculator.theme.fontSize
                backgroundColor: calculator.advancedPage === modelData ? calculator.theme.colors.accent : calculator.theme.colors.surface_alt
                foregroundColor: calculator.advancedPage === modelData ? calculator.theme.colors.background : calculator.theme.colors.foreground
                onClicked: { calculator.advancedPage = modelData; calculator.activate(); }
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: calculator.advanced && calculator.advancedPage === "Conversions"
        spacing: 8
        FocusChoice {
            Layout.fillWidth: true
            theme: calculator.theme
            translateModel: true
            model: calculator.conversionGroups.map(group => group.name)
            currentIndex: calculator.conversionCategory
            enabled: !calculator.busy
            Accessible.name: qsTranslate("Spectrum", "Conversion category")
            onActivated: calculator.setCategory(currentIndex)
        }
        Text {
            text: qsTranslate("Spectrum", "Value")
            color: calculator.theme.colors.muted
            font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize - 1 }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 42
            radius: 8
            color: calculator.theme.colors.background
            TextInput {
                id: conversionValue
                anchors { fill: parent; margins: 10 }
                text: "1"
                selectByMouse: true
                activeFocusOnTab: true
                enabled: !calculator.busy
                verticalAlignment: TextInput.AlignVCenter
                color: calculator.theme.colors.foreground
                selectionColor: calculator.theme.colors.accent
                font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize }
                Accessible.name: qsTranslate("Spectrum", "Value to convert")
                Keys.onReturnPressed: calculator.convert()
                Keys.onEnterPressed: calculator.convert()
                Keys.onEscapePressed: calculator.closeRequested()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTranslate("Spectrum", "From")
                    color: calculator.theme.colors.muted
                    font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize - 1 }
                }
                FocusChoice {
                    Layout.fillWidth: true
                    visible: calculator.conversionUnits.length > 0
                    theme: calculator.theme
                    model: calculator.conversionUnits
                    currentIndex: Math.max(0, calculator.conversionUnits.indexOf(calculator.fromUnit))
                    enabled: !calculator.busy
                    onActivated: calculator.fromUnit = calculator.conversionUnits[currentIndex]
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: calculator.conversionUnits.length === 0
                    implicitHeight: 36
                    radius: 8
                    color: calculator.theme.colors.background
                    TextInput {
                        anchors { fill: parent; margins: 8 }
                        text: calculator.fromUnit
                        selectByMouse: true
                        activeFocusOnTab: true
                        enabled: !calculator.busy
                        color: calculator.theme.colors.foreground
                        font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize }
                        Accessible.name: qsTranslate("Spectrum", "Source unit")
                        onTextEdited: calculator.fromUnit = text
                    }
                }
            }
            ShellButton {
                label: "⇄"
                enabled: !calculator.busy
                Accessible.name: qsTranslate("Spectrum", "Swap units")
                fontFamily: calculator.theme.fontFamily
                fontSize: calculator.theme.fontSize
                backgroundColor: calculator.theme.colors.surface_alt
                foregroundColor: calculator.theme.colors.foreground
                onClicked: { const unit = calculator.fromUnit; calculator.fromUnit = calculator.toUnit; calculator.toUnit = unit; }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    text: qsTranslate("Spectrum", "To")
                    color: calculator.theme.colors.muted
                    font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize - 1 }
                }
                FocusChoice {
                    Layout.fillWidth: true
                    visible: calculator.conversionUnits.length > 0
                    theme: calculator.theme
                    model: calculator.conversionUnits
                    currentIndex: Math.max(0, calculator.conversionUnits.indexOf(calculator.toUnit))
                    enabled: !calculator.busy
                    onActivated: calculator.toUnit = calculator.conversionUnits[currentIndex]
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: calculator.conversionUnits.length === 0
                    implicitHeight: 36
                    radius: 8
                    color: calculator.theme.colors.background
                    TextInput {
                        anchors { fill: parent; margins: 8 }
                        text: calculator.toUnit
                        selectByMouse: true
                        activeFocusOnTab: true
                        enabled: !calculator.busy
                        color: calculator.theme.colors.foreground
                        font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize }
                        Accessible.name: qsTranslate("Spectrum", "Target unit")
                        onTextEdited: calculator.toUnit = text
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: calculator.conversionGroups[calculator.conversionCategory].name === "Currency"
            text: qsTranslate("Spectrum", "Currency rates depend on available exchange-rate data.")
            wrapMode: Text.Wrap
            color: calculator.theme.colors.muted
            font { family: calculator.theme.fontFamily; pixelSize: calculator.theme.fontSize - 1 }
        }
        RowLayout {
            Layout.fillWidth: true
            ShellButton {
                Layout.fillWidth: true
                label: qsTranslate("Spectrum", "Convert")
                enabled: !calculator.busy
                fontFamily: calculator.theme.fontFamily
                fontSize: calculator.theme.fontSize
                backgroundColor: calculator.theme.colors.accent
                foregroundColor: calculator.theme.colors.background
                onClicked: calculator.convert()
            }
            ShellButton {
                label: qsTranslate("Spectrum", "Copy")
                enabled: !calculator.busy && calculator.result.length > 0
                fontFamily: calculator.theme.fontFamily
                fontSize: calculator.theme.fontSize
                backgroundColor: calculator.theme.colors.surface_alt
                foregroundColor: calculator.theme.colors.foreground
                onClicked: calculator.press("Copy")
            }
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        visible: calculator.advanced && calculator.advancedPage === "Scientific"
        spacing: 6
        ShellButton {
            Layout.fillWidth: true
            label: calculator.degrees ? qsTranslate("Spectrum", "Angles: Degrees") : qsTranslate("Spectrum", "Angles: Radians")
            enabled: !calculator.busy
            fontFamily: calculator.theme.fontFamily
            fontSize: calculator.theme.fontSize
            backgroundColor: calculator.theme.colors.surface_alt
            foregroundColor: calculator.theme.colors.foreground
            onClicked: calculator.degrees = !calculator.degrees
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 4
            columnSpacing: 6
            rowSpacing: 6
            Repeater {
                model: ["sqrt","x²","xʸ","1/x","ln","log10","exp","abs","sin","cos","tan","π","asin","acos","atan","e","round","floor","ceil","Ans"]
                ShellButton {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    label: qsTranslate("Spectrum", modelData)
                    enabled: !calculator.busy
                    fontFamily: calculator.theme.fontFamily
                    fontSize: calculator.theme.fontSize
                    backgroundColor: calculator.theme.colors.surface_alt
                    foregroundColor: calculator.theme.colors.foreground
                    onClicked: calculator.scientific(modelData)
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Repeater {
                model: ["AC","Copy","="]
                ShellButton {
                    required property string modelData
                    Layout.fillWidth: true
                    label: qsTranslate("Spectrum", modelData)
                    enabled: !calculator.busy
                    fontFamily: calculator.theme.fontFamily
                    fontSize: calculator.theme.fontSize
                    backgroundColor: modelData === "=" ? calculator.theme.colors.accent : calculator.theme.colors.surface_alt
                    foregroundColor: modelData === "=" ? calculator.theme.colors.background : calculator.theme.colors.foreground
                    onClicked: calculator.press(modelData)
                }
            }
        }
    }
    Flow {
        Layout.fillWidth: true
        spacing: 5
        Repeater {
            model: calculator.history.slice(0, 4)
            ShellButton {
                required property var modelData
                label: (modelData.result.length > 22 ? modelData.result.slice(0, 21) + "…" : modelData.result) + (modelData.unit ? " " + modelData.unit : "")
                enabled: !calculator.busy
                fontFamily: calculator.theme.fontFamily
                fontSize: calculator.theme.fontSize - 1
                backgroundColor: calculator.theme.colors.surface_alt
                foregroundColor: calculator.theme.colors.muted
                Accessible.name: qsTranslate("Spectrum", "Reuse result ") + modelData.result + (modelData.unit ? " " + modelData.unit : "")
                onClicked: calculator.recall(modelData)
            }
        }
    }
}
