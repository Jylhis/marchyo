pragma Singleton
import QtQuick

// Whether the pointer has moved since the last keyboard navigation or content
// scroll. Ui/PointerMoveGate writes it; hover styling in the Ui controls reads
// it, so content that slides under a still pointer does not steal the selection.
QtObject {
    property bool moved: true
}
