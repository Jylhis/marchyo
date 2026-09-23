pragma Singleton
import QtQuick

// Static theme for the greeter: the Jylhis Dark fallback palette, variant-
// swapped at build time by packages/marchyo-shell/package.nix (same generator
// as the shell's Theme.qml). Deliberately no runtime switching machinery —
// there is no marchyo desktop, no colors.json, and no marchyo CLI under
// greetd; the greeter user only ever sees the baked host variant.
QtObject {
    id: root

    property string name: ""
    property string variant: ""

    // Whole-object reassignment only: bindings read Theme.palette.<token>,
    // and var properties notify per value, not per member.
    property var palette: ({
            bg: "#0c0f14",
            bgSubtle: "#14171c",
            surface: "#1c1f24",
            surfaceRaised: "#262a2f",
            text: "#d1d4dc",
            textMuted: "#878b91",
            textHeading: "#e7ebf2",
            textFaint: "#5d6067",
            accent: "#f5a351",
            accentHover: "#ffb063",
            accentSubtle: "#281604",
            brand: "#f8763a",
            contour: "#7ca2ff",
            border: "#242c37",
            borderStrong: "#3f4754",
            decorator: "#525a6b",
            selectionBg: "#3c2206",
            cursor: "#f5a351",
            scrim: "#040508",
            destructive: "#ffb2b4",
            statusErr: "#ff8271",
            statusWarn: "#ec871d",
            statusOk: "#39ae34",
            statusInfo: "#17a4ed"
        })

    // The greeter always has a known palette (the build bakes the host
    // variant); `known` mirrors the shell's Theme for API compatibility.
    readonly property bool known: true
}
