import qs.Ui
import qs.Commons
import qs.Services

BarIndicator {
    indicatorActive: Camera.inUse
    compact: true
    text: String.fromCodePoint(0xF05A0)
    textColor: Camera.inUse ? Colors.statusWarn : Colors.text
    tooltipText: {
        if (!Camera.inUse)
            return I18n.t("barIndicators.cameraIdle");
        return I18n.t("camera.inUse") + "\n" + Camera.users.join("\n");
    }
}
