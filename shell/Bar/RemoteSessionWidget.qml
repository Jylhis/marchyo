import qs.Ui
import qs.Commons
import qs.Services

BarIndicator {
    id: root

    compact: true
    indicatorActive: RemoteSession.active
    text: "󰢹"
    textColor: RemoteSession.active ? Colors.statusErr : Colors.text
    tooltipText: {
        if (!RemoteSession.active)
            return I18n.t("barIndicators.remoteIdle");
        if (RemoteSession.peers.length > 0)
            return I18n.t("remote.sessionFrom", RemoteSession.peers.join(", "));
        return I18n.t("remote.session");
    }
}
