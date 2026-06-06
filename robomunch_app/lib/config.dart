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
  static const String defaultLocalhostBackend = "http://192.168.1.100:5000";
  static const String defaultCloudBackend = "http://YOUR-VM-IP:8000";
}
