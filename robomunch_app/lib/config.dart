/// Runtime configuration for the two backend servers.
///
/// Both URLs are user-editable from the Settings dialog at runtime — these
/// values are only the defaults shown on first launch.
///
///  * [defaultLocalhostBackend] — Backend Server 1 (your computer, Flask).
///    Put your computer's LAN IP here. The phone and the computer MUST be
///    on the same Wi-Fi network.
///
///  * [defaultCloudBackend] — Backend Server 2 (cloud VM, Django).
///    Once you deploy your VM, set this to http://<VM-IP>:<PORT>.
class AppConfig {
  // iOS Simulator can reach the host Mac via localhost / 127.0.0.1 directly.
  // For a physical device on the same Wi-Fi, swap this for the Mac's LAN IP.
  static const String defaultLocalhostBackend = "http://127.0.0.1:5000";
  static const String defaultCloudBackend = "http://4.210.219.179:8000";
}
